/**
 * Know Before You Go — evaluation harness (§13).
 *
 * One Barcelona generation proves nothing. The current contract needs a
 * destination-diverse check of its seven required buckets plus optional eighth,
 * stable topic counts,
 * per-subcategory word ceilings, flexible content shapes and stable/verify
 * ratio. The failure modes are structural drift and a global disclaimer
 * disguised as section-level caution.
 *
 * This imports the REAL prompt and schema from `convex/lib`. An eval against a
 * copy-pasted prompt measures a copy of the prompt, which is exactly the drift
 * this backend exists to prevent.
 *
 * Run:
 *   npm run eval:kbyg              # every case
 *   npm run eval:kbyg -- barcelona # one case by id
 *
 * Needs `OPENAI_API_KEY` in the environment. Results land in
 * `tools/fixtures/kbyg/<id>.json` so runs stay comparable over time.
 */

import { mkdirSync, writeFileSync } from "node:fs";
import { join } from "node:path";

import { COMPONENTS } from "../convex/lib/components";
import { callOpenAI, OPENAI_MODEL } from "../convex/lib/openai";
import {
  KBYG_TOPIC_COUNTS,
  KBYG_WORD_LIMITS,
  type KBYGTopic,
} from "../convex/lib/validation";
import {
  buildSystemPrompt,
  buildUserMessage,
  type PreferenceAnswer,
  type TripInput,
} from "../convex/lib/prompts";

// MARK: - The matrix ----------------------------------------------------------

/** Seven questions, as `answers[]`. `l`/`r`/`b` keeps the cases readable. */
function answers(pattern: string): PreferenceAnswer[] {
  const choice = { l: "left", r: "right", b: "both" } as const;
  return pattern
    .split("")
    .map((c, i) => ({
      questionID: String(i + 1),
      choice: choice[c as keyof typeof choice],
    }));
}

type Case = { id: string; why: string; input: TripInput };

/**
 * Drawn from §13: destinations that stress different parts of the taxonomy, and
 * traveller shapes that should visibly change what gets a section. Not the full
 * matrix — the full matrix is a cost decision, this is the ratio check.
 */
const CASES: Case[] = [
  {
    id: "barcelona-couple",
    why: "Large European city, the baseline everything was designed against",
    input: {
      mode: "solo",
      solo: {
        destination: "Barcelona, Spain",
        groupType: "couple",
        durationDays: 4,
        startMonth: "may",
        answers: answers("lbbllbb"),
        profile: {
          scaleAnswers: [],
          usuallySkip: [],
          mustHaves: [],
          passport: "DE",
        },
      },
    },
  },
  {
    id: "bergen-family",
    why: "Small Nordic city where scams and bargaining are not topics; family changes the emphasis",
    input: {
      mode: "solo",
      solo: {
        destination: "Bergen, Norway",
        groupType: "family",
        durationDays: 6,
        startMonth: "july",
        answers: answers("rlbrlll"),
      },
    },
  },
  {
    id: "naxos-solo",
    why: "Island: ferries and timetables decide the trip; sparse practical infrastructure",
    input: {
      mode: "solo",
      solo: {
        destination: "Naxos, Greece",
        groupType: "solo",
        durationDays: 8,
        startMonth: "september",
        answers: answers("rrrlrbl"),
      },
    },
  },
  {
    id: "sri-lanka-group",
    why: "Multi-region country with real entry rules, health topics and transport friction",
    input: {
      mode: "solo",
      solo: {
        destination: "Sri Lanka",
        groupType: "group",
        durationDays: 14,
        startMonth: "february",
        answers: answers("bbrlbrl"),
      },
    },
  },
  {
    id: "dolomites-couple",
    why: "Rural/mountain: driving, seasonal closures and natural hazards are the real content",
    input: {
      mode: "solo",
      solo: {
        destination: "Val Gardena, Dolomites, Italy",
        groupType: "couple",
        durationDays: 5,
        startMonth: "january",
        answers: answers("rrblrlr"),
      },
    },
  },
  {
    id: "lisbon-group-trip",
    why: "The group path: one shared briefing assembled from several members",
    input: {
      mode: "group",
      group: {
        destination: "Lisbon, Portugal",
        durationDays: 4,
        startMonth: "october",
        members: [
          { name: "Ana", answers: answers("lbrllbr") },
          { name: "Tom", answers: answers("rlblrbl") },
          { name: "Mia", answers: answers("bbbrlrb") },
        ],
      },
    },
  },
];

