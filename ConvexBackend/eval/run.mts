/**
 * The §13 evaluation runner — and, specifically, the D15 experiment.
 *
 *   OPENAI_API_KEY=… npx tsx eval/run.ts            # the whole matrix
 *   OPENAI_API_KEY=… npx tsx eval/run.ts --only barcelona-couple-weekend
 *   OPENAI_API_KEY=… npx tsx eval/run.ts --dry      # print the plan and the call count
 *
 * It calls the SAME `lib/` code the backend calls — same prompts, same schemas,
 * same adapter, same post-decode validation. That is the point: a harness with
 * its own copy of the prompt measures the harness.
 *
 * Cost discipline: the itinerary is identical under both arms, so it is
 * generated once per fixture and shared. Five calls per fixture, not seven.
 */

import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";
import { runComponent, type SuggestionsVariant } from "../convex/lib/components";
import { callOpenAI, OpenAIError, OPENAI_MODEL } from "../convex/lib/openai";
import { buildSystemPrompt, buildUserMessage } from "../convex/lib/prompts";
import { suggestionsSchema } from "../convex/lib/schemas";
import { ValidationError } from "../convex/lib/validation";
import { FIXTURES, TRUNCATION_PROBE_CEILING, type Fixture } from "./fixtures";
import {
  completeness,
  costUSD,
  itineraryShapeViolations,
  jaccard,
  laneViolations,
  linkScore,
  placeNames,
  repeatedSentences,
  unitsOf,
  type Unit,
} from "./score";

type CallRecord = {
  fixture: string;
  arm: "shared" | SuggestionsVariant;
  component: string;
  ok: boolean;
  errorCode?: string;
  durationMs: number;
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  maxOutputTokens: number;
  repairs: number;
  droppedSections: string[];
  costUSD: number;
  data?: unknown;
};

const RESULTS_DIR = join(import.meta.dirname, "results");

async function main() {
  const args = process.argv.slice(2);
  const only = valueOf(args, "--only");
  const dry = args.includes("--dry");
  const fixtures = only ? FIXTURES.filter((f) => f.id === only) : FIXTURES;

  if (fixtures.length === 0) {
    console.error(`No fixture matched ${only ?? "(none)"}`);
    process.exit(1);
  }

  // 5 model calls per fixture: itinerary (shared) + combined suggestions +
  // split suggestions + worthIt + whereToStay. Plus one truncation probe.
  const callCount = fixtures.length * 5 + 1;
  console.log(
    `${fixtures.length} fixtures · ${callCount} model calls · model ${OPENAI_MODEL}`,
  );
  if (dry) {
    for (const f of fixtures) console.log(`  ${f.id.padEnd(32)} ${f.archetype}`);
    return;
  }
  if (!process.env.OPENAI_API_KEY) {
    console.error("OPENAI_API_KEY is not set. Refusing to run.");
    process.exit(1);
  }

  mkdirSync(RESULTS_DIR, { recursive: true });

  const records: CallRecord[] = [];
  for (const fixture of fixtures) {
    console.log(`\n── ${fixture.id} (${fixture.archetype})`);
    // Sequential across fixtures, parallel within one: this mirrors what a
    // device actually does, and keeps the per-call latencies comparable
    // instead of measuring how well the provider handles forty at once.
    const [itinerary, combined, splitSuggestions, worthIt, whereToStay] =
      await Promise.all([
        call(fixture, "shared", "itinerary"),
        call(fixture, "combined", "suggestions"),
        call(fixture, "split", "suggestions"),
        call(fixture, "split", "worthIt"),
        call(fixture, "split", "whereToStay"),
      ]);
    records.push(itinerary, combined, splitSuggestions, worthIt, whereToStay);
    for (const r of [itinerary, combined, splitSuggestions, worthIt, whereToStay]) {
      console.log(
        `   ${r.arm.padEnd(8)} ${r.component.padEnd(12)} ` +
          `${r.ok ? "ok  " : "FAIL"} ${String(r.outputTokens).padStart(5)} out · ` +
          `${String(r.durationMs).padStart(6)} ms` +
          (r.errorCode ? ` · ${r.errorCode}` : "") +
          (r.repairs ? ` · ${r.repairs} repairs` : ""),
      );
    }
  }

  const probe = await truncationProbe(fixtures[0]);
  console.log(
    `\n── truncation probe @ ${TRUNCATION_PROBE_CEILING} tokens: ` +
      `${probe.errorCode ?? "no truncation (ceiling too generous)"}`,
  );

  const stamp = new Date().toISOString().replace(/[:.]/g, "-");
  writeFileSync(
    join(RESULTS_DIR, `run-${stamp}.json`),
    JSON.stringify({ model: OPENAI_MODEL, records, probe }, null, 2),
  );
  const report = summarise(records, probe, fixtures);
  writeFileSync(join(RESULTS_DIR, `run-${stamp}.md`), report);
  console.log(`\n${report}`);
  console.log(`Written to eval/results/run-${stamp}.{json,md}`);
}

