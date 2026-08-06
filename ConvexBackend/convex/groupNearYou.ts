import { ConvexError, v } from "convex/values";
import { action, internalMutation } from "./_generated/server";
import { internal } from "./_generated/api";
import type { Doc } from "./_generated/dataModel";
import { callGroupComponent } from "./generate";
import { collectAlreadyRecommended } from "./groupDeepDives";
import type { GroupTripInput, NearYouCandidate } from "./lib/prompts";
import { tokenMatchesHash } from "./lib/tokens";
import { MAX_NEAR_YOU_CANDIDATES } from "./lib/validators";

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

const groundedCandidateValidator = v.object({
  id: v.string(),
  name: v.string(),
  category: v.string(),
  latitude: v.number(),
  longitude: v.number(),
  distanceMetres: v.number(),
  walkingMinutes: v.number(),
  mapURL: v.string(),
});

const practicalValidator = v.object({
  kind: v.union(v.literal("transport"), v.literal("grocery"), v.literal("pharmacy")),
  candidate: groundedCandidateValidator,
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

/** Shared Near You. `researchArea` is client-derived coarse locality, never raw input. */
export const generate = action({
  args: {
    groupId: v.id("groups"),
    memberToken: v.string(),
    accommodation: accommodationValidator,
    candidates: v.array(groundedCandidateValidator),
    practical: v.array(practicalValidator),
    unavailablePracticalKinds: v.array(
      v.union(v.literal("transport"), v.literal("grocery"), v.literal("pharmacy")),
    ),
    /** Locality/neighbourhood only, derived after local address resolution. */
    researchArea: v.string(),
    replace: v.boolean(),
  },
  handler: async (ctx, args): Promise<unknown> => {
    validateInput(args.accommodation, args.candidates, args.practical);
    const researchArea = args.researchArea.trim().slice(0, 160);
    if (!researchArea) throw new ConvexError("invalid_near_you_location");
    const begun = await ctx.runMutation(internal.groupNearYou.begin, {
      groupId: args.groupId,
      memberToken: args.memberToken,
      replace: args.replace,
    });

    try {
      await ctx.runMutation(internal.quota.reserveGlobalModelCall, {});
      const modelCandidates = args.candidates.map(modelCandidate);
      const result = await callGroupComponent(ctx, "nearYou", begun.input, {
        alreadyRecommended: begun.alreadyRecommended,
        nearYouCandidates: modelCandidates,
        nearYouLocation: { area: researchArea, city: begun.input.destination },
      });
      const nearYou = materializeGroupNearYou(
        result.data,
        args.candidates,
        args.practical,
        args.unavailablePracticalKinds,
      );

      return await ctx.runMutation(internal.groupNearYou.commit, {
        groupId: args.groupId,
        operationVersion: begun.operationVersion,
        previousSuccessfulCount: begun.successfulCount,
        accommodation: args.accommodation,
        nearYou,
        setBy: begun.setBy,
      });
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

export function modelCandidate(candidate: GroundedCandidate): NearYouCandidate {
  return {
    id: candidate.id,
    name: candidate.name,
    category: candidate.category,
    distanceMetres: candidate.distanceMetres,
    walkingMinutes: candidate.walkingMinutes,
  };
}

export function materializeGroupNearYou(
  rawSelection: unknown,
  candidates: GroundedCandidate[],
  practical: Practical[],
  unavailablePracticalKinds: string[],
  makeID: () => string = () => crypto.randomUUID(),
): unknown {
  if (typeof rawSelection !== "object" || rawSelection === null) {
    throw new ConvexError("invalid_near_you_selection");
  }
  const selection = rawSelection as {
    sections?: Array<{
      title?: unknown;
      picks?: Array<{ candidateID?: unknown; explanation?: unknown }>;
    }>;
    sparseMessage?: unknown;
    liveFinds?: Array<{
      id?: unknown;
      name?: unknown;
      category?: unknown;
      locationHint?: unknown;
      explanation?: unknown;
      accessNote?: unknown;
      sourceTitle?: unknown;
      sourceURL?: unknown;
    }>;
  };
  const byID = new Map(candidates.map((candidate) => [candidate.id, candidate]));
  const used = new Set<string>();
  const sections = (selection.sections ?? []).flatMap((section) => {
    if (typeof section.title !== "string" || !Array.isArray(section.picks)) return [];
    const picks = section.picks.flatMap((pick) => {
      if (typeof pick.candidateID !== "string" || typeof pick.explanation !== "string") {
        return [];
      }
      const candidate = byID.get(pick.candidateID);
      if (!candidate) throw new ConvexError("unknown_near_you_candidate");
      if (!used.add(pick.candidateID)) return [];
      return [{ candidate, explanation: pick.explanation }];
    });
    return picks.length === 0 ? [] : [{ id: makeID(), title: section.title, picks }];
  });
  const liveFinds = (selection.liveFinds ?? []).flatMap((find) => {
    if (
      typeof find.name !== "string" ||
      typeof find.category !== "string" ||
      typeof find.locationHint !== "string" ||
      typeof find.explanation !== "string" ||
      !(find.accessNote === null || typeof find.accessNote === "string") ||
      typeof find.sourceTitle !== "string" ||
      typeof find.sourceURL !== "string"
    ) return [];
    return [{
      id: typeof find.id === "string" && UUID_PATTERN.test(find.id) ? find.id : makeID(),
      name: find.name,
      category: find.category,
      locationHint: find.locationHint,
      explanation: find.explanation,
      accessNote: find.accessNote,
      sourceTitle: find.sourceTitle,
      sourceURL: find.sourceURL,
    }];
  });
  const sparseMessage =
    candidates.length + liveFinds.length < 4 && typeof selection.sparseMessage !== "string"
      ? "Only a few verified local finds surfaced here, so this list is intentionally short."
      : (selection.sparseMessage ?? null);
  return { sections, liveFinds, practical, unavailablePracticalKinds, sparseMessage };
}

function validateInput(
  accommodation: Accommodation,
  candidates: GroundedCandidate[],
  practical: Practical[],
) {
  if (
    !accommodation.label.trim() ||
    accommodation.label.length > 160 ||
    !validCoordinate(accommodation.latitude, accommodation.longitude) ||
    Math.abs(accommodation.latitude * 1_000 - Math.round(accommodation.latitude * 1_000)) > 1e-7 ||
    Math.abs(accommodation.longitude * 1_000 - Math.round(accommodation.longitude * 1_000)) > 1e-7
  ) {
    throw new ConvexError("invalid_coarse_accommodation");
  }
  if (candidates.length > MAX_NEAR_YOU_CANDIDATES || practical.length > MAX_PRACTICAL) {
    throw new ConvexError("too_many_near_you_candidates");
  }
  const ids = new Set<string>();
  for (const candidate of [...candidates, ...practical.map((item) => item.candidate)]) {
    if (
      !UUID_PATTERN.test(candidate.id) ||
      !candidate.name.trim() ||
      candidate.name.length > 160 ||
      candidate.category.length > 80 ||
      !validCoordinate(candidate.latitude, candidate.longitude) ||
      !Number.isFinite(candidate.distanceMetres) ||
      candidate.distanceMetres < 0 ||
      !Number.isFinite(candidate.walkingMinutes) ||
      candidate.walkingMinutes < 1 ||
      !isAppleMapsURL(candidate.mapURL)
    ) {
      throw new ConvexError("invalid_grounded_candidate");
    }
    if (candidates.includes(candidate) && !ids.add(candidate.id)) {
      throw new ConvexError("duplicate_near_you_candidate");
    }
  }
}

function validCoordinate(latitude: number, longitude: number) {
  return Number.isFinite(latitude) && Number.isFinite(longitude) &&
    latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180 &&
    !(latitude === 0 && longitude === 0);
}

function isAppleMapsURL(raw: string) {
  try {
    const url = new URL(raw);
    return url.protocol === "https:" && url.hostname === "maps.apple.com";
  } catch {
    return false;
  }
}

function safeErrorCode(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  return message.slice(0, 120).replace(/[^a-zA-Z0-9_-]/g, "_") || "near_you_failed";
}
