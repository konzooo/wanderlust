import { ConvexError, v } from "convex/values";
import { action } from "./_generated/server";
import { internal } from "./_generated/api";
import {
  generationComponent,
  runComponent,
  suggestionsVariant,
  SUGGESTIONS_VARIANT,
  type SuggestionsVariant,
} from "./lib/components";
import type { Component, NearYouCandidate, SoloTripInput } from "./lib/prompts";
import { OpenAIError } from "./lib/openai";
import { ValidationError } from "./lib/validation";
import {
  runSuggestionTopUp,
  suggestionTopUpPlan,
  type SuggestionsSnapshot,
} from "./lib/suggestionTopUp";
import type { Reservation } from "./quota";
import {
  MAX_ALREADY_RECOMMENDED_ITEMS,
  MAX_CUSTOMIZATIONS_LENGTH,
  MAX_DESTINATION_INPUT_LENGTH,
  MAX_INTEREST_LENGTH,
  MAX_NEAR_YOU_CANDIDATES,
  MAX_NEAR_YOU_LOCATION_LENGTH,
  MAX_SUGGESTION_SNAPSHOT_CARDS,
  MAX_SUGGESTION_SNAPSHOT_CATEGORIES,
  MAX_SUGGESTION_SNAPSHOT_TEXT_LENGTH,
  nearYouCandidate,
  nearYouLocation,
  soloTripInput,
  suggestionsSnapshot,
} from "./lib/validators";
import { stampMissingStableIds } from "./lib/stableIds";

/**
 * Solo trip generation. This is the whole reason the app no longer carries an
 * OpenAI key: the device asks for a component, the backend owns the prompt, the
 * schema, the model choice and the spend limits, and only structured output
 * comes back.
 *
 * One component per call, deliberately. The app already tracks each component's
 * state independently, and a per-component boundary is what makes per-component
 * retry and the required-vs-best-effort split expressible at all. Orchestrating
 * the set (single-flight, attempt IDs, `Promise.allSettled`) is the generation
 * coordinator's job and lands with it.
 *
 * Public and unauthenticated, like every other function in this backend — the
 * install token is throttling identity, not a credential, and this action
 * returns only content generated from arguments the caller supplied. There is
 * nothing here to read that the caller did not already send.
 */
