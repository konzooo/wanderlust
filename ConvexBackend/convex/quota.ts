import { ConvexError, v } from "convex/values";
import { internalMutation, MutationCtx } from "./_generated/server";
import { Id } from "./_generated/dataModel";
import { hashToken } from "./lib/tokens";
import {
  COMPONENTS,
  generationComponent,
  suggestionsVariant,
  tripMode,
} from "./lib/components";
import type { Component } from "./lib/prompts";

/**
 * Server-side spend control for the generation entry points.
 *
 * Three layers, each answering a different question:
 *   1. `globalBudget`  — is the backend as a whole still inside today's budget?
 *   2. `installs`      — has this install had a reasonable share today?
 *   3. `generationSlots` — has this trip already used up a capped component?
 *
 * Layers 1 and 2 count ATTEMPTS, because a failed call still costs money.
 * Layer 3 counts COMMITTED RESULTS, because a deep dive the traveller never
 * received must not burn one of their three (§10).
 */

const DAY_MS = 24 * 60 * 60 * 1000;

/** Attempts per install per rolling day. Generous for real use, flat for abuse. */
export const MAX_ATTEMPTS_PER_INSTALL_PER_DAY = 60;

/** Attempts across every install per rolling day. The only unspoofable limit. */
export const MAX_ATTEMPTS_GLOBAL_PER_DAY = 5_000;

/**
 * A reservation older than this is assumed orphaned (the action died between
 * reserving and committing) and stops counting against a per-trip cap. Long
 * enough to outlast any real call, short enough that a crash doesn't cost the
 * traveller a deep dive for the rest of the trip.
 */
const RESERVATION_TTL_MS = 5 * 60 * 1000;

/** Machine-readable rejection codes. The app maps these to copy. */
export type QuotaCode =
  | "quota_global_daily"
  | "quota_install_daily"
  | "quota_component_cap"
  | "duplicate_deep_dive";

export type Reservation = {
  installHash: string;
  /** Present only for components with a per-trip cap. */
  slotId: Id<"generationSlots"> | null;
};

/**
 * Normalises a free-text interest label so "Climbing gyms", "climbing  gyms"
 * and "Climbing Gyms " are all the same deep dive. Used for both the duplicate
 * check and the stored label.
 */
export function normaliseLabel(label: string): string {
  return label.toLowerCase().replace(/\s+/g, " ").trim().slice(0, 80);
}

/**
 * Claims capacity for one model call, or throws a `ConvexError` carrying a
 * `QuotaCode`. Runs as a single mutation so the read-then-write is transactional
 * and two concurrent deep dives cannot both see "only 2 used".
 */
export const reserve = internalMutation({
  args: {
    installToken: v.string(),
    tripKey: v.string(),
    component: generationComponent,
    label: v.optional(v.string()),
  },
  handler: async (ctx, args): Promise<Reservation> => {
    const now = Date.now();
    await consumeGlobalBudget(ctx, now);
    const installHash = await consumeInstallBudget(ctx, args.installToken, now);

    const cap = COMPONENTS[args.component as Component].perTripCap;
    if (cap === null) return { installHash, slotId: null };

    const label = args.label ? normaliseLabel(args.label) : undefined;
    const slots = await ctx.db
      .query("generationSlots")
      .withIndex("by_trip_component", (q) =>
        q
          .eq("installHash", installHash)
          .eq("tripKey", args.tripKey)
          .eq("component", args.component),
      )
      .collect();

    const live = slots.filter(
      (s) => s.status === "committed" || now - s.createdAt < RESERVATION_TTL_MS,
    );
    if (live.length >= cap) throw new ConvexError("quota_component_cap");
    if (label && live.some((s) => s.label === label)) {
      throw new ConvexError("duplicate_deep_dive");
    }

    const slotId = await ctx.db.insert("generationSlots", {
      installHash,
      tripKey: args.tripKey,
      component: args.component,
      label,
      status: "reserved",
      createdAt: now,
    });
    return { installHash, slotId };
  },
});

/** Promotes a reservation once the result is actually in the traveller's hands. */
export const commitReservation = internalMutation({
  args: { slotId: v.id("generationSlots") },
  handler: async (ctx, args) => {
    const slot = await ctx.db.get(args.slotId);
    if (!slot || slot.status === "committed") return;
    await ctx.db.patch(args.slotId, { status: "committed" });
  },
});

/** Hands the slot back after a failure — failures never consume a cap. */
export const releaseReservation = internalMutation({
  args: { slotId: v.id("generationSlots") },
  handler: async (ctx, args) => {
    const slot = await ctx.db.get(args.slotId);
    if (!slot || slot.status === "committed") return;
    await ctx.db.delete(args.slotId);
  },
});

/**
 * Records what one model call actually cost and how long it took. Deliberately
 * carries no install hash and no content — this table answers "what does a
 * suggestions call cost", never "what did this person generate".
 */
export const recordTelemetry = internalMutation({
  args: {
    component: generationComponent,
    mode: tripMode,
    inputTokens: v.number(),
    cachedInputTokens: v.number(),
    outputTokens: v.number(),
    durationMs: v.number(),
    errorCode: v.optional(v.string()),
    variant: v.optional(suggestionsVariant),
    maxOutputTokens: v.optional(v.number()),
    repairs: v.optional(v.number()),
  },
  handler: async (ctx, args) => {
    await ctx.db.insert("generationTelemetry", { ...args, createdAt: Date.now() });
  },
});

/** Group manual calls share the unspoofable global budget but no install cap. */
export const reserveGlobalModelCall = internalMutation({
  args: {},
  handler: async (ctx) => {
    await consumeGlobalBudget(ctx, Date.now());
    return { reserved: true };
  },
});

// MARK: - Window accounting ----------------------------------------------------

async function consumeGlobalBudget(ctx: MutationCtx, now: number) {
  const budget = await ctx.db.query("globalBudget").first();
  if (!budget) {
    await ctx.db.insert("globalBudget", { windowStart: now, windowCount: 1 });
    return;
  }
  if (now - budget.windowStart >= DAY_MS) {
    await ctx.db.patch(budget._id, { windowStart: now, windowCount: 1 });
    return;
  }
  if (budget.windowCount >= MAX_ATTEMPTS_GLOBAL_PER_DAY) {
    throw new ConvexError("quota_global_daily");
  }
  await ctx.db.patch(budget._id, { windowCount: budget.windowCount + 1 });
}

async function consumeInstallBudget(
  ctx: MutationCtx,
  installToken: string,
  now: number,
): Promise<string> {
  const installHash = await hashToken(installToken);
  const install = await ctx.db
    .query("installs")
    .withIndex("by_hash", (q) => q.eq("installHash", installHash))
    .unique();

  if (!install) {
    await ctx.db.insert("installs", {
      installHash,
      createdAt: now,
      windowStart: now,
      windowCount: 1,
      totalCount: 1,
    });
    return installHash;
  }

  if (now - install.windowStart >= DAY_MS) {
    await ctx.db.patch(install._id, {
      windowStart: now,
      windowCount: 1,
      totalCount: install.totalCount + 1,
    });
    return installHash;
  }

  if (install.windowCount >= MAX_ATTEMPTS_PER_INSTALL_PER_DAY) {
    throw new ConvexError("quota_install_daily");
  }
  await ctx.db.patch(install._id, {
    windowCount: install.windowCount + 1,
    totalCount: install.totalCount + 1,
  });
  return installHash;
}