async function call(
  fixture: Fixture,
  arm: CallRecord["arm"],
  component: "itinerary" | "suggestions" | "worthIt" | "whereToStay",
): Promise<CallRecord> {
  const variant: SuggestionsVariant = arm === "combined" ? "combined" : "split";
  const started = Date.now();
  try {
    const result = await runComponent({
      component,
      input: { mode: "solo", solo: fixture.input },
      variant,
    });
    return {
      fixture: fixture.id,
      arm,
      component,
      ok: true,
      durationMs: result.durationMs,
      inputTokens: result.usage.inputTokens,
      cachedInputTokens: result.usage.cachedInputTokens,
      outputTokens: result.usage.outputTokens,
      maxOutputTokens: result.maxOutputTokens,
      repairs: result.validation.repairs,
      droppedSections: result.validation.droppedSections,
      costUSD: costUSD(result.usage),
      data: result.data,
    };
  } catch (error) {
    const usage =
      error instanceof OpenAIError && error.usage
        ? error.usage
        : { inputTokens: 0, cachedInputTokens: 0, outputTokens: 0 };
    return {
      fixture: fixture.id,
      arm,
      component,
      ok: false,
      errorCode:
        error instanceof OpenAIError
          ? error.code
          : error instanceof ValidationError
            ? `validation_${error.code}`
            : String(error),
      durationMs: Date.now() - started,
      inputTokens: usage.inputTokens,
      cachedInputTokens: usage.cachedInputTokens,
      outputTokens: usage.outputTokens,
      maxOutputTokens: 0,
      repairs: 0,
      droppedSections: [],
      costUSD: costUSD(usage),
    };
  }
}

/**
 * §13's "truncated output at the token ceiling", induced rather than waited
 * for. What matters is that a too-small ceiling produces a distinct, catchable
 * `incomplete_max_output_tokens` — not a half-object that decodes.
 */
async function truncationProbe(fixture: Fixture) {
  const started = Date.now();
  try {
    await callOpenAI({
      systemPrompt: buildSystemPrompt("suggestions", "solo", {
        extras: true,
        interestPrompts: true,
      }),
      userPrompt: buildUserMessage({ mode: "solo", solo: fixture.input }),
      schema: suggestionsSchema({ extras: true, interestPrompts: true }),
      schemaName: "travel_suggestions_schema",
      maxOutputTokens: TRUNCATION_PROBE_CEILING,
    });
    return { truncated: false, errorCode: null, durationMs: Date.now() - started };
  } catch (error) {
    return {
      truncated: error instanceof OpenAIError && error.code.startsWith("incomplete_"),
      errorCode: error instanceof OpenAIError ? error.code : String(error),
      durationMs: Date.now() - started,
    };
  }
}

// MARK: - Reporting --------------------------------------------------------