export const generateComponent = action({
  args: {
    /** Random token minted on first launch and kept in the device Keychain. */
    installToken: v.string(),
    /** Stable per-trip key; scopes the per-trip component caps. */
    tripKey: v.string(),
    component: generationComponent,
    input: soloTripInput,
    /** Deep dives only: the interest the traveller tapped. */
    interest: v.optional(v.union(v.string(), v.null())),
    /**
     * Places already recommended elsewhere in this trip, so a later component
     * doesn't repeat them. Derived by the caller at call time and never stored
     * server-side — a persisted copy would go stale the moment anything else
     * in the trip changed.
     */
    alreadyRecommended: v.optional(v.union(v.array(v.string()), v.null())),
    /**
     * Near You only. MapKit-grounded facts with no accommodation input,
     * coordinates or map URLs. The model may return only these candidate IDs.
     */
    nearYouCandidates: v.optional(
      v.union(v.array(nearYouCandidate), v.null()),
    ),
    /** Coarse locality/city only; raw address input is structurally absent. */
    nearYouLocation: v.optional(v.union(nearYouLocation, v.null())),
    /**
     * Which arm of the D15 experiment to run (see `SUGGESTIONS_VARIANT`).
     *
     * The caller decides, because only the caller knows what else it is about
     * to request: asking for the enlarged suggestions shape and then also
     * calling `worthIt` would generate the same cards twice. The server's own
     * constant is the default for a client that doesn't say, which is what an
     * older build sends.
     */
    variant: v.optional(v.union(suggestionsVariant, v.null())),
  },
  handler: async (ctx, args): Promise<unknown> => {
    const component = args.component as Component;
    const input = args.input as SoloTripInput;

    if (
      args.installToken.length < 32 ||
      args.installToken.length > 256 ||
      args.tripKey.length === 0 ||
      args.tripKey.length > 128
    ) {
      throw new ConvexError("invalid_request");
    }
    if (input.destination.trim().length === 0) {
      throw new ConvexError("invalid_request");
    }
    if (
      input.destination.length > MAX_DESTINATION_INPUT_LENGTH ||
      (input.customizations ?? "").length > MAX_CUSTOMIZATIONS_LENGTH
    ) {
      throw new ConvexError("input_too_long");
    }

    const interest = args.interest?.slice(0, MAX_INTEREST_LENGTH) || undefined;
    if (component === "deepDive" && !interest) {
      throw new ConvexError("invalid_request");
    }
    const alreadyRecommended =
      args.alreadyRecommended?.slice(0, MAX_ALREADY_RECOMMENDED_ITEMS) ?? undefined;
    const nearYouCandidates = args.nearYouCandidates
      ?.slice(0, MAX_NEAR_YOU_CANDIDATES) as NearYouCandidate[] | undefined;
    if (component === "nearYou") {
      if (!nearYouCandidates || !validNearYouCandidates(nearYouCandidates)) {
        throw new ConvexError("invalid_near_you_candidates");
      }
    }
    const nearYouLocationContext = args.nearYouLocation
      ? {
        area: args.nearYouLocation.area.trim().slice(0, MAX_NEAR_YOU_LOCATION_LENGTH),
        city: args.nearYouLocation.city.trim().slice(0, MAX_NEAR_YOU_LOCATION_LENGTH),
      }
      : undefined;
    if (
      component === "nearYou" &&
      (!nearYouLocationContext?.area || !nearYouLocationContext.city)
    ) {
      throw new ConvexError("invalid_near_you_location");
    }

    // Throws a ConvexError carrying a QuotaCode when a limit is hit.
    const reservation: Reservation = await ctx.runMutation(internal.quota.reserve, {
      installToken: args.installToken,
      tripKey: args.tripKey,
      component: args.component,
      label: interest,
    });

    const variant: SuggestionsVariant = args.variant ?? SUGGESTIONS_VARIANT;
    const startedAt = Date.now();
    try {
      const result = await runComponent({
        component,
        input: { mode: "solo", solo: input },
        interest,
        alreadyRecommended,
        nearYouCandidates: component === "nearYou" ? nearYouCandidates : undefined,
        nearYouLocation: component === "nearYou" ? nearYouLocationContext : undefined,
        variant,
        beforeValidationRetry: async () => {
          // The corrective pass is a second paid provider call, so it consumes
          // a second install/global attempt just like a traveller-tapped retry.
          await ctx.runMutation(internal.quota.reserve, {
            installToken: args.installToken,
            tripKey: args.tripKey,
            component: args.component,
            label: interest,
          });
        },
      });

      await ctx.runMutation(internal.quota.recordTelemetry, {
        component: args.component,
        mode: "solo" as const,
        inputTokens: result.usage.inputTokens,
        cachedInputTokens: result.usage.cachedInputTokens,
        outputTokens: result.usage.outputTokens,
        durationMs: result.durationMs,
        variant,
        maxOutputTokens: result.maxOutputTokens,
        repairs: result.validation.repairs,
        providerAttempts: result.providerAttempts,
        webSearchCalls: result.webSearchCalls,
        model: result.model,
      });
      if (reservation.slotId) {
        await ctx.runMutation(internal.quota.commitReservation, {
          slotId: reservation.slotId,
        });
      }
      return component === "nearYou"
        ? stampMissingStableIds(result.data)
        : result.data;
    } catch (error) {
      const code = failureCode(error);
      // A truncation still burned every one of the output tokens it produced,
      // and that count is the whole basis for re-deriving the ceiling — so a
      // failed call records what it actually cost, not zeros.
      const measuredError = error instanceof OpenAIError || error instanceof ValidationError
        ? error
        : undefined;
      const usage = measuredError?.usage;
      await ctx.runMutation(internal.quota.recordTelemetry, {
        component: args.component,
        mode: "solo" as const,
        inputTokens: usage?.inputTokens ?? 0,
        cachedInputTokens: usage?.cachedInputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
        durationMs:
          measuredError?.durationMs ??
          Date.now() - startedAt,
        errorCode: code,
        variant,
        providerAttempts: measuredError?.providerAttempts ?? 1,
        webSearchCalls: 0,
      });
      // The traveller never received this, so it must not consume a cap.
      if (reservation.slotId) {
        await ctx.runMutation(internal.quota.releaseReservation, {
          slotId: reservation.slotId,
        });
      }
      throw new ConvexError(code);
    }
  },
});

/**
 * Completes a usable-but-thin solo suggestions response without delaying its
 * first paint. The client has already rendered `existingSuggestions` before it
 * calls this action; this endpoint returns additions only, and one failure
 * leaves that visible first response untouched.
 */