// MARK: - What we measure -----------------------------------------------------

type Section = {
  bucket: string;
  topic: KBYGTopic;
  bucketTitle: string | null;
  title: string;
  body: string;
  bullets: string[];
  volatility: "stable" | "verify";
  sourceLead: string | null;
  source: string | null;
  sourceURL: string | null;
  locations: unknown[];
};

/**
 * Hedging about a fact's *currency* — the thing the volatility flag replaced.
 *
 * Deliberately narrow. An earlier version flagged "it's advisable to drink
 * bottled water", which is ordinary advice, not a confidence hedge; a detector
 * that cries wolf on real content stops being read. What is caught here is the
 * prose telling the traveller to go and check, which is the source line's job
 * on a `verify` section and nobody's job on a `stable` one.
 */
const HEDGES = [
  "check before",
  "may change",
  "can vary",
  "subject to change",
  "be sure to verify",
  "check the most current",
  "check the current",
  "check for your nationality",
  "always check",
  "as of ",
];

function scoreSections(sections: Section[]) {
  const byBucket: Record<string, number> = {};
  const byTopic: Record<string, number> = {};
  for (const s of sections) byBucket[s.bucket] = (byBucket[s.bucket] ?? 0) + 1;
  for (const s of sections) byTopic[s.topic] = (byTopic[s.topic] ?? 0) + 1;

  const verify = sections.filter((s) => s.volatility === "verify");
  const stable = sections.filter((s) => s.volatility === "stable");
  const wordBudgetViolations = sections
    .filter((s) => sectionWordCount(s) > KBYG_WORD_LIMITS[s.topic])
    .map((s) => ({
      topic: s.topic,
      title: s.title,
      actual: sectionWordCount(s),
      maximum: KBYG_WORD_LIMITS[s.topic],
    }));
  const proseOnly = sections.filter((s) => !!s.body.trim() && s.bullets.length === 0).length;
  const bulletsOnly = sections.filter((s) => !s.body.trim() && s.bullets.length > 0).length;
  const mixed = sections.filter((s) => !!s.body.trim() && s.bullets.length > 0).length;
  const topicCountViolations = Object.entries(KBYG_TOPIC_COUNTS)
    .filter(([topic, count]) => {
      const actual = byTopic[topic] ?? 0;
      return actual < count.min || actual > count.max;
    })
    .map(([topic, count]) => ({ topic, actual: byTopic[topic] ?? 0, ...count }));

  return {
    sectionCount: sections.length,
    inRange: sections.length >= 20 && sections.length <= 24,
    byBucket,
    byTopic,
    topicCountViolations,
    allRequiredBucketsCovered:
      [
        "beforeYouLeave",
        "onTheGround",
        "money",
        "gettingAround",
        "culture",
        "destinationEssential",
        "healthAndSafety",
      ].every(
        (b) => (byBucket[b] ?? 0) > 0,
      ),
    verifyCount: verify.length,
    stableCount: stable.length,
    /** Entry and currency always verify; most briefings need only 2–5. */
    verifyRatio: sections.length ? verify.length / sections.length : 0,
    /** The rule Swift enforces after decode; every one of these is a downgrade. */
    verifyWithoutSource: verify.filter((s) => !s.source?.trim()).map((s) => s.title),
    verifyWithSourceURL: verify.filter((s) => !!s.sourceURL).length,
    /** A stable section carrying source fields it was told not to set. */
    stableWithSourceFields: stable
      .filter((s) => s.source || s.sourceLead || s.sourceURL)
      .map((s) => s.title),
    hedgedStableSections: stable
      .filter((s) => HEDGES.some((h) => s.body.toLowerCase().includes(h)))
      .map((s) => s.title),
    /** A verify section that hedges anyway — its source line already said this. */
    hedgedVerifySections: verify
      .filter((s) => HEDGES.some((h) => s.body.toLowerCase().includes(h)))
      .map((s) => s.title),
    wordBudgetViolations,
    contentShapes: { proseOnly, bulletsOnly, mixed },
    titlesOverLimit: sections.filter((s) => s.title.length > 48).map((s) => s.title),
    destinationBucketTitles: sections
      .filter((s) => s.topic === "destinationEssential")
      .map((s) => s.bucketTitle),
    /** Places named at all — KBYG may name them, but it is not a places feed. */
    sectionsNamingPlaces: sections.filter((s) => s.locations.length > 0).length,
    /** Repeated prose anywhere in the briefing. */
    duplicateSentences: duplicateSentences(sections),
  };
}

