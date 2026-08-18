import { ConvexError, v } from "convex/values";
import { action, internalMutation, mutation } from "./_generated/server";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { callGroupComponent } from "./generate";
import { collectAlreadyRecommended } from "./groupDeepDives";
import type { GroupTripInput } from "./lib/prompts";
import { tokenMatchesHash } from "./lib/tokens";

const OPERATION_TTL_MS = 5 * 60 * 1_000;
const MAX_PRACTICAL = 3;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const accommodationValidator = v.object({
  label: v.string(),
  latitude: v.number(),
  longitude: v.number(),
  precision: v.union(v.literal("address"), v.literal("neighbourhood")),
});



type GroundedCandidate = {
  id: string;
  name: string;
  category: string;
  latitude: number;
  longitude: number;
  distanceMetres: number;
  walkingMinutes: number;
  mapURL: string;
};

type Accommodation = {
  label: string;
  latitude: number;
  longitude: number;
  precision: "address" | "neighbourhood";
};

type Practical = {
  kind: "transport" | "grocery" | "pharmacy";
  candidate: GroundedCandidate;
};

export function successfulNearYouCount(group: {
  nearYou?: unknown;
  nearYouGenerationCount?: number;
}): number {
  return group.nearYouGenerationCount ?? (group.nearYou === undefined ? 0 : 1);
}

/** Pure replacement rule used by the transactional mutation and tests. */
export function groupNearYouRejection(
  successfulCount: number,
  replace: boolean,
): "near_you_replace_confirmation_required" | "near_you_replacement_used" | "near_you_missing_initial" | null {
  if (successfulCount >= 2) return "near_you_replacement_used";
  if (replace && successfulCount === 0) return "near_you_missing_initial";
  if (!replace && successfulCount === 1) return "near_you_replace_confirmation_required";
  return null;
}

/**
 * Any member may start the operation. The mutation both authorizes and locks a
 * version so concurrent members cannot each spend the one replacement.
 */
export const begin = internalMutation({
  args: {
    groupId: v.id("groups"),
    memberToken: v.string(),
    replace: v.boolean(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new ConvexError("Group not found");
    if (group.status !== "ready") throw new ConvexError("group_not_ready");
    const members = await ctx.db
      .query("members")
      .withIndex("by_group", (q) => q.eq("groupId", args.groupId))
      .collect();
    let viewer: Doc<"members"> | undefined;
    for (const member of members) {
      if (await tokenMatchesHash(args.memberToken, member.memberTokenHash)) {
        viewer = member;
        break;
      }
    }
    if (!viewer) throw new ConvexError("Not authorized");

    const now = Date.now();
    if (
      group.nearYouOperationState?.state === "generating" &&
      now - (group.nearYouOperationStartedAt ?? now) < OPERATION_TTL_MS
    ) {
      throw new ConvexError("near_you_in_progress");
    }
    const successfulCount = successfulNearYouCount(group);
    const rejection = groupNearYouRejection(successfulCount, args.replace);
    if (rejection) throw new ConvexError(rejection);

    const operationVersion = (group.nearYouOperationVersion ?? 0) + 1;
    await ctx.db.patch(group._id, {
      nearYouOperationVersion: operationVersion,
      nearYouOperationState: { state: "generating" },
      nearYouOperationStartedAt: now,
    });

    const input: GroupTripInput = {
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
    };
    return {
      operationVersion,
      successfulCount,
      setBy: viewer.name,
      input,
      alreadyRecommended: collectAlreadyRecommended([
        group.itinerary,
        group.suggestions,
        group.worthIt,
        group.deepDives,
        group.nearYou,
      ]),
    };
  },
});

export const fail = internalMutation({
  args: {
    groupId: v.id("groups"),
    operationVersion: v.number(),
    code: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.nearYouOperationVersion !== args.operationVersion) return;
    await ctx.db.patch(group._id, {
      nearYouOperationState: { state: "failed", code: args.code },
      nearYouOperationStartedAt: undefined,
    });
  },
});

export const commit = internalMutation({
  args: {
    groupId: v.id("groups"),
    operationVersion: v.number(),
    previousSuccessfulCount: v.number(),
    accommodation: accommodationValidator,
    nearYou: v.any(),
    setBy: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (
      !group ||
      group.nearYouOperationVersion !== args.operationVersion ||
      group.nearYouOperationState?.state !== "generating" ||
      successfulNearYouCount(group) !== args.previousSuccessfulCount
    ) {
      throw new ConvexError("stale_group_near_you");
    }
    const generationCount = args.previousSuccessfulCount + 1;
    await ctx.db.patch(group._id, {
      accommodation: args.accommodation,
      nearYou: args.nearYou,
      nearYouSetBy: args.setBy,
      nearYouGenerationCount: generationCount,
      nearYouOperationState: { state: "ready" },
      nearYouOperationStartedAt: undefined,
    });
    return {
      accommodation: args.accommodation,
      nearYou: args.nearYou,
      nearYouSetBy: args.setBy,
      generationCount,
    };
  },
});

