import assert from "node:assert/strict";
import { test } from "node:test";
import { componentSpec } from "../convex/lib/components";
import {
  buildOpenAIRequestBody,
  NEAR_YOU_MODEL,
  WORTH_IT_MODEL,
} from "../convex/lib/openai";
import { buildSystemPrompt } from "../convex/lib/prompts";
import { costUSD, laneViolations } from "../eval/score";

test("Worth It uses Luna without spending tokens on hidden reasoning", () => {
  const spec = componentSpec("worthIt", "split");
  assert.equal(spec.model, WORTH_IT_MODEL);
  assert.equal(spec.model, "gpt-5.6-luna");
  assert.deepEqual(spec.reasoning, { effort: "none" });

  const body = buildOpenAIRequestBody({
    systemPrompt: "decide",
    userPrompt: "trip",
    schema: { type: "object" },
    schemaName: "worth_it",
    maxOutputTokens: 2_048,
    model: spec.model,
    reasoning: spec.reasoning,
  });
  assert.equal(body.model, "gpt-5.6-luna");
  assert.deepEqual(body.reasoning, { effort: "none" });
});

test("Near You runs on the cheap tier now that MapKit verifies its output", () => {
  const spec = componentSpec("nearYou", "split");
  assert.equal(spec.model, NEAR_YOU_MODEL);
  // Terra paid for a hosted web search whose accuracy the on-device
  // verification pass now provides for free — see NEAR_YOU_MODEL.
  assert.equal(spec.model, "gpt-5.6-luna");
});

test("Worth It prompt uses a calibrated personal verdict instead of forced negativity", () => {
  const prompt = buildSystemPrompt("worthIt", "solo");

  assert.match(prompt, /Worth it —/);
  assert.match(prompt, /Worth it if/);
  assert.match(prompt, /Optional for you —/);
  assert.match(prompt, /Probably skip it for you —/);
  assert.match(prompt, /There is no quota for positive, optional or negative verdicts/);
  assert.match(prompt, /Question 3 is a preference signal, not a veto/);
  assert.match(prompt, /exceptional icon still deserves an enthusiastic/);
  assert.match(prompt, /entry fee or a paid tour is not a catch by itself/i);
  assert.match(prompt, /Specific interests are not automatically niche/);
  assert.match(prompt, /Return two to four items/);

  assert.doesNotMatch(prompt, /At least one should lean positive/);
  assert.doesNotMatch(prompt, /Return exactly four/);
});

test("the eval flags verdicts that drift outside the calibrated scale", () => {
  const data = {
    items: [
      { place: "A", verdict: "Optional for you — good, but not essential." },
      { place: "B", verdict: "Skip it unless you love books." },
    ],
  };
  assert.deepEqual(laneViolations("worthIt", data), [
    "worthIt verdict leaves the calibrated scale: B",
  ]);
});

test("the eval prices the routed Luna call instead of treating it as 4o-mini", () => {
  const usage = { inputTokens: 1_000, cachedInputTokens: 0, outputTokens: 1_000 };
  assert.equal(costUSD(usage, "gpt-4o-mini"), 0.00075);
  assert.equal(costUSD(usage, WORTH_IT_MODEL), 0.0014);
});
