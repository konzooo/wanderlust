import assert from "node:assert/strict";
import { test } from "node:test";

import {
  buildSystemPrompt,
  buildUserMessage,
  type TripInput,
} from "../convex/lib/prompts";
import { KBYG_WORD_LIMITS } from "../convex/lib/validation";

test("the KBYG prompt carries every stable topic and its shared word ceiling", () => {
  const prompt = buildSystemPrompt("knowBeforeYouGo", "solo");

  for (const [topic, maximum] of Object.entries(KBYG_WORD_LIMITS)) {
    assert.match(prompt, new RegExp(`topic "${topic}"`));
    assert.match(
      prompt,
      new RegExp(`(?:Maximum ${maximum} words|no more than ${maximum} words)`),
      `${topic} must expose its ${maximum}-word boundary to the model`,
    );
  }

  for (const bucket of [
    "beforeYouLeave",
    "onTheGround",
    "money",
    "gettingAround",
    "culture",
    "destinationEssential",
    "healthAndSafety",
    "otherTips",
  ]) {
    assert.match(prompt, new RegExp(`bucket "${bucket}"`));
  }

  assert.match(prompt, /prose only, bullets only, or a short explanation followed by supporting bullets/);
  assert.match(prompt, /body and all bullets together/);
});

test("Traveller DNA passport is made available for nationality-specific entry advice", () => {
  const input: TripInput = {
    mode: "solo",
    solo: {
      destination: "Sri Lanka",
      groupType: "solo",
      durationDays: 10,
      startMonth: "february",
      answers: [],
      profile: {
        scaleAnswers: [],
        usuallySkip: [],
        mustHaves: [],
        passport: "de",
      },
    },
  };

  assert.match(buildUserMessage(input), /Passport used for this trip: DE/);
});