/**
 * Shared Near You, first half.
 *
 * Verification has to happen on a device — only the phone has MapKit — so the
 * group flow can no longer be one server round trip. This reserves the
 * operation and returns the model's *proposals*; nothing is persisted until the
 * caller comes back through `commitVerified` with places MapKit has confirmed.
 * A caller that dies in between leaves the operation reserved, which the
 * existing `OPERATION_TTL_MS` already reclaims.
 *
 * `researchArea` is client-derived coarse locality, never raw input.
 */
export const propose = action({
  args: {
    groupId: v.id("groups"),
    memberToken: v.string(),
    /** Locality/neighbourhood only, derived after local address resolution. */
    researchArea: v.string(),
    replace: v.boolean(),
  },
  handler: async (ctx, args): Promise<unknown> => {
    const researchArea = args.researchArea.trim().slice(0, 160);
    if (!researchArea) throw new ConvexError("invalid_near_you_location");
    const begun = await ctx.runMutation(internal.groupNearYou.begin, {
      groupId: args.groupId,
      memberToken: args.memberToken,
      replace: args.replace,
    });

    try {
      await ctx.runMutation(internal.quota.reserveGlobalModelCall, {});
      const result = await callGroupComponent(ctx, "nearYou", begun.input, {
        alreadyRecommended: begun.alreadyRecommended,
        nearYouLocation: { area: researchArea, city: begun.input.destination },
      });
      const data = result.data as { places?: unknown; sparseMessage?: unknown };
      return {
        operationVersion: begun.operationVersion,
        previousSuccessfulCount: begun.successfulCount,
        setBy: begun.setBy,
        places: Array.isArray(data.places) ? data.places : [],
        sparseMessage:
          typeof data.sparseMessage === "string" ? data.sparseMessage : null,
      };
    } catch (error) {
      await ctx.runMutation(internal.groupNearYou.fail, {
        groupId: args.groupId,
        operationVersion: begun.operationVersion,
        code: safeErrorCode(error),
      });
      throw error;
    }
  },
});

/**
 * Shared Near You, second half: persist what the device actually verified.
 *
 * The content is client-supplied, which is a real widening — but the same was
 * already true of the MapKit candidates and practical layer this replaces, and
 * it stays gated behind a member capability token. What is *not* trusted from
 * the client is who is writing: `setBy` is re-derived from the token here
 * rather than accepted as an argument.
 */
export const commitVerified = mutation({
  args: {
    groupId: v.id("groups"),
    memberToken: v.string(),
    operationVersion: v.number(),
    previousSuccessfulCount: v.number(),
    accommodation: accommodationValidator,
    nearYou: v.any(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new ConvexError("Group not found");
    const members = await ctx.db
      .query("members")
      .withIndex("by_group", (q) => q.eq("groupId", args.groupId))
      .collect();
    let viewer: Doc<"members"> | undefined;
    for (const member of members) {
      if (await tokenMatchesHash(args.memberToken, member.memberTokenHash)) {
        viewer = member;
        break;
      }
    }
    if (!viewer) throw new ConvexError("Not authorized");

    if (
      group.nearYouOperationVersion !== args.operationVersion ||
      group.nearYouOperationState?.state !== "generating" ||
      successfulNearYouCount(group) !== args.previousSuccessfulCount
    ) {
      throw new ConvexError("stale_group_near_you");
    }

    const generationCount = args.previousSuccessfulCount + 1;
    await ctx.db.patch(group._id, {
      accommodation: args.accommodation,
      nearYou: args.nearYou,
      nearYouSetBy: viewer.name,
      nearYouGenerationCount: generationCount,
      nearYouOperationState: { state: "ready" },
      nearYouOperationStartedAt: undefined,
    });
    return {
      accommodation: args.accommodation,
      nearYou: args.nearYou,
      nearYouSetBy: viewer.name,
      generationCount,
    };
  },
});


function safeErrorCode(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  return message.slice(0, 120).replace(/[^a-zA-Z0-9_-]/g, "_") || "near_you_failed";
}
