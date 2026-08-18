import { ConvexError, v } from "convex/values";
import {
  internalAction,
  internalMutation,
  internalQuery,
  mutation,
  MutationCtx,
  QueryCtx,
} from "./_generated/server";
import { internal } from "./_generated/api";
import { Doc, Id } from "./_generated/dataModel";
import { tokenMatchesHash } from "./lib/tokens";
import { MIN_MEMBERS_TO_GENERATE } from "./lib/validators";
import {
  COMPONENTS,
  generationComponent,
  runComponent,
  type ComponentResult,
} from "./lib/components";
import { OpenAIError } from "./lib/openai";
import { ValidationError } from "./lib/validation";
import type { GroupTripInput, Component } from "./lib/prompts";
import { stampMissingStableIds } from "./lib/stableIds";

async function collectMembers(
  ctx: QueryCtx,
  groupId: Id<"groups">,
): Promise<Doc<"members">[]> {
  return ctx.db
    .query("members")
    .withIndex("by_group", (q) => q.eq("groupId", groupId))
    .collect();
}

/**
 * The one transactional entry point that begins generation. Flipping
 * `collecting → generating` here (a serialized mutation) guarantees at most one
 * live generation even under concurrent final submissions: whoever makes the
 * transition schedules exactly one run; everyone else sees a non-`collecting`
 * status and no-ops. `generationVersion` lets `commit` reject stale results.
 *
 * Returns whether generation was actually started.
 */
export async function startGeneration(
  ctx: MutationCtx,
  group: Doc<"groups">,
  members: Doc<"members">[],
  opts: { force: boolean },
): Promise<boolean> {
  if (group.status !== "collecting") return false;

  const completedCount = members.filter((m) => m.status === "completed").length;
  const allDone = members.every(
    (m) => m.status === "completed" || m.status === "skipped",
  );

  if (opts.force) {
    if (completedCount < 1) return false;
    // Late/unfinished members are skipped and cannot change the result.
    for (const m of members) {
      if (m.status === "pending") {
        await ctx.db.patch(m._id, { status: "skipped" });
      }
    }
  } else if (!(allDone && members.length >= MIN_MEMBERS_TO_GENERATE)) {
    return false;
  }

  const generationVersion = group.generationVersion + 1;
  await ctx.db.patch(group._id, {
    status: "generating",
    generationVersion,
    attemptCount: group.attemptCount + 1,
    errorCode: undefined,
  });
  await ctx.scheduler.runAfter(0, internal.generate.run, {
    groupId: group._id,
    generationVersion,
  });
  return true;
}

/** Admin "Generate now" — closes the group and generates with whoever's done. */
export const forceGenerate = mutation({
  args: { groupId: v.id("groups"), adminToken: v.string() },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new ConvexError("Group not found");
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    if (group.status !== "collecting") {
      throw new ConvexError("Generation already started");
    }
    const members = await collectMembers(ctx, args.groupId);
    const started = await startGeneration(ctx, group, members, { force: true });
    if (!started) {
      throw new ConvexError("At least one member must finish first");
    }
    return { started: true };
  },
});

/**
 * Admin retry.
 *
 * Re-runs only the components that failed, so a group whose suggestions call
 * failed does not pay to regenerate an itinerary it already has. That also
 * means a retry is available from `ready`, not just `error`: with best-effort
 * components a trip can be perfectly usable and still have something to fix.
 * Bumping `generationVersion` is what invalidates anything the previous run
 * still has in flight.
 */
