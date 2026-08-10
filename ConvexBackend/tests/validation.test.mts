/**
 * Post-decode validation (§3).
 *
 *   npx tsx --test tests/
 *
 * Strict Structured Outputs guarantees the shape and nothing else — not counts,
 * not lengths, not "this substring is really in that text". Everything asserted
 * here is a rule the schema cannot express, which is exactly why it has to be
 * enforced in code and exactly why it needs tests: a silently-skipped rule
 * looks identical to a rule the model happened to obey.
 */

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  emptyReport,
  validateInterestPrompts,
  validateItinerary,
  validateSuggestions,
  validateWhereToStay,
  validateWorthIt,
  ValidationError,
} from "../convex/lib/validation";

const card = (place: string, extra: Record<string, unknown> = {}) => ({
  place,
  theCase: "There is nothing else like it.",
  theCatch: "The queue is brutal in the sun.",
  verdict: "Worth it — book the first slot.",
  locations: [],
  ...extra,
});

const area = (name: string, extra: Record<string, unknown> = {}) => ({
  area: name,
  theCase: "Medieval lanes that open onto a bar every fifty metres.",
  bestFor: "A first visit on foot",
  watchOut: "Narrow streets carry sound straight up.",
  locations: [],
  ...extra,
});

// MARK: - Counts the schema cannot express

test("worth-it caps the section at four cards and counts the truncation", () => {
  const report = emptyReport();
  const items = validateWorthIt(
    [card("A"), card("B"), card("C"), card("D"), card("E")],
    report,
  );
  assert.equal(items?.length, 4);
  assert.equal(report.repairs, 1);
});

test("worth-it accepts a concise two-card section without padding it", () => {
  const report = emptyReport();
  const items = validateWorthIt([card("A"), card("B")], report);
  assert.equal(items?.length, 2);
  assert.equal(report.repairs, 0);
});

test("worth-it drops cards missing a prose field rather than rendering a blank one", () => {
  const report = emptyReport();
  const items = validateWorthIt(
    [card("A"), { ...card("B"), verdict: "  " }, card("C"), card("D")],
    report,
  );
  assert.equal(items?.length, 3);
  assert.equal(report.repairs, 1);
});

test("worth-it is dropped whole when too little survives", () => {
  const report = emptyReport();
  assert.equal(validateWorthIt([card("A")], report), null);
  assert.deepEqual(report.droppedSections, ["worthIt"]);
});

test("where-to-stay caps at six areas and rejects fewer than three", () => {
  const many = validateWhereToStay(
    ["a", "b", "c", "d", "e", "f", "g"].map((n) => area(n)),
    emptyReport(),
  );
  assert.equal(many?.length, 6);
  assert.equal(validateWhereToStay([area("a"), area("b")], emptyReport()), null);
});

test("interest prompts drop duplicates of the fixed client-side chips", () => {
  const report = emptyReport();
  const prompts = validateInterestPrompts(
    ["Natural wine bars", "Climbing Gyms", "Remote-work cafés", "Sunday markets"],
    report,
  );
  assert.deepEqual(prompts, ["Natural wine bars", "Sunday markets"]);
  assert.equal(report.repairs, 2);
});

test("interest prompts drop an over-long label rather than truncating it mid-word", () => {
  const prompts = validateInterestPrompts(
    ["A label far longer than any chip could ever hope to render on one line"],
    emptyReport(),
  );
  assert.deepEqual(prompts, []);
});

// MARK: - Link repair

test("a linkSubstring carrying the city is shortened to what the text actually says", () => {
  const report = emptyReport();
  const items = validateWorthIt(
    [
      card("Chök", {
        theCase: "Try the churros at Chök, which masters the form.",
        locations: [
          { linkSubstring: "Chök, Barcelona", placeName: "Chök, Barcelona" },
        ],
      }),
      card("B"),
      card("C"),
      card("D"),
    ],
    report,
  );
  assert.equal((items![0].locations as any[])[0].linkSubstring, "Chök");
  assert.equal(
    (items![0].locations as any[])[0].placeName,
    "Chök, Barcelona",
    "placeName is the searchable name and must never be shortened",
  );
  assert.equal(report.repairs, 1);
});

test("the card's own title counts as text, since the app renders it linkably", () => {
  const items = validateWhereToStay(
    [
      area("El Born", {
        locations: [
          { linkSubstring: "El Born, Barcelona", placeName: "El Born, Barcelona" },
        ],
      }),
      area("b"),
      area("c"),
    ],
    emptyReport(),
  );
  assert.equal((items![0].locations as any[])[0].linkSubstring, "El Born");
});

test("a substring that is genuinely absent is left alone rather than guessed at", () => {
  const report = emptyReport();
  const items = validateWorthIt(
    [
      card("A", {
        locations: [{ linkSubstring: "Somewhere Else", placeName: "Somewhere Else" }],
      }),
      card("B"),
      card("C"),
      card("D"),
    ],
    report,
  );
  assert.equal((items![0].locations as any[])[0].linkSubstring, "Somewhere Else");
  assert.equal(report.repairs, 0);
});

test("a repaired prefix under three characters is refused", () => {
  const items = validateWorthIt(
    [
      card("A", {
        theCase: "El is a place, apparently, and so is everything else here.",
        locations: [{ linkSubstring: "El, Somewhere", placeName: "El, Somewhere" }],
      }),
      card("B"),
      card("C"),
      card("D"),
    ],
    emptyReport(),
  );
  assert.equal((items![0].locations as any[])[0].linkSubstring, "El, Somewhere");
});

// MARK: - Whole responses

test("suggestions carrying no readable category is a failure, not an empty feed", () => {
  assert.throws(
    () => validateSuggestions({ dynamicSuggestions: [], staticSuggestions: [] }, emptyReport()),
    (e: unknown) => e instanceof ValidationError && e.code === "empty_suggestions",
  );
});

test("suggestions keeps the extras only when the response carried them", () => {
  const split = validateSuggestions(
    {
      dynamicSuggestions: [{ ID: "cafes", title: "Cafés", texts: [{ text: "Go here." }] }],
      staticSuggestions: [],
      interestPrompts: ["Natural wine bars"],
    },
    emptyReport(),
  );
  assert.deepEqual(split.interestPrompts, ["Natural wine bars"]);
  assert.equal("worthIt" in split, false);
  assert.equal("whereToStay" in split, false);
});

test("an itinerary with no usable segment fails outright — it is the required component", () => {
  assert.throws(
    () => validateItinerary({ segments: [] }, emptyReport()),
    (e: unknown) => e instanceof ValidationError && e.code === "empty_itinerary",
  );
});

test("a short trip cannot silently omit one of its days", () => {
  assert.throws(
    () =>
      validateItinerary(
        { segments: [{ title: "Day 1" }] },
        emptyReport(),
        2,
      ),
    (e: unknown) =>
      e instanceof ValidationError && e.code === "incomplete_itinerary",
  );
});

test("a short itinerary passes only with one segment per requested day", () => {
  const itinerary = validateItinerary(
    { segments: [{ title: "Day 1" }, { title: "Day 2" }] },
    emptyReport(),
    2,
  );
  assert.equal((itinerary.segments as unknown[]).length, 2);
});
