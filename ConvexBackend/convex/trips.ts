import { ConvexError, v } from "convex/values";
import { action } from "./_generated/server";
import { internal } from "./_generated/api";
import { generationComponent, runComponent } from "./lib/components";
import type { Component, SoloTripInput } from "./lib/prompts";
import { OpenAIError } from "./lib/openai";
import type { Reservation } from "./quota";
import {
  MAX_ALREADY_RECOMMENDED_ITEMS,
  MAX_CUSTOMIZATIONS_LENGTH,
  MAX_DESTINATION_INPUT_LENGTH,
  MAX_INTEREST_LENGTH,
  soloTripInput,
} from "./lib/validators";

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
  },
  handler: async (ctx, args): Promise<unknown> => {
    const component = args.component as Component;
    const input = args.input as SoloTripInput;

    if (!args.installToken || !args.tripKey) {
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

    // Throws a ConvexError carrying a QuotaCode when a limit is hit.
    const reservation: Reservation = await ctx.runMutation(internal.quota.reserve, {
      installToken: args.installToken,
      tripKey: args.tripKey,
      component: args.component,
      label: interest,
    });

    const startedAt = Date.now();
    try {
      const result = await runComponent({
        component,
        input: { mode: "solo", solo: input },
        interest,
        alreadyRecommended,
      });

      await ctx.runMutation(internal.quota.recordTelemetry, {
        component: args.component,
        mode: "solo" as const,
        inputTokens: result.usage.inputTokens,
        cachedInputTokens: result.usage.cachedInputTokens,
        outputTokens: result.usage.outputTokens,
        durationMs: result.durationMs,
      });
      if (reservation.slotId) {
        await ctx.runMutation(internal.quota.commitReservation, {
          slotId: reservation.slotId,
        });
      }
      return result.data;
    } catch (error) {
      const code = error instanceof OpenAIError ? error.code : "generation_failed";
      await ctx.runMutation(internal.quota.recordTelemetry, {
        component: args.component,
        mode: "solo" as const,
        inputTokens: 0,
        cachedInputTokens: 0,
        outputTokens: 0,
        durationMs: Date.now() - startedAt,
        errorCode: code,
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