export const retryGeneration = mutation({
  args: { groupId: v.id("groups"), adminToken: v.string() },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) throw new ConvexError("Group not found");
    if (!(await tokenMatchesHash(args.adminToken, group.adminTokenHash))) {
      throw new ConvexError("Not authorized");
    }
    if (group.status !== "error" && group.status !== "ready") {
      throw new ConvexError("Nothing to retry");
    }

    const components = componentsNeedingRetry(group);
    if (components.length === 0) throw new ConvexError("Nothing to retry");

    const generationVersion = group.generationVersion + 1;
    await ctx.db.patch(group._id, {
      // Only fall back to the blocking `generating` status when the trip has no
      // itinerary yet. If it does, the group stays readable while the retried
      // component regenerates and its own state carries the progress.
      status: group.itinerary === undefined ? "generating" : group.status,
      generationVersion,
      attemptCount: group.attemptCount + 1,
      errorCode: undefined,
    });
    await ctx.scheduler.runAfter(0, internal.generate.run, {
      groupId: group._id,
      generationVersion,
      components,
    });
    return { retrying: true };
  },
});

/** Immutable snapshot the action reads once, so external calls see a fixed input. */
export const snapshot = internalQuery({
  args: { groupId: v.id("groups") },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group) return null;
    const members = await collectMembers(ctx, args.groupId);
    return {
      generationVersion: group.generationVersion,
      destination: group.destination,
      durationDays: group.durationDays,
      startMonth: group.startMonth,
      members: members
        .filter((m) => m.status === "completed" && m.preferences)
        .map((m) => ({ name: m.name, preferences: m.preferences! })),
    };
  },
});

/**
 * Records one component's result, if the version still matches.
 *
 * Per-component and incremental on purpose: results become visible as they
 * land instead of after the slowest call, and a stale run — one whose version
 * was superseded by a retry — can never write over a newer one.
 */
export const commitComponent = internalMutation({
  args: {
    groupId: v.id("groups"),
    generationVersion: v.number(),
    component: generationComponent,
    data: v.any(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.generationVersion !== args.generationVersion) return;

    // A component outside the eager group set has no
    // column to write to, so there is nothing to commit.
    const field = PAYLOAD_FIELD[args.component as GroupComponent];
    if (!field) return;

    await ctx.db.patch(args.groupId, {
      componentStates: {
        ...currentStates(group),
        [args.component]: { state: "ready" as const },
      },
      [field]: stampMissingStableIds(args.data),
    });
  },
});

/** Records one component's failure, if the version still matches. */
export const failComponent = internalMutation({
  args: {
    groupId: v.id("groups"),
    generationVersion: v.number(),
    component: generationComponent,
    code: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.generationVersion !== args.generationVersion) return;
    await ctx.db.patch(args.groupId, {
      componentStates: {
        ...currentStates(group),
        [args.component]: { state: "failed" as const, code: args.code },
      },
    });
  },
});

/** Marks the components a run is about to start, so the UI can say so. */
export const markGenerating = internalMutation({
  args: {
    groupId: v.id("groups"),
    generationVersion: v.number(),
    components: v.array(generationComponent),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.generationVersion !== args.generationVersion) return;
    const states = { ...currentStates(group) };
    for (const component of args.components) {
      states[component as GroupComponent] = { state: "generating" as const };
    }
    await ctx.db.patch(args.groupId, { componentStates: states });
  },
});

/**
 * Settles the group's overall status once every component has finished.
 *
 * The required/best-effort split, made explicit: only the itinerary can fail the
 * generation. A suggestions failure leaves the trip `ready` with a failed
 * component the admin can retry on its own — which is the behaviour the
 * sequential version had by accident, now stated rather than implied.
 */
export const finishGeneration = internalMutation({
  args: {
    groupId: v.id("groups"),
    generationVersion: v.number(),
    requiredErrorCode: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.generationVersion !== args.generationVersion) return;

    if (args.requiredErrorCode) {
      await ctx.db.patch(args.groupId, {
        status: "error",
        errorCode: args.requiredErrorCode,
      });
      return;
    }
    if (group.itinerary === undefined) {
      await ctx.db.patch(args.groupId, { status: "error", errorCode: "missing_itinerary" });
      return;
    }
    await ctx.db.patch(args.groupId, { status: "ready", errorCode: undefined });
  },
});

