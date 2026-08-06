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
  validateNearYou,
  ValidationError,
} from "../convex/lib/validation";
import { GROUP_COMPONENTS } from "../convex/generate";

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
  const message = buildUserMessage(input, { nearYouCandidates: candidates });

  assert.match(message, /Grounded Cafe/);
  assert.match(message, /distanceMetres=430/);
  assert.equal(message.includes(exactAddress), false);
  assert.equal(message.includes("latitude"), false);
  assert.equal(message.includes("longitude"), false);
  assert.equal(message.includes("mapURL"), false);
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

test("model-authored distance or walking claims fail validation", () => {
  assert.throws(
    () =>
      validateNearYou(
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
          ],
          sparseMessage: null,
        },
        emptyReport(),
        candidates,
      ),
    (error: unknown) =>
      error instanceof ValidationError &&
      error.code === "near_you_model_grounding_claim",
  );

  assert.throws(
    () =>
      validateNearYou(
        {
          sections: [
            {
              title: "Under a ten minute walk",
              picks: [
                {
                  candidateID: candidates[0].id,
                  explanation: "Fits a quiet start and an independent-place preference.",
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
      error.code === "near_you_model_grounding_claim",
  );
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
  assert.match(buildSystemPrompt("nearYou", "solo"), /supplied candidate/i);
});
