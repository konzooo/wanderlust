import { ConvexError, v } from "convex/values";
import {
  action,
  internalMutation,
  internalQuery,
  type QueryCtx,
} from "./_generated/server";
import { internal } from "./_generated/api";
import type { Doc, Id } from "./_generated/dataModel";
import { callGroupComponent } from "./generate";
import { COMPONENTS } from "./lib/components";
import type { GroupTripInput } from "./lib/prompts";
import { stampMissingStableIds } from "./lib/stableIds";
import { tokenMatchesHash } from "./lib/tokens";
import { MAX_INTEREST_LENGTH } from "./lib/validators";
import { normaliseLabel } from "./quota";

const RESERVATION_TTL_MS = 5 * 60 * 1_000;
export const GROUP_DEEP_DIVE_CAP = COMPONENTS.deepDive.perTripCap ?? 3;

type SlotLike = { status: "reserved" | "committed"; label: string; createdAt: number };

/** Pure cap/duplicate decision, shared by the mutation and unit tests. */
export function groupDeepDiveRejection(
  slots: SlotLike[],
  label: string,
  now: number,
): "quota_component_cap" | "duplicate_deep_dive" | null {
  const live = slots.filter(
    (slot) => slot.status === "committed" || now - slot.createdAt < RESERVATION_TTL_MS,
  );
  if (live.length >= GROUP_DEEP_DIVE_CAP) return "quota_component_cap";
  if (live.some((slot) => slot.label === label)) return "duplicate_deep_dive";
  return null;
}

async function membersFor(ctx: QueryCtx, groupId: Id<"groups">) {
  return ctx.db
    .query("members")
    .withIndex("by_group", (q) => q.eq("groupId", groupId))
    .collect();
}

/** Authorizes the organizer and freezes one group prompt input. */
export const snapshot = internalQuery({
  args: { groupId: v.id("groups"), adminToken: v.string() },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new ConvexError("Group not found");
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    if (group.status !== "ready" || group.itinerary === undefined) {
      throw new ConvexError("group_not_ready");
    }
    const members = await membersFor(ctx, args.groupId);
    return {
      input: {
        destination: group.destination,
        durationDays: group.durationDays,
        startMonth: group.startMonth,
        members: members
          .filter((member) => member.status === "completed" && member.preferences)
          .map((member) => ({
            name: member.name,
            answers: member.preferences!.answers,
            profile: member.preferences!.profile ?? null,
          })),
      } satisfies GroupTripInput,
      alreadyRecommended: collectAlreadyRecommended([
        group.itinerary,
        group.suggestions,
        group.worthIt,
        group.deepDives,
      ]),
    };
  },
});

/** Transactionally claims one of the group's three successful result slots. */
export const reserve = internalMutation({
  args: {
    groupId: v.id("groups"),
    adminToken: v.string(),
    interest: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new ConvexError("Group not found");
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    if (group.status !== "ready") throw new ConvexError("group_not_ready");

    const now = Date.now();
    const label = normaliseLabel(args.interest);
    const slots = await ctx.db
      .query("groupGenerationSlots")
      .withIndex("by_group_component", (q) =>
        q.eq("groupId", args.groupId).eq("component", "deepDive"),
      )
      .collect();
    const rejection = groupDeepDiveRejection(slots, label, now);
    if (rejection) throw new ConvexError(rejection);

    const slotId = await ctx.db.insert("groupGenerationSlots", {
      groupId: args.groupId,
      component: "deepDive",
      label,
      status: "reserved",
      createdAt: now,
    });
    return { slotId };
  },
});

export const release = internalMutation({
  args: { slotId: v.id("groupGenerationSlots") },
  handler: async (ctx, args) => {
    const slot = await ctx.db.get(args.slotId);
    if (slot?.status === "reserved") await ctx.db.delete(slot._id);
  },
});

/** Commits the shared result and its cap slot in the same transaction. */
export const commit = internalMutation({
  args: {
    groupId: v.id("groups"),
    slotId: v.id("groupGenerationSlots"),
    category: v.any(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    const slot = await ctx.db.get(args.slotId);
    if (!group || !slot || slot.groupId !== args.groupId || slot.status !== "reserved") {
      throw new ConvexError("stale_group_deep_dive");
    }
    const existing = Array.isArray(group.deepDives) ? group.deepDives : [];
    if (existing.length >= GROUP_DEEP_DIVE_CAP) {
      throw new ConvexError("quota_component_cap");
    }
    await ctx.db.patch(group._id, { deepDives: [...existing, args.category] });
    await ctx.db.patch(slot._id, { status: "committed" });
    return args.category;
  },
});

/** Organizer-only explicit group deep dive. The response is shared group state. */
export const generate = action({
  args: {
    groupId: v.id("groups"),
    adminToken: v.string(),
    interest: v.string(),
  },
  handler: async (ctx, args): Promise<unknown> => {
    const interest = args.interest.trim();
    if (!interest || interest.length > MAX_INTEREST_LENGTH) {
      throw new ConvexError("invalid_interest");
    }

    const snap = await ctx.runQuery(internal.groupDeepDives.snapshot, {
      groupId: args.groupId,
      adminToken: args.adminToken,
    });
    const reservation = await ctx.runMutation(internal.groupDeepDives.reserve, {
      groupId: args.groupId,
      adminToken: args.adminToken,
      interest,
    });

    try {
      await ctx.runMutation(internal.quota.reserveGlobalModelCall, {});
      const result = await callGroupComponent(ctx, "deepDive", snap.input, {
        interest,
        alreadyRecommended: snap.alreadyRecommended,
      });
      const stamped = stampMissingStableIds(result.data) as Record<string, unknown>;
      const category = { ...stamped, requestedInterest: interest };
      await ctx.runMutation(internal.groupDeepDives.commit, {
        groupId: args.groupId,
        slotId: reservation.slotId,
        category,
      });
      return category;
    } catch (error) {
      await ctx.runMutation(internal.groupDeepDives.release, {
        slotId: reservation.slotId,
      });
      throw error;
    }
  },
});

/** Mirrors CoreModels' live recommendation derivation for group model calls. */
export function collectAlreadyRecommended(values: unknown[]): string[] {
  const result: string[] = [];
  const seen = new Set<string>();
  const add = (value: unknown) => {
    if (typeof value !== "string") return;
    const name = value.trim();
    if (!name || seen.has(name.toLowerCase())) return;
    seen.add(name.toLowerCase());
    result.push(name);
  };
  const walk = (value: unknown) => {
    if (Array.isArray(value)) {
      value.forEach(walk);
      return;
    }
    if (typeof value !== "object" || value === null) return;
    const record = value as Record<string, unknown>;
    add(record.placeName);
    // Worth-it titles are recommendations even when their locations array is absent.
    add(record.place);
    Object.values(record).forEach(walk);
  };
  values.forEach(walk);
  return result.slice(0, 200);
}