/** Records a failure only if the version still matches. */
export const fail = internalMutation({
  args: {
    groupId: v.id("groups"),
    generationVersion: v.number(),
    errorCode: v.string(),
  },
  handler: async (ctx, args) => {
    const group = await ctx.db.get(args.groupId);
    if (!group || group.generationVersion !== args.generationVersion) return;
    await ctx.db.patch(args.groupId, { status: "error", errorCode: args.errorCode });
  },
});

/**
 * Performs the external model calls for a group.
 *
 * Every component runs concurrently and each commits the moment it returns, so
 * one slow or failing call no longer holds the others hostage. `allSettled` is
 * the point: a rejected component must not abort its siblings, and the run only
 * settles the group's status once every one of them has finished.
 *
 * Prompts, schemas, the model and the Responses adapter all come from `lib/` —
 * this action owns no prompt text, so the group and solo paths cannot drift.
 */
export const run = internalAction({
  args: {
    groupId: v.id("groups"),
    generationVersion: v.number(),
    /** Omitted means "everything"; a retry passes only what failed. */
    components: v.optional(v.array(generationComponent)),
  },
  handler: async (ctx, args) => {
    const snap = await ctx.runQuery(internal.generate.snapshot, {
      groupId: args.groupId,
    });
    if (!snap || snap.generationVersion !== args.generationVersion) return; // stale

    const components = (args.components ?? GROUP_COMPONENTS) as GroupComponent[];
    if (components.length === 0) return;

    const input: GroupTripInput = {
      destination: snap.destination,
      durationDays: snap.durationDays,
      startMonth: snap.startMonth,
      members: snap.members.map((m) => ({
        name: m.name,
        answers: m.preferences.answers,
        profile: m.preferences.profile ?? null,
      })),
    };

    await ctx.runMutation(internal.generate.markGenerating, {
      groupId: args.groupId,
      generationVersion: args.generationVersion,
      components,
    });

    const outcomes = await Promise.allSettled(
      components.map(async (component) => {
        try {
          const result = await callGroupComponent(ctx, component, input);
          await ctx.runMutation(internal.generate.commitComponent, {
            groupId: args.groupId,
            generationVersion: args.generationVersion,
            component,
            data: result.data,
          });
          return { component, code: null as string | null };
        } catch (error) {
          const code = errorCode(error);
          await ctx.runMutation(internal.generate.failComponent, {
            groupId: args.groupId,
            generationVersion: args.generationVersion,
            component,
            code,
          });
          return { component, code };
        }
      }),
    );

    // A rejection here means the commit mutation itself threw, not the model
    // call — the inner catch already handled those. Treat it as a failure of
    // that component so a required one still fails the generation.
    const requiredErrorCode = outcomes.reduce<string | undefined>((found, outcome, index) => {
      if (found) return found;
      const component = components[index];
      if (!COMPONENTS[component].required) return undefined;
      if (outcome.status === "rejected") return errorCode(outcome.reason);
      return outcome.value.code ?? undefined;
    }, undefined);

    await ctx.runMutation(internal.generate.finishGeneration, {
      groupId: args.groupId,
      generationVersion: args.generationVersion,
      requiredErrorCode,
    });
  },
});

/** Eager shared content. Deep dives remain explicit and admin-triggered. */
export const GROUP_COMPONENTS = [
  "itinerary",
  "suggestions",
  "knowBeforeYouGo",
  "worthIt",
  "whereToStay",
] as const;
export type GroupComponent = (typeof GROUP_COMPONENTS)[number];

/** Where each group component's payload is stored on the document. */
const PAYLOAD_FIELD: Record<
  GroupComponent,
  "itinerary" | "suggestions" | "knowBeforeYouGo" | "worthIt" | "whereToStay"
> = {
  itinerary: "itinerary",
  suggestions: "suggestions",
  knowBeforeYouGo: "knowBeforeYouGo",
  worthIt: "worthIt",
  whereToStay: "whereToStay",
};

type ComponentStates = Doc<"groups">["componentStates"] & {};
type ResolvedStates = Required<ComponentStates>;

