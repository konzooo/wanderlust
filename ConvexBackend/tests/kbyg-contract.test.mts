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

test("KBYG titles use visible screen context and local prices carry USD equivalents", () => {
  const prompt = buildSystemPrompt("knowBeforeYouGo", "solo");

  assert.match(prompt, /destination and bucket are already visible on screen/i);
  assert.match(prompt, /Do not repeat the destination name, country, city, region or demonym/i);
  assert.match(prompt, /"Typical spending"/);
  assert.match(prompt, /never "Getting SIM cards in Japan"/);
  assert.match(prompt, /each practical price, cost, cash amount, monetary tip or fee/i);
  assert.match(prompt, /¥1,500 \(about US\$10\)/);
  assert.match(prompt, /applies throughout the briefing, including arrival and local transport/i);
  assert.match(prompt, /currencyExchange already gives the reference conversions into USD and EUR/i);
});
