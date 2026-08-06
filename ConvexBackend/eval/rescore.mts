/**
 * Re-scores a saved run without calling the model.
 *
 *   npx tsx eval/rescore.mts                       # the newest run
 *   npx tsx eval/rescore.mts run-2026-…-155Z.json  # a specific one
 *
 * The raw responses are kept in `results/*.json` precisely so that a change to
 * the *scoring* can be applied to runs that already happened. A metric that
 * only exists going forward cannot tell you whether a fix worked, and re-running
 * the matrix to answer an arithmetic question spends money to learn nothing.
 */

import { readFileSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { FIXTURES } from "./fixtures";
import {
  completeness,
  itineraryShapeViolations,
  laneViolations,
  linkScore,
  repeatedSentences,
  unitsOf,
  type Unit,
} from "./score";

const RESULTS_DIR = join(import.meta.dirname, "results");

const named = process.argv[2];
const files = readdirSync(RESULTS_DIR)
  .filter((n) => n.endsWith(".json"))
  .sort();
const file = named ?? files[files.length - 1];
if (!file) {
  console.error("No saved runs in eval/results.");
  process.exit(1);
}

const run = JSON.parse(readFileSync(join(RESULTS_DIR, file), "utf8")) as {
  records: {
    fixture: string;
    arm: string;
    component: string;
    ok: boolean;
    data?: unknown;
  }[];
};

console.log(`# Re-scored ${file}\n`);

for (const arm of ["combined", "split"]) {
  const rows = run.records.filter((r) => r.ok && (r.arm === arm || r.arm === "shared"));
  const byFixture = new Map<string, typeof rows>();
  for (const row of rows) {
    byFixture.set(row.fixture, [...(byFixture.get(row.fixture) ?? []), row]);
  }

  let locations = 0;
  let resolvable = 0;
  let withCoordinates = 0;
  let repeats = 0;
  let lanes = 0;
  let unfindable = 0;
  const perComponent = new Map<string, { n: number; ok: number }>();

  for (const rows of byFixture.values()) {
    const units: Unit[] = rows.flatMap((r) => unitsOf(r.component, r.data));
    const score = linkScore(units);
    locations += score.locations;
    resolvable += score.resolvable;
    withCoordinates += score.withCoordinates;
    repeats += repeatedSentences(units).length;

    for (const row of rows) {
      const componentUnits = unitsOf(row.component, row.data);
      const componentScore = linkScore(componentUnits);
      const bucket = perComponent.get(row.component) ?? { n: 0, ok: 0 };
      bucket.n += componentScore.locations;
      bucket.ok += componentScore.resolvable;
      perComponent.set(row.component, bucket);
      lanes += laneViolations(row.component, row.data).length;
      if (row.component === "suggestions") {
        unfindable += completeness(row.data).unfindableTexts;
      }
    }
  }

  console.log(`## ${arm}`);
  console.log(
    `link resolution ${pct(resolvable, locations)} (${resolvable}/${locations}) · ` +
      `with coords ${pct(withCoordinates, locations)} · ` +
      `unfindable suggestions ${unfindable} · repeated sentences ${repeats} · lane violations ${lanes}`,
  );
  for (const [component, { n, ok }] of [...perComponent].sort()) {
    console.log(`  ${component.padEnd(14)} ${pct(ok, n)} (${ok}/${n})`);
  }
  console.log("");
}

const shape = run.records.flatMap((r) => {
  if (!r.ok || r.component !== "itinerary" || r.arm !== "shared") return [];
  const fixture = FIXTURES.find((f) => f.id === r.fixture);
  return fixture
    ? itineraryShapeViolations(r.data, fixture.input.durationDays).map(
        (v) => `  ${r.fixture.padEnd(30)} ${v}`,
      )
    : [];
});
console.log("## itinerary shape");
console.log(shape.length === 0 ? "  all fixtures obeyed the rule" : shape.join("\n"));
console.log("");

function pct(part: number, whole: number) {
  return whole === 0 ? "n/a" : `${((part / whole) * 100).toFixed(0)}%`;
}
