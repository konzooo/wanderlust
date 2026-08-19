/**
 * Post-decode validation (§3).
 *
 *   npx tsx --test tests/*.mts
 *
 * Structured Outputs now owns the simple itinerary array bounds. These tests
 * cover the semantic constraints and defensive checks that still belong in
 * application code: a schema-conforming response can still be unusable.
 */

import assert from "node:assert/strict";
import { test } from "node:test";
import {
  emptyReport,
  KBYG_WORD_LIMITS,
  validateInterestPrompts,
  validateItinerary,
  validateKnowBeforeYouGo,
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

const kbygSection = (
  topic: keyof typeof KBYG_WORD_LIMITS,
  bucket: string,
  extra: Record<string, unknown> = {},
) => ({
  bucket,
  topic,
  bucketTitle: topic === "destinationEssential" ? "Island logistics" : null,
  title: topic,
  body: `Useful ${topic} advice.`,
  bullets:
    topic === "costSnapshot"
      ? ["Meal €12", "Ride €3", "Museum €10", "Rooms €50–150"]
      : topic === "destinationEssential" || topic === "otherTips"
        ? ["First practical point", "Second practical point"]
        : [],
  volatility: "stable",
  sourceLead: null,
  source: null,
  sourceURL: null,
  locations: [],
  ...extra,
});

function validKBYGSections(): Record<string, unknown>[] {
  return [
    kbygSection("entryRequirements", "beforeYouLeave"),
    kbygSection("arrivalTransport", "beforeYouLeave"),
    kbygSection("monthPacking", "beforeYouLeave"),
    kbygSection("simInternet", "onTheGround"),
    kbygSection("apps", "onTheGround"),
    kbygSection("electricity", "onTheGround"),
    kbygSection("onGroundWildcard", "onTheGround"),
    kbygSection("currencyExchange", "money"),
    kbygSection("costSnapshot", "money"),
    kbygSection("tipping", "money"),
    kbygSection("paymentMethods", "money"),
    kbygSection("localTransport", "gettingAround", { title: "Metro" }),
    kbygSection("localTransport", "gettingAround", { title: "Bus" }),
    kbygSection("localTransport", "gettingAround", { title: "Walking" }),
    kbygSection("culture", "culture", { title: "Greetings" }),
    kbygSection("culture", "culture", { title: "Dining rhythm" }),
    kbygSection("culture", "culture", { title: "Public behavior" }),
    kbygSection("language", "culture"),
    kbygSection("destinationEssential", "destinationEssential"),
    kbygSection("healthSafety", "healthAndSafety"),
  ];
}

// MARK: - Best-effort count repair

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

// MARK: - Know Before You Go contract

test("KBYG keeps the canonical topic order and repairs a mismatched bucket", () => {
  const sections = validKBYGSections();
  const payment = sections.find((section) => section.topic === "paymentMethods")!;
  payment.bucket = "culture";
  const report = emptyReport();

  const validated = validateKnowBeforeYouGo({ sections: sections.reverse() }, report);
  const result = validated.sections as Record<string, unknown>[];

  assert.equal(result.length, 20);
  assert.deepEqual(
    result.slice(0, 4).map((section) => section.topic),
    ["entryRequirements", "arrivalTransport", "monthPacking", "simInternet"],
  );
  assert.equal(
    result.find((section) => section.topic === "paymentMethods")!.bucket,
    "money",
  );
  assert.equal(report.repairs, 1);
});

test("KBYG enforces one combined word ceiling without choosing the content shape", () => {
  const sections = validKBYGSections();
  const arrival = sections.find((section) => section.topic === "arrivalTransport")!;
  arrival.body = Array.from({ length: 90 }, (_, index) => `body${index}`).join(" ");
  arrival.bullets = ["one two three four five six seven eight nine ten eleven twelve"];
  const report = emptyReport();

  const validated = validateKnowBeforeYouGo({ sections }, report);
  const result = (validated.sections as Record<string, unknown>[]).find(
    (section) => section.topic === "arrivalTransport",
  )!;
  const content = [result.body, ...(result.bullets as string[])]
    .join(" ")
    .trim()
    .split(/\s+/);

  assert.ok(content.length <= KBYG_WORD_LIMITS.arrivalTransport);
  assert.notEqual(result.body, "", "the model's prose-plus-bullets shape is retained");
  assert.equal((result.bullets as string[]).length, 1);
  assert.equal(report.repairs, 1);
});

test("KBYG rejects a missing required topic instead of rendering a structurally incomplete brief", () => {
  const sections = validKBYGSections().filter(
    (section) => section.topic !== "currencyExchange",
  );

  assert.throws(
    () => validateKnowBeforeYouGo({ sections }, emptyReport()),
    (error: unknown) =>
      error instanceof ValidationError &&
      error.code === "incomplete_know_before_you_go:currencyExchange",
  );
});

test("KBYG drops an under-specified optional Other tips section", () => {
  const report = emptyReport();
  const sections = [
    ...validKBYGSections(),
    kbygSection("otherTips", "otherTips", { bullets: ["Only one"] }),
  ];

  const validated = validateKnowBeforeYouGo({ sections }, report);
  assert.equal(
    (validated.sections as Record<string, unknown>[]).some(
      (section) => section.topic === "otherTips",
    ),
    false,
  );
  assert.equal(report.repairs, 1);
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