export const topUpSuggestions = action({
  args: {
    installToken: v.string(),
    tripKey: v.string(),
    input: soloTripInput,
    existingSuggestions: suggestionsSnapshot,
    alreadyRecommended: v.optional(v.union(v.array(v.string()), v.null())),
  },
  handler: async (ctx, args): Promise<unknown> => {
    const input = args.input as SoloTripInput;
    const existing = args.existingSuggestions as SuggestionsSnapshot;
    if (
      args.installToken.length < 32 ||
      args.installToken.length > 256 ||
      args.tripKey.length === 0 ||
      args.tripKey.length > 128 ||
      input.destination.trim().length === 0
    ) {
      throw new ConvexError("invalid_request");
    }
    if (
      input.destination.length > MAX_DESTINATION_INPUT_LENGTH ||
      (input.customizations ?? "").length > MAX_CUSTOMIZATIONS_LENGTH ||
      !validSuggestionSnapshot(existing)
    ) {
      throw new ConvexError("input_too_long");
    }

    const tripInput = { mode: "solo" as const, solo: input };
    if (suggestionTopUpPlan(existing, tripInput).complete) {
      return { dynamicSuggestions: [], staticSuggestions: [] };
    }

    const reservation: Reservation = await ctx.runMutation(internal.quota.reserve, {
      installToken: args.installToken,
      tripKey: args.tripKey,
      component: "suggestions",
      label: "automatic_top_up",
    });
    const startedAt = Date.now();
    try {
      const result = await runSuggestionTopUp({
        input: tripInput,
        existing,
        alreadyRecommended:
          args.alreadyRecommended?.slice(0, MAX_ALREADY_RECOMMENDED_ITEMS) ?? undefined,
      });
      if (!result) return { dynamicSuggestions: [], staticSuggestions: [] };
      await ctx.runMutation(internal.quota.recordTelemetry, {
        component: "suggestions",
        mode: "solo" as const,
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
      if (reservation.slotId) {
        await ctx.runMutation(internal.quota.commitReservation, {
          slotId: reservation.slotId,
        });
      }
      return result.data;
    } catch (error) {
      const code = failureCode(error);
      const measuredError = error instanceof OpenAIError || error instanceof ValidationError
        ? error
        : undefined;
      const usage = measuredError?.usage;
      await ctx.runMutation(internal.quota.recordTelemetry, {
        component: "suggestions",
        mode: "solo" as const,
        inputTokens: usage?.inputTokens ?? 0,
        cachedInputTokens: usage?.cachedInputTokens ?? 0,
        outputTokens: usage?.outputTokens ?? 0,
        durationMs: measuredError?.durationMs ?? Date.now() - startedAt,
        errorCode: code,
        variant: "split" as const,
        providerAttempts: measuredError?.providerAttempts ?? 1,
        webSearchCalls: 0,
      });
      if (reservation.slotId) {
        await ctx.runMutation(internal.quota.releaseReservation, {
          slotId: reservation.slotId,
        });
      }
      throw new ConvexError(code);
    }
  },
});

function validSuggestionSnapshot(value: SuggestionsSnapshot): boolean {
  const categories = [...value.dynamicSuggestions, ...value.staticSuggestions];
  return categories.length <= MAX_SUGGESTION_SNAPSHOT_CATEGORIES &&
    categories.every((category) =>
      category.title.length <= 160 &&
      category.texts.length <= MAX_SUGGESTION_SNAPSHOT_CARDS &&
      category.texts.every((text) =>
        text.length > 0 && text.length <= MAX_SUGGESTION_SNAPSHOT_TEXT_LENGTH
      )
    );
}

function validNearYouCandidates(candidates: NearYouCandidate[]): boolean {
  const ids = new Set<string>();
  return candidates.every((candidate) => {
    if (
      candidate.id.trim().length === 0 ||
      candidate.name.trim().length === 0 ||
      candidate.category.trim().length === 0 ||
      !Number.isFinite(candidate.distanceMetres) ||
      candidate.distanceMetres < 0 ||
      !Number.isFinite(candidate.walkingMinutes) ||
      candidate.walkingMinutes < 1 ||
      ids.has(candidate.id)
    ) {
      return false;
    }
    ids.add(candidate.id);
    return true;
  });
}

/**
 * Both failure families produce a stable code the client can map to copy.
 *
 * A `ValidationError` is deliberately distinct from an `OpenAIError`: the call
 * succeeded and was billed, and what failed was the content. Collapsing the two
 * into `generation_failed` would hide exactly the signal the D15 evaluation is
 * looking for.
 */
function failureCode(error: unknown): string {
  if (error instanceof OpenAIError) return error.code;
  if (error instanceof ValidationError) return `validation_${error.code}`;
  return "generation_failed";
}
