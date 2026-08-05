import { v } from "convex/values";
import {
  DEEP_DIVE_SCHEMA,
  ITINERARY_SCHEMA,
  SUGGESTIONS_SCHEMA,
} from "./schemas";
import {
  buildSystemPrompt,
  buildUserMessage,
  type Component,
  type TripInput,
} from "./prompts";
import { callOpenAI, type OpenAIResult } from "./openai";

export type { Component } from "./prompts";

/** Wire validator for the component name. Shared by every entry point. */
export const generationComponent = v.union(
  v.literal("itinerary"),
  v.literal("suggestions"),
  v.literal("deepDive"),
);

export const tripMode = v.union(v.literal("solo"), v.literal("group"));

type ComponentSpec = {
  schema: unknown;
  schemaName: string;
  maxOutputTokens: number;
  /**
   * A required component's failure fails the whole generation. Everything else
   * is best-effort: it commits `failed(code)` for itself and the trip still
   * becomes ready. This formalises the split the group action already had.
   */
  required: boolean;
  /** Committed results allowed per trip, or `null` for uncapped. */
  perTripCap: number | null;
};

export const COMPONENTS: Record<Component, ComponentSpec> = {
  itinerary: {
    schema: ITINERARY_SCHEMA,
    schemaName: "travel_itinerary_schema",
    maxOutputTokens: 8_192,
    required: true,
    perTripCap: null,
  },
  suggestions: {
    schema: SUGGESTIONS_SCHEMA,
    schemaName: "travel_suggestions_schema",
    // Carried over unchanged from the device client. This ceiling is a known
    // risk once the suggestions call grows: a truncated response fails strict
    // decode outright. Re-derive it from the `incomplete_max_output_tokens`
    // rate in real telemetry — never raise it on a hunch.
    maxOutputTokens: 4_096,
    required: false,
    perTripCap: null,
  },
  deepDive: {
    schema: DEEP_DIVE_SCHEMA,
    schemaName: "travel_deep_dive_schema",
    maxOutputTokens: 1_536,
    required: false,
    // D9. Enforced server-side in `quota.ts`; the client's own cap is a
    // courtesy, not the control.
    perTripCap: 3,
  },
};

/** Composes prompt + schema + ceiling for one component and makes the call. */
export async function runComponent(args: {
  component: Component;
  input: TripInput;
  interest?: string;
  alreadyRecommended?: string[];
}): Promise<OpenAIResult> {
  const spec = COMPONENTS[args.component];
  return callOpenAI({
    systemPrompt: buildSystemPrompt(args.component, args.input.mode),
    userPrompt: buildUserMessage(args.input, {
      interest: args.interest,
      alreadyRecommended: args.alreadyRecommended,
    }),
    schema: spec.schema,
    schemaName: spec.schemaName,
    maxOutputTokens: spec.maxOutputTokens,
  });
}