/**
 * What actually happened to each component, for any generation of any age.
 *
 * Two kinds of gap are filled here, both from the payloads: a group generated
 * before per-component state existed has no `componentStates` at all, and a
 * group generated before a component existed has the object but not that key.
 * In both cases the payload is the honest record — present means it ran, absent
 * means it never did — so neither is reported as a failure.
 */
export function currentStates(group: Doc<"groups">): ResolvedStates {
  const stored = group.componentStates;
  return {
    itinerary: stored?.itinerary ?? derivedState(group.itinerary),
    suggestions: stored?.suggestions ?? derivedState(group.suggestions),
    knowBeforeYouGo: stored?.knowBeforeYouGo ?? derivedState(group.knowBeforeYouGo),
    worthIt: stored?.worthIt ?? derivedState(group.worthIt),
    whereToStay: stored?.whereToStay ?? derivedState(group.whereToStay),
  };
}

function derivedState(payload: unknown): ResolvedStates["itinerary"] {
  return payload === undefined ? { state: "absent" } : { state: "ready" };
}

/** The components worth re-running: anything that failed or never happened. */
export function componentsNeedingRetry(group: Doc<"groups">): GroupComponent[] {
  const states = currentStates(group);
  return GROUP_COMPONENTS.filter((component) => {
    const state = states[component].state;
    return state === "failed" || state === "absent";
  });
}

/**
 * Runs one group component and records its cost/latency either way.
 *
 * Always the measured `split` variant. Worth-it and Where-to-stay are shared
 * content, while each member's Worth-it decisions remain local to their own
 * device and therefore never enter this action.
 */
export async function callGroupComponent(
  ctx: { runMutation: (ref: any, args: any) => Promise<any> },
  component: Component,
  input: GroupTripInput,
  options?: {
    interest?: string;
    alreadyRecommended?: string[];
    nearYouCandidates?: import("./lib/prompts").NearYouCandidate[];
    nearYouLocation?: import("./lib/prompts").NearYouLocationContext;
  },
): Promise<ComponentResult> {
  const startedAt = Date.now();
  try {
    const result = await runComponent({
      component,
      input: { mode: "group", group: input },
      interest: options?.interest,
      alreadyRecommended: options?.alreadyRecommended,
      nearYouCandidates: options?.nearYouCandidates,
      nearYouLocation: options?.nearYouLocation,
      variant: "split",
      beforeValidationRetry: async () => {
        // A corrective itinerary pass is another paid provider call.
        await ctx.runMutation(internal.quota.reserveGlobalModelCall, {});
      },
    });
    await ctx.runMutation(internal.quota.recordTelemetry, {
      component,
      mode: "group" as const,
      inputTokens: result.usage.inputTokens,
      cachedInputTokens: result.usage.cachedInputTokens,
      outputTokens: result.usage.outputTokens,
      durationMs: result.durationMs,
      variant: "split" as const,
      maxOutputTokens: result.maxOutputTokens,
      repairs: result.validation.repairs,
      providerAttempts: result.providerAttempts,
      webSearchCalls: result.webSearchCalls,
      model: result.model,
    });
    return result;
  } catch (error) {
    const measuredError = error instanceof OpenAIError || error instanceof ValidationError
      ? error
      : undefined;
    const usage = measuredError?.usage;
    await ctx.runMutation(internal.quota.recordTelemetry, {
      component,
      mode: "group" as const,
      inputTokens: usage?.inputTokens ?? 0,
      cachedInputTokens: usage?.cachedInputTokens ?? 0,
      outputTokens: usage?.outputTokens ?? 0,
      durationMs:
        measuredError?.durationMs ??
        Date.now() - startedAt,
      errorCode: errorCode(error),
      variant: "split" as const,
      providerAttempts: measuredError?.providerAttempts ?? 1,
      webSearchCalls: 0,
    });
    throw error;
  }
}

function errorCode(e: unknown): string {
  if (e instanceof OpenAIError) return e.code;
  if (e instanceof ValidationError) return `validation_${e.code}`;
  const msg = e instanceof Error ? e.message : String(e);
  return msg.slice(0, 200);
}
