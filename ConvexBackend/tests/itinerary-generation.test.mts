import assert from "node:assert/strict";
import { test } from "node:test";
import { runComponent } from "../convex/lib/components";
import { itinerarySchema, itinerarySegmentBounds } from "../convex/lib/schemas";
import type { OpenAIResult } from "../convex/lib/openai";
import { ValidationError } from "../convex/lib/validation";

const input = {
  mode: "solo" as const,
  solo: {
    destination: "Lisbon",
    groupType: "solo",
    durationDays: 2,
    startMonth: "August",
    answers: [],
  },
};

function itinerary(segmentCount: number): Record<string, unknown> {
  return {
    name: "travel_itinerary_schema",
    destination: "Lisbon",
    title: "Two days in Lisbon",
    segments: Array.from({ length: segmentCount }, (_, index) => ({
      title: `Day ${index + 1}`,
      description: { morning: [], afternoon: [], evening: [] },
      secret_tip: { text: "Leave room to wander.", locations: [] },
    })),
  };
}

function providerResult(data: unknown): OpenAIResult {
  return {
    data,
    usage: {
      inputTokens: 10,
      cachedInputTokens: 2,
      outputTokens: 20,
      reasoningTokens: 0,
    },
    durationMs: 5,
    webSources: [],
    webSearchCalls: 0,
  };
}

test("short trips require exactly one segment per day in the provider schema", () => {
  assert.deepEqual(itinerarySegmentBounds(4), { minItems: 4, maxItems: 4 });

  const schema = itinerarySchema(4) as {
    properties: { segments: { minItems: number; maxItems: number } };
  };
  assert.equal(schema.properties.segments.minItems, 4);
  assert.equal(schema.properties.segments.maxItems, 4);
});

test("long trips require a readable two-to-five segment range", () => {
  assert.deepEqual(itinerarySegmentBounds(12), { minItems: 2, maxItems: 5 });
});

test("an incomplete itinerary gets one charged corrective provider pass", async () => {
  const prompts: string[] = [];
  let calls = 0;
  let additionalReservations = 0;

  const result = await runComponent({
    component: "itinerary",
    input,
    callProvider: async (args) => {
      calls += 1;
      prompts.push(args.userPrompt);
      return providerResult(itinerary(calls === 1 ? 1 : 2));
    },
    beforeValidationRetry: async (error) => {
      assert.equal(error.code, "incomplete_itinerary");
      additionalReservations += 1;
    },
  });

  assert.equal(calls, 2);
  assert.equal(additionalReservations, 1);
  assert.match(prompts[1], /CORRECTION/);
  assert.match(prompts[1], /exactly 2 non-empty itinerary segments/);
  assert.equal(result.providerAttempts, 2);
  assert.equal(result.usage.inputTokens, 20);
  assert.equal(result.usage.cachedInputTokens, 4);
  assert.equal(result.usage.outputTokens, 40);
  assert.equal(result.durationMs, 10);
  assert.equal((result.data as { segments: unknown[] }).segments.length, 2);
});

test("a second incomplete itinerary fails with both attempts measured", async () => {
  let additionalReservations = 0;

  await assert.rejects(
    runComponent({
      component: "itinerary",
      input,
      callProvider: async () => providerResult(itinerary(1)),
      beforeValidationRetry: async () => {
        additionalReservations += 1;
      },
    }),
    (error: unknown) => {
      assert.ok(error instanceof ValidationError);
      assert.equal(error.code, "incomplete_itinerary");
      assert.equal(error.providerAttempts, 2);
      assert.equal(error.usage?.inputTokens, 20);
      assert.equal(error.usage?.outputTokens, 40);
      assert.equal(error.durationMs, 10);
      return true;
    },
  );

  assert.equal(additionalReservations, 1);
});
