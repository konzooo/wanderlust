import assert from "node:assert/strict";
import { test } from "node:test";
import {
  mergeSuggestions,
  runSuggestionTopUp,
  suggestionTopUpPlan,
} from "../convex/lib/suggestionTopUp";
import type { TripInput } from "../convex/lib/prompts";

const input: TripInput = {
  mode: "solo",
  solo: {
    destination: "Rome",
    groupType: "couple",
    durationDays: 3,
    startMonth: "June",
    answers: [],
  },
};

const existing = {
  dynamicSuggestions: [{
    ID: "random",
    title: "Explore Rome like a local",
    texts: ["One existing local idea."],
  }],
  staticSuggestions: [{
    ID: "month",
    title: "June in Rome",
    texts: ["One existing June idea."],
  }],
};

const linkable = (text: string) => ({ text, locations: [] });
const category = (ID: string, title: string, count: number) => ({
  ID,
  title,
  texts: Array.from({ length: count }, (_, index) => linkable(`${title} ${index + 1}`)),
});

test("a thin Rome response is classified into precise missing targets", () => {
  const plan = suggestionTopUpPlan(existing, input);
  assert.equal(plan.complete, false);
  assert.equal(plan.partyID, "couples");
  assert.equal(plan.dynamic?.count, 3);
  assert.deepEqual(plan.dynamic?.ids, ["random"]);
  assert.equal(plan.month?.count, 3);
  assert.equal(plan.party?.count, 4);
  assert.deepEqual(plan.party?.ids, ["couples"]);
  assert.equal(plan.avoid?.count, 4);
});

test("the focused call binds each field to only its missing card count", async () => {
  let captured: Record<string, unknown> | undefined;
  const result = await runSuggestionTopUp({
    input,
    existing,
    callProvider: async (args) => {
      captured = args as unknown as Record<string, unknown>;
      return {
        data: {
          dynamic: category("random", "Explore Rome like a local", 3),
          month: category("month", "June in Rome", 3),
          party: category("couples", "Rome for two", 4),
          avoid: category("avoid", "What to avoid", 4),
        },
        usage: { inputTokens: 10, cachedInputTokens: 0, outputTokens: 20, reasoningTokens: 0 },
        durationMs: 5,
        webSources: [],
        webSearchCalls: 0,
        model: "test-model",
      };
    },
  });

  const schema = captured?.schema as {
    properties: Record<string, { properties: { texts: { minItems: number; maxItems: number } } }>;
  };
  assert.equal(schema.properties.dynamic.properties.texts.minItems, 3);
  assert.equal(schema.properties.month.properties.texts.maxItems, 3);
  assert.equal(schema.properties.party.properties.texts.minItems, 4);
  assert.match(String(captured?.systemPrompt), /Return only the missing additions/i);
  assert.equal(
    (result?.data as { dynamicSuggestions: unknown[] }).dynamicSuggestions.length,
    1,
  );
  assert.equal(
    (result?.data as { staticSuggestions: unknown[] }).staticSuggestions.length,
    3,
  );
});

test("the merge is append-only and preserves already-visible IDs and order", () => {
  const base = {
    dynamicSuggestions: [{
      id: "category-original",
      ID: "random",
      title: "Explore Rome like a local",
      texts: [{ id: "card-original", text: "Existing card", locations: [] }],
    }],
    staticSuggestions: [],
  };
  const additions = {
    dynamicSuggestions: [category("random", "A rewritten title", 3)],
    staticSuggestions: [
      category("avoid", "What to avoid", 4),
      category("couples", "Rome for two", 4),
      category("month", "June in Rome", 4),
    ],
  };
  const merged = mergeSuggestions(base, additions, input) as {
    dynamicSuggestions: Array<{ id: string; title: string; texts: Array<{ id?: string }> }>;
    staticSuggestions: Array<{ ID: string }>;
  };
  assert.equal(merged.dynamicSuggestions[0].id, "category-original");
  assert.equal(merged.dynamicSuggestions[0].title, "Explore Rome like a local");
  assert.equal(merged.dynamicSuggestions[0].texts[0].id, "card-original");
  assert.equal(merged.dynamicSuggestions[0].texts.length, 4);
  assert.deepEqual(merged.staticSuggestions.map((value) => value.ID), [
    "month",
    "couples",
    "avoid",
  ]);
});