function sectionWordCount(section: Section): number {
  return [section.body, ...section.bullets]
    .flatMap((text) => text.trim().split(/\s+/).filter(Boolean))
    .length;
}

function duplicateSentences(sections: Section[]): string[] {
  const seen = new Map<string, number>();
  for (const s of sections) {
    for (const raw of [s.body, ...s.bullets]) {
      for (const sentence of raw.split(/(?<=[.!?])\s+/)) {
        const key = sentence.trim().toLowerCase();
        if (key.length < 25) continue;
        seen.set(key, (seen.get(key) ?? 0) + 1);
      }
    }
  }
  return [...seen.entries()].filter(([, n]) => n > 1).map(([k]) => k);
}

// MARK: - Runner --------------------------------------------------------------

async function runCase(testCase: Case) {
  const spec = COMPONENTS.knowBeforeYouGo;
  const result = await callOpenAI({
    systemPrompt: buildSystemPrompt("knowBeforeYouGo", testCase.input.mode),
    userPrompt: buildUserMessage(testCase.input),
    schema: spec.schema,
    schemaName: spec.schemaName,
    maxOutputTokens: spec.maxOutputTokens,
  });

  const sections = (result.data as { sections: Section[] }).sections;
  return {
    id: testCase.id,
    why: testCase.why,
    model: OPENAI_MODEL,
    ranAt: new Date().toISOString(),
    usage: result.usage,
    durationMs: result.durationMs,
    score: scoreSections(sections),
    sections,
  };
}

async function main() {
  const only = process.argv.slice(2).filter((a) => !a.startsWith("-"));
  const cases = only.length ? CASES.filter((c) => only.includes(c.id)) : CASES;
  // Relative to the package root, because the script runs as a bundle from a
  // build directory — `npm run` puts us here regardless.
  const outDir = join(process.cwd(), "tools", "fixtures", "kbyg");
  mkdirSync(outDir, { recursive: true });

  const summary: Record<string, unknown>[] = [];
  for (const testCase of cases) {
    process.stdout.write(`→ ${testCase.id} … `);
    try {
      const run = await runCase(testCase);
      writeFileSync(join(outDir, `${testCase.id}.json`), JSON.stringify(run, null, 2));
      const s = run.score;
      console.log(
        `${s.sectionCount} sections, ${s.verifyCount} verify (${(s.verifyRatio * 100).toFixed(0)}%), ` +
          `${run.usage.outputTokens} out tokens, ${run.durationMs}ms`,
      );
      summary.push({ id: testCase.id, ...s, outputTokens: run.usage.outputTokens });
    } catch (error) {
      console.log(`FAILED — ${error instanceof Error ? error.message : String(error)}`);
      summary.push({ id: testCase.id, error: String(error) });
    }
  }

  console.log("\n=== Summary ===");
  console.table(
    summary.map((s: any) => ({
      case: s.id,
      sections: s.sectionCount ?? "—",
      verify: s.verifyCount ?? "—",
      "verify %": s.verifyRatio != null ? `${(s.verifyRatio * 100).toFixed(0)}%` : "—",
      buckets: s.allRequiredBucketsCovered === undefined
        ? "—"
        : s.allRequiredBucketsCovered
          ? "7/7"
          : "INCOMPLETE",
      "unsourced verify": s.verifyWithoutSource?.length ?? "—",
      hedged: s.hedgedStableSections
        ? s.hedgedStableSections.length + s.hedgedVerifySections.length
        : "—",
      "word cap": s.wordBudgetViolations
        ? s.wordBudgetViolations.length
          ? "FAIL"
          : "OK"
        : "—",
      topics: s.topicCountViolations
        ? s.topicCountViolations.length
          ? "FAIL"
          : "OK"
        : "—",
      shapes: s.contentShapes
        ? `${s.contentShapes.proseOnly}/${s.contentShapes.bulletsOnly}/${s.contentShapes.mixed}`
        : "—",
      places: s.sectionsNamingPlaces ?? "—",
      "out tokens": s.outputTokens ?? "—",
    })),
  );
  writeFileSync(join(outDir, "_summary.json"), JSON.stringify(summary, null, 2));
}

main();
