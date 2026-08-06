import assert from "node:assert/strict";
import { test } from "node:test";
import {
  COMPONENTS,
  NEAR_YOU_MAX_SEARCH_CALLS,
} from "../convex/lib/components";
import {
  buildSystemPrompt,
  buildUserMessage,
  type NearYouCandidate,
  type TripInput,
} from "../convex/lib/prompts";
import {
  emptyReport,
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

test("Near You prompt receives candidates but never the exact accommodation input", () => {
  const exactAddress = "Carrer de Mallorca 166, 2A";
  const message = buildUserMessage(input, {
    nearYouCandidates: candidates,
    nearYouLocation: { area: "Eixample", city: "Barcelona" },
  });

  assert.match(message, /Grounded Cafe/);
  assert.match(message, /distanceMetres=430/);
  assert.equal(message.includes(exactAddress), false);
  assert.equal(message.includes("latitude"), false);
  assert.equal(message.includes("longitude"), false);
  assert.equal(message.includes("mapURL"), false);
  assert.match(message, /area=Eixample/);
});

test("live search is required, not stored, and Near You requests one broad search", () => {
  const body = buildOpenAIRequestBody({
    systemPrompt: "local friend",
    userPrompt: "coarse area only",
    schema: { type: "object" },
    schemaName: "near_you",
    maxOutputTokens: 2048,
    model: NEAR_YOU_MODEL,
    webSearch: {
      maxToolCalls: NEAR_YOU_MAX_SEARCH_CALLS,
      approximateLocation: { city: "Barcelona" },
    },
  });
  assert.equal(body.model, "gpt-5.6-luna");
  assert.equal(body.store, false);
  assert.equal(body.tool_choice, "required");
  assert.equal(body.max_tool_calls, 1);
  assert.deepEqual(body.include, ["web_search_call.action.sources"]);
  assert.equal(JSON.stringify(body).includes("Carrer de Mallorca"), false);
  assert.equal(NEAR_YOU_MAX_SEARCH_CALLS, 1, "Near You requests one broad search action");
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

test("live finds must reference a source consulted by web search", () => {
  const raw = {
    sections: [],
    liveFinds: [
      {
        name: "Temporary Design Market",
        category: "Pop-up market",
        locationHint: "Ciutat Vella, Barcelona",
        explanation: "A timely fit for independent design and an unhurried afternoon.",
        accessNote: "Check the organizer's date before setting out.",
        sourceTitle: "Organizer",
        sourceURL: "https://events.example/market?utm_source=search",
      },
      {
        name: "Invented Market",
        category: "Market",
        locationHint: "Barcelona",
        explanation: "Unsupported.",
        accessNote: null,
        sourceTitle: "Unknown",
        sourceURL: "https://invented.invalid/event",
      },
    ],
    sparseMessage: null,
  };
  const report = emptyReport();
  const result = validateNearYou(raw, report, [], [
    { url: "https://events.example/market", title: "Organizer" },
  ]);
  assert.equal((result.liveFinds as unknown[]).length, 1);
  assert.equal((result.liveFinds as any[])[0].name, "Temporary Design Market");
  assert.equal(report.repairs, 2, "drops the unsupported find and adds an honest sparse note");
});

test("solo live finds receive a durable ID before client decoding", () => {
  const id = "33333333-3333-4333-8333-333333333333";
  const stamped = stampMissingStableIds({
    sections: [],
    liveFinds: [{
      name: "Temporary Design Market",
      category: "Pop-up market",
      locationHint: "Barcelona",
      explanation: "A current independent-design find.",
      accessNote: null,
      sourceTitle: "Organizer",
      sourceURL: "https://events.example/market",
    }],
    sparseMessage: null,
  }, () => id) as any;

  assert.equal(stamped.liveFinds[0].id, id);
  assert.deepEqual(JSON.parse(JSON.stringify(stamped)), stamped);
});

test("Near You output cannot introduce an unknown candidate ID", () => {
  assert.throws(
    () =>
      validateNearYou(
        {
          sections: [
            {
              title: "Your kind of morning",
              picks: [
                {
                  candidateID: "99999999-9999-9999-9999-999999999999",
                  explanation: "Fits a slow start and a strong coffee preference.",
                },
              ],
            },
          ],
          sparseMessage: null,
        },
        emptyReport(),
        candidates,
      ),
    (error: unknown) =>
      error instanceof ValidationError &&
      error.code === "unknown_near_you_candidate",
  );
});

test("model-authored distance or walking claims are dropped before display", () => {
  const report = emptyReport();
  const result = validateNearYou(
    {
      sections: [
        {
          title: "Easy first stop",
          picks: [
            {
              candidateID: candidates[0].id,
              explanation: "A six minute walk for a quiet coffee.",
            },
          ],
        },
        {
          title: "Under a ten minute walk",
          picks: [
            {
              candidateID: candidates[1].id,
              explanation: "Fits a quiet start and an independent-place preference.",
            },
          ],
        },
      ],
      liveFinds: [],
      sparseMessage: null,
    },
    report,
    candidates,
  );

  assert.deepEqual(result.sections, []);
  assert.equal(report.repairs, 4, "drops unsafe prose and adds an honest sparse note");
});

test("sparse candidate sets stay sparse and gain an honest note", () => {
  const result = validateNearYou(
    {
      sections: [
        {
          title: "One real fit",
          picks: [
            {
              candidateID: candidates[0].id,
              explanation: "Matches a relaxed morning and independent places.",
            },
          ],
        },
      ],
      sparseMessage: null,
    },
    emptyReport(),
    candidates.slice(0, 1),
  );

  assert.equal((result.sections as unknown[]).length, 1);
  assert.equal(typeof result.sparseMessage, "string");
});

test("Near You stays solo-manual and does not alter the deep-dive cap", () => {
  assert.equal(COMPONENTS.deepDive.perTripCap, 3);
  assert.equal(COMPONENTS.nearYou.perTripCap, null);
  assert.equal(GROUP_COMPONENTS.includes("nearYou" as never), false);
  assert.equal(GROUP_COMPONENTS.includes("worthIt"), true);
  assert.equal(GROUP_COMPONENTS.includes("whereToStay"), true);
  assert.match(buildSystemPrompt("nearYou", "solo"), /supplied candidate/i);
});
