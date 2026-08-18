import { v } from "convex/values";
import { query } from "./_generated/server";
import { OPENAI_MODEL } from "./lib/openai";

/**
 * Debug-only spend reporting.
 *
 * Cost is computed here rather than stored, because a stored figure freezes a
 * price that changes underneath it. The tokens are the measurement; the rate is
 * an assumption, and keeping them apart means a price change is a one-line edit
 * rather than a corrupted history.
 *
 * **These rates are hand-maintained and will drift.** They are USD per million
 * tokens, checked against OpenAI's pricing page on 2026-08-18. Treat the output
 * as an order-of-magnitude guide for comparing components against each other,
 * not as a bill.
 */
const RATES: Record<string, { input: number; cachedInput: number; output: number }> = {
  "gpt-5.6-sol": { input: 5.0, cachedInput: 0.5, output: 30.0 },
  "gpt-5.6-terra": { input: 2.0, cachedInput: 0.2, output: 12.0 },
  "gpt-5.6-luna": { input: 0.2, cachedInput: 0.02, output: 1.2 },
  "gpt-4o-mini": { input: 0.15, cachedInput: 0.075, output: 0.6 },
};

/** USD per hosted web-search action. Zero for every component since Near You stopped searching. */
const WEB_SEARCH_CALL_USD = 0.01;

function costUSD(row: {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
  webSearchCalls?: number;
  model?: string;
}): number | null {
  const rate = RATES[row.model ?? OPENAI_MODEL];
  if (!rate) return null;

  // `cachedInputTokens` is the discounted subset of `inputTokens`, so the
  // uncached remainder is what gets billed at the full rate.
  const uncachedInput = Math.max(0, row.inputTokens - row.cachedInputTokens);
  const tokenCost =
    (uncachedInput * rate.input +
      row.cachedInputTokens * rate.cachedInput +
      row.outputTokens * rate.output) /
    1_000_000;
  return tokenCost + (row.webSearchCalls ?? 0) * WEB_SEARCH_CALL_USD;
}

/**
 * The most recent calls, newest first, with what each one cost.
 *
 * Deliberately returns individual rows rather than a total: an average hides
 * the case worth seeing, which is one component quietly costing ten times its
 * neighbours.
 */
export const recent = query({
  args: { limit: v.optional(v.number()) },
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(50, args.limit ?? 20));
    const rows = await ctx.db.query("generationTelemetry").order("desc").take(limit);

    return rows.map((row) => ({
      component: row.component,
      mode: row.mode,
      model: row.model ?? null,
      inputTokens: row.inputTokens,
      cachedInputTokens: row.cachedInputTokens,
      outputTokens: row.outputTokens,
      durationMs: row.durationMs,
      webSearchCalls: row.webSearchCalls ?? 0,
      errorCode: row.errorCode ?? null,
      createdAt: row.createdAt,
      /**
       * Null only when the model has no rate here — shown as unknown rather
       * than zero, since a missing price that reads as free is the one failure
       * mode this panel must not have.
       *
       * Rows written before `model` was recorded fall back to the default
       * model, which is correct for the components that use it and understates
       * historical Near You and Worth It rows that ran on a pricier tier. They
       * age out; new rows carry the model they were actually billed at.
       */
      costUSD: costUSD(row),
    }));
  },
});