function summarise(
  records: CallRecord[],
  probe: { truncated: boolean; errorCode: string | null },
  fixtures: Fixture[],
): string {
  const lines: string[] = [];
  lines.push(`# D15 evaluation — ${new Date().toISOString().slice(0, 10)}`);
  lines.push("");
  lines.push(`Model: \`${OPENAI_MODEL}\` · ${fixtures.length} fixtures · ${records.length} calls`);
  lines.push("");

  const arms: SuggestionsVariant[] = ["combined", "split"];

  lines.push("## Per-arm totals (the suggestions lane only — the itinerary is shared)");
  lines.push("");
  lines.push(
    "| arm | calls | ok | out tokens (mean) | in tokens (mean) | cost/trip | wall-clock/trip | truncations | decode fails | repairs |",
  );
  lines.push("|---|---|---|---|---|---|---|---|---|---|");
  for (const arm of arms) {
    const rows = records.filter((r) => r.arm === arm);
    const perFixture = groupBy(rows, (r) => r.fixture);
    const wall = mean(
      [...perFixture.values()].map((rs) => Math.max(...rs.map((r) => r.durationMs))),
    );
    const cost = mean([...perFixture.values()].map((rs) => sum(rs.map((r) => r.costUSD))));
    lines.push(
      `| ${arm} | ${rows.length} | ${rows.filter((r) => r.ok).length} | ` +
        `${Math.round(mean(rows.map((r) => r.outputTokens)))} | ` +
        `${Math.round(mean(rows.map((r) => r.inputTokens)))} | ` +
        `$${cost.toFixed(5)} | ${Math.round(wall)} ms | ` +
        `${rows.filter((r) => r.errorCode?.startsWith("incomplete_")).length} | ` +
        `${rows.filter((r) => r.errorCode?.includes("decode") || r.errorCode?.startsWith("validation_")).length} | ` +
        `${sum(rows.map((r) => r.repairs))} |`,
    );
  }
  lines.push("");
  lines.push(
    "*Wall-clock is the slowest call in the arm, because the device runs them in parallel; " +
      "it excludes the itinerary, which runs alongside both arms identically.*",
  );
  lines.push("");

  lines.push("## Headroom against the ceiling");
  lines.push("");
  lines.push("| arm | component | ceiling | max out | p50 out | headroom at max |");
  lines.push("|---|---|---|---|---|---|");
  for (const arm of arms) {
    for (const component of ["suggestions", "worthIt", "whereToStay"]) {
      const rows = records.filter(
        (r) => r.arm === arm && r.component === component && r.ok,
      );
      if (rows.length === 0) continue;
      const outs = rows.map((r) => r.outputTokens).sort((a, b) => a - b);
      const ceiling = rows[0].maxOutputTokens;
      const max = outs[outs.length - 1];
      lines.push(
        `| ${arm} | ${component} | ${ceiling} | ${max} | ${outs[Math.floor(outs.length / 2)]} | ` +
          `${(((ceiling - max) / ceiling) * 100).toFixed(0)}% |`,
      );
    }
  }
  lines.push("");

  lines.push("## Content quality");
  lines.push("");
  lines.push(
    "| arm | link resolution | with coords | worth-it items (mean) | stay areas (mean) | chips (mean) | unfindable suggestions | repeated sentences | lane violations |",
  );
  lines.push("|---|---|---|---|---|---|---|---|---|");
  for (const arm of arms) {
    const perFixture = groupBy(
      records.filter((r) => r.arm === arm && r.ok),
      (r) => r.fixture,
    );
    let links = { locations: 0, resolvable: 0, withCoordinates: 0 };
    const worthItCounts: number[] = [];
    const stayCounts: number[] = [];
    const chipCounts: number[] = [];
    let unfindable = 0;
    let repeats = 0;
    let lanes = 0;

    for (const [fixture, rows] of perFixture) {
      const itinerary = records.find(
        (r) => r.fixture === fixture && r.arm === "shared" && r.ok,
      );
      const units: Unit[] = [
        ...(itinerary ? unitsOf("itinerary", itinerary.data) : []),
        ...rows.flatMap((r) => unitsOf(r.component, r.data)),
      ];
      const score = linkScore(units);
      links = {
        locations: links.locations + score.locations,
        resolvable: links.resolvable + score.resolvable,
        withCoordinates: links.withCoordinates + score.withCoordinates,
      };
      repeats += repeatedSentences(units).length;

      for (const row of rows) {
        const c = completeness(row.data);
        if (row.component === "suggestions") {
          chipCounts.push(c.interestPrompts);
          unfindable += c.unfindableTexts;
          if (arm === "combined") {
            worthItCounts.push(c.worthItItems);
            stayCounts.push(c.stayAreas);
          }
        }
        if (row.component === "worthIt") worthItCounts.push(c.worthItItems);
        if (row.component === "whereToStay") stayCounts.push(c.stayAreas);
        lanes += laneViolations(row.component, row.data).length;
      }
    }

    lines.push(
      `| ${arm} | ${pct(links.resolvable, links.locations)} | ${pct(links.withCoordinates, links.locations)} | ` +
        `${mean(worthItCounts).toFixed(1)} | ${mean(stayCounts).toFixed(1)} | ${mean(chipCounts).toFixed(1)} | ` +
        `${unfindable} | ${repeats} | ${lanes} |`,
    );
  }
  lines.push("");

  lines.push("## Personalisation");
  lines.push("");
  lines.push(
    "Overlap of named places between two travellers in the SAME destination. " +
      "Lower is better: it means the preferences reached the output.",
  );
  lines.push("");
  lines.push("| pair | arm | place overlap |");
  lines.push("|---|---|---|");
  for (const fixture of fixtures) {
    if (!fixture.contrastWith || fixture.id > fixture.contrastWith) continue;
    for (const arm of arms) {
      const a = placesFor(records, fixture.id, arm);
      const b = placesFor(records, fixture.contrastWith, arm);
      if (a.size === 0 || b.size === 0) continue;
      lines.push(
        `| ${fixture.id} vs ${fixture.contrastWith} | ${arm} | ${(jaccard(a, b) * 100).toFixed(0)}% |`,
      );
    }
  }
  lines.push("");

  lines.push("## Itinerary shape");
  lines.push("");
  lines.push(
    "One segment per day up to five days, then no more than five. Shared across " +
      "both arms — the itinerary call is identical.",
  );
  lines.push("");
  const shape = fixtures.flatMap((fixture) => {
    const row = records.find(
      (r) => r.fixture === fixture.id && r.arm === "shared" && r.ok,
    );
    return row
      ? itineraryShapeViolations(row.data, fixture.input.durationDays).map(
          (v) => `- \`${fixture.id}\`: ${v}`,
        )
      : [];
  });
  lines.push(shape.length === 0 ? "All fixtures obeyed the rule." : shape.join("\n"));
  lines.push("");

  lines.push("## Induced failure");
  lines.push("");
  lines.push(
    `Truncation probe at ${TRUNCATION_PROBE_CEILING} output tokens: ` +
      (probe.truncated
        ? `**caught cleanly** as \`${probe.errorCode}\`.`
        : `**not caught** — got \`${probe.errorCode ?? "success"}\`.`),
  );
  lines.push("");

  const failures = records.filter((r) => !r.ok);
  if (failures.length > 0) {
    lines.push("## Failures");
    lines.push("");
    for (const f of failures) {
      lines.push(`- \`${f.fixture}\` / ${f.arm} / ${f.component}: \`${f.errorCode}\``);
    }
    lines.push("");
  }

  return lines.join("\n");
}

function placesFor(
  records: CallRecord[],
  fixture: string,
  arm: SuggestionsVariant,
): Set<string> {
  const rows = records.filter((r) => r.fixture === fixture && r.arm === arm && r.ok);
  return placeNames(rows.flatMap((r) => unitsOf(r.component, r.data)));
}

function groupBy<T>(items: T[], key: (item: T) => string): Map<string, T[]> {
  const map = new Map<string, T[]>();
  for (const item of items) {
    const k = key(item);
    map.set(k, [...(map.get(k) ?? []), item]);
  }
  return map;
}

const sum = (values: number[]) => values.reduce((a, b) => a + b, 0);
const mean = (values: number[]) => (values.length ? sum(values) / values.length : 0);
const pct = (part: number, whole: number) =>
  whole === 0 ? "n/a" : `${((part / whole) * 100).toFixed(0)}%`;

function valueOf(args: string[], flag: string): string | undefined {
  const index = args.indexOf(flag);
  return index >= 0 ? args[index + 1] : undefined;
}

await main();
