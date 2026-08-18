import assert from "node:assert/strict";
import { test } from "node:test";
import { COMPONENTS } from "../convex/lib/components";
import {
  buildSystemPrompt,
  buildUserMessage,
  type NearYouCandidate,
  type TripInput,
} from "../convex/lib/prompts";
import {
  emptyReport,
  NEAR_YOU_MAX_PROPOSALS,
  validateNearYou,
  ValidationError,
} from "../convex/lib/validation";
import { GROUP_COMPONENTS } from "../convex/generate";
import {
  buildOpenAIRequestBody,
  countWebSearchCalls,
  NEAR_YOU_MODEL,
} from "../convex/lib/openai";
import { stampMissingStableIds } from "../convex/lib/stableIds";

const candidates: NearYouCandidate[] = [
  {
    id: "11111111-1111-1111-1111-111111111111",
    name: "Grounded Cafe",
    category: "Cafe",
    distanceMetres: 430,
    walkingMinutes: 6,
  },
  {
    id: "22222222-2222-2222-2222-222222222222",
    name: "Real Museum",
    category: "Museum",
    distanceMetres: 920,
    walkingMinutes: 13,
  },
];

const input: TripInput = {
  mode: "solo",
  solo: {
    destination: "Barcelona, Spain",
    groupType: "solo",
    durationDays: 3,
    startMonth: "may",
    answers: [],
  },
};

test("Near You prompt carries the coarse area and never the exact address", () => {
  const exactAddress = "Carrer de Mallorca 166, 2A";
  const message = buildUserMessage(input, {
    nearYouCandidates: candidates,
    nearYouLocation: { area: "Eixample", city: "Barcelona" },
  });

  assert.match(message, /area=Eixample/);
  assert.match(message, /city=Barcelona/);

  // The privacy boundary that predates this redesign and outlives it.
  assert.equal(message.includes(exactAddress), false);
  assert.equal(message.includes("latitude"), false);
  assert.equal(message.includes("longitude"), false);
  assert.equal(message.includes("mapURL"), false);

  // The model now proposes places instead of picking from a supplied sweep, so
  // a candidate list must not leak back into the prompt and re-anchor it.
  assert.equal(message.includes("Grounded Cafe"), false);
  assert.equal(message.includes("distanceMetres"), false);
});

test("Near You runs tool-free on the cheap tier and never carries the address", () => {
  const body = buildOpenAIRequestBody({
    systemPrompt: "local host",
    userPrompt: "coarse area only",
    schema: { type: "object" },
    schemaName: "near_you",
    maxOutputTokens: 2048,
    model: NEAR_YOU_MODEL,
  });
  assert.equal(body.model, "gpt-5.6-luna");
  assert.equal(body.store, false);
  // The verification pass replaced the forced search, so none of the hosted
  // web-search wiring may come back without a deliberate decision.
  assert.equal(body.tool_choice, undefined);
  assert.equal(body.tools, undefined);
  assert.equal(body.max_tool_calls, undefined);
  assert.equal(JSON.stringify(body).includes("Carrer de Mallorca"), false);
});

test("search telemetry counts paid searches, not page navigation", () => {
  assert.equal(countWebSearchCalls({
    output: [
      { type: "web_search_call", action: { type: "search", queries: ["one"] } },
      { type: "web_search_call", action: { type: "open_page", url: "https://example.com" } },
      { type: "web_search_call", action: { type: "find_in_page", pattern: "date" } },
      { type: "web_search_call", action: { type: "search", queries: ["two"] } },
    ],
  }), 2);
});

test("proposals are capped so one runaway answer cannot flood the verifier", () => {
  const report = emptyReport();
  const result = validateNearYou(
    {
      places: Array.from({ length: 40 }, (_, i) => ({
        name: `Place ${i}`,
        category: "Cafe",
        locationHint: `Carrer ${i}`,
        explanation: "Quiet enough to read in.",
        accessNote: null,
      })),
      sparseMessage: null,
    },
    report,
  );
  assert.equal((result.places as unknown[]).length, NEAR_YOU_MAX_PROPOSALS);
  assert.ok(report.repairs > 0);
});

test("the same venue proposed twice costs only one slot and one lookup", () => {
  const place = {
    name: "Bar Cañete",
    category: "Tapas bar",
    locationHint: "Carrer de la Unió 17",
    explanation: "Counter seating suits eating alone.",
    accessNote: null,
  };
  const report = emptyReport();
  const result = validateNearYou(
    { places: [place, { ...place, name: "bar cañete " }], sparseMessage: null },
    report,
  );
  assert.equal((result.places as unknown[]).length, 1);
  assert.equal(report.repairs, 1);
});

test("model-authored distance or walking claims are dropped before display", () => {
  const report = emptyReport();
  const result = validateNearYou(
    {
      places: [
        {
          name: "Federal Café",
          category: "Cafe",
          locationHint: "Carrer del Parlament 39",
          explanation: "Just a two minute walk from your door.",
          accessNote: null,
        },
        {
          name: "Mercat de la Concepció",
          category: "Market",
          locationHint: "Carrer d'Aragó 313",
          explanation: "The flower stalls are the reason to go early.",
          accessNote: "Liveliest on Saturday mornings.",
        },
      ],
      sparseMessage: null,
    },
    report,
  );
  const places = result.places as Record<string, unknown>[];
  assert.equal(places.length, 1, "the entry claiming a walking time is dropped");
  assert.equal(places[0].name, "Mercat de la Concepció");
  assert.equal(places[0].accessNote, "Liveliest on Saturday mornings.");
});

test("a recurring rhythm survives but an invented journey time does not", () => {
  const report = emptyReport();
  const result = validateNearYou(
    {
      places: [
        {
          name: "Plaça de la Vila de Gràcia",
          category: "Square",
          locationHint: "Carrer de Jesús",
          explanation: "Where the neighbourhood sits once the heat drops.",
          accessNote: "Ten minutes on foot from the flat.",
        },
      ],
      sparseMessage: null,
    },
    report,
  );
  const places = result.places as Record<string, unknown>[];
  assert.equal(places.length, 1, "the recommendation itself is kept");
  assert.equal(places[0].accessNote, null, "the journey-time claim is stripped");
  assert.ok(report.repairs > 0);
});

test("an answer with no usable place is a failure, not an empty screen", () => {
  assert.throws(
    () => validateNearYou({ places: [], sparseMessage: null }, emptyReport()),
    ValidationError,
  );
});

test("Near You stays solo-manual and does not alter the deep-dive cap", () => {
  assert.equal(COMPONENTS.deepDive.perTripCap, 3);
  assert.equal(COMPONENTS.nearYou.perTripCap, null);
  assert.equal(GROUP_COMPONENTS.includes("nearYou" as never), false);
  assert.equal(GROUP_COMPONENTS.includes("worthIt"), true);
  assert.equal(GROUP_COMPONENTS.includes("whereToStay"), true);
  assert.match(buildSystemPrompt("nearYou", "solo"), /checked against a map/i);
});
