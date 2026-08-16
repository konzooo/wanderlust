import { v } from "convex/values";
import {
  DEEP_DIVE_SCHEMA,
  ITINERARY_SCHEMA,
  KNOW_BEFORE_YOU_GO_SCHEMA,
  NEAR_YOU_SCHEMA,
  WHERE_TO_STAY_SCHEMA,
  WORTH_IT_SCHEMA,
  itinerarySchema,
  suggestionsSchema,
} from "./schemas";
import {
  buildSystemPrompt,
  buildUserMessage,
  type Component,
  type NearYouCandidate,
  type NearYouLocationContext,
  type PromptOptions,
  type TripInput,
} from "./prompts";
import {
  callOpenAI,
  NEAR_YOU_MODEL,
  OpenAIError,
  WORTH_IT_MODEL,
  type OpenAIReasoningEffort,
  type OpenAIResult,
  type OpenAIUsage,
} from "./openai";
import {
  emptyReport,
  validateDeepDive,
  validateItinerary,
  validateNearYou,
  validateSuggestions,
  validateWhereToStayResponse,
  validateWorthItResponse,
  ValidationError,
  type ValidationReport,
} from "./validation";

export type { Component } from "./prompts";

/** Wire validator for the component name. Shared by every entry point. */
export const generationComponent = v.union(
  v.literal("itinerary"),
  v.literal("suggestions"),
  v.literal("deepDive"),
  v.literal("knowBeforeYouGo"),
  v.literal("worthIt"),
  v.literal("whereToStay"),
  v.literal("nearYou"),
);

export const tripMode = v.union(v.literal("solo"), v.literal("group"));

/**
 * D15, expressed as code rather than as an argument.
 *
 * `combined` asks one suggestions call for the themed categories, the
 * Worth-it/Skip cards and the where-to-stay guide together. `split` keeps the
 * suggestions call at its pre-S5 size and runs the two new sections as their
 * own focused calls in parallel.
 *
 * Both are real, shippable paths, because the plan refuses to settle this by
 * argument: call count is not the billing unit, and the things that actually
 * decide it — output tokens, wall-clock, truncation rate, decode failures —
 * cannot be reasoned about from the shape of the code. See `eval/` for the
 * matrix that produced the current default and `docs/d15-decision.md` for the
 * numbers behind it.
 */
export type SuggestionsVariant = "combined" | "split";

export const suggestionsVariant = v.union(
  v.literal("combined"),
  v.literal("split"),
);

/** The measured default. Changing this changes what every new trip generates. */
export const SUGGESTIONS_VARIANT: SuggestionsVariant = "split";

/** Request one broad hosted search; one action can return many source URLs. */
export const NEAR_YOU_MAX_SEARCH_CALLS = 1;

/**
 * The components a solo trip generates on open, for a given variant.
 *
 * Deep dives are deliberately absent: one is only ever generated because the
 * traveller tapped a chip.
 */
export function automaticComponents(
  variant: SuggestionsVariant = SUGGESTIONS_VARIANT,
): Component[] {
  return variant === "combined"
    ? ["itinerary", "suggestions", "knowBeforeYouGo"]
    : [
        "itinerary",
        "suggestions",
        "knowBeforeYouGo",
        "worthIt",
        "whereToStay",
      ];
}

/**
 * Token ceilings for the two suggestions shapes.
 *
 * Measured, not guessed — V13's rule is that this number only ever moves on
 * evidence. Each is roughly 3× the largest output seen across the §13 matrix
 * (`docs/d15-decision.md`), which is headroom for a destination denser than the
 * sample while still bounding a runaway response.
 *
 * Observed maxima over 16 runs: combined 1,911 · split 996.
 *
 * Note which direction the risk runs. An unused ceiling costs nothing — you are
 * billed for tokens produced, not for tokens allowed — so a ceiling that is too
 * low buys no saving and converts a long answer into a hard decode failure. The
 * reason not to simply set it enormous is to cap the worst case, not the mean.
 */
const SUGGESTIONS_MAX_OUTPUT_TOKENS_SPLIT = 3_072;
const SUGGESTIONS_MAX_OUTPUT_TOKENS_COMBINED = 6_144;

type ComponentSpec = {
  schema: unknown;
  schemaName: string;
  maxOutputTokens: number;
  /** Optional component-specific model route; otherwise use the default. */
  model?: string;
  /** Always explicit when a routed model supports configurable reasoning. */
  reasoning?: { effort: OpenAIReasoningEffort };
  /**
   * A required component's failure fails the whole generation. Everything else
   * is best-effort: it commits `failed(code)` for itself and the trip still
   * becomes ready. This formalises the split the group action already had.
   */
  required: boolean;
  /** Committed results allowed per trip, or `null` for uncapped. */
  perTripCap: number | null;
};

/**
 * Per-component specs.
 *
 * The suggestions entry is variant-dependent, so it is resolved through
 * `componentSpec` rather than read straight out of this table. Everything that
 * does not depend on the variant — required-ness and per-trip caps — stays
 * here, where both entry points already look for it.
 */
export const COMPONENTS: Record<Component, ComponentSpec> = {
  itinerary: {
    schema: ITINERARY_SCHEMA,
    schemaName: "travel_itinerary_schema",
    maxOutputTokens: 8_192,
    required: true,
    perTripCap: null,
  },
  suggestions: {
    // Placeholder shape; the live one comes from `componentSpec`, which knows
    // whether this run is carrying the extras.
    schema: suggestionsSchema({ extras: false, interestPrompts: true }),
    schemaName: "travel_suggestions_schema",
    maxOutputTokens: SUGGESTIONS_MAX_OUTPUT_TOKENS_SPLIT,
    required: false,
    perTripCap: null,
  },
  knowBeforeYouGo: {
    schema: KNOW_BEFORE_YOU_GO_SCHEMA,
    schemaName: "know_before_you_go_schema",
    // Measured, not estimated: the six §13 evaluation cases (see
    // `tools/kbyg-eval.ts` and the fixtures beside it) produce 9–12 sections at
    // 944–1,522 output tokens. The ceiling sits well above that on purpose —
    // truncation is not a short answer here, it is a hard strict-decode failure
    // — and a cap costs nothing when it is not reached. Re-derive it from the
    // `incomplete_` rate in real telemetry, never from arithmetic.
    maxOutputTokens: 6_144,
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
  worthIt: {
    schema: WORTH_IT_SCHEMA,
    schemaName: "travel_worth_it_schema",
    // Observed max 547 when the section returned four cards.
    maxOutputTokens: 2_048,
    model: WORTH_IT_MODEL,
    // This is an editorial classification task, not a multi-step reasoning
    // task. Explicitly opt out of Luna's default reasoning budget.
    reasoning: { effort: "none" },
    required: false,
    perTripCap: null,
  },
  whereToStay: {
    schema: WHERE_TO_STAY_SCHEMA,
    schemaName: "travel_where_to_stay_schema",
    // Observed max 854; 3× rounded to the next 512.
    maxOutputTokens: 2_560,
    required: false,
    perTripCap: null,
  },
  nearYou: {
    schema: NEAR_YOU_SCHEMA,
    schemaName: "grounded_near_you_schema",
    // Live finds add sourced discovery fields to the grounded selection. The
    // ceiling is deliberately headroom rather than a target; billing follows
    // tokens produced, while a too-small ceiling turns a useful long result
    // into an incomplete strict-JSON failure.
    maxOutputTokens: 4_096,
    model: NEAR_YOU_MODEL,
    required: false,
    perTripCap: null,
  },
};

/** Resolves the schema, ceiling and prompt options for one run. */
export function componentSpec(
  component: Component,
  variant: SuggestionsVariant,
  expectedDurationDays?: number,
): ComponentSpec & { promptOptions: PromptOptions } {
  const base = COMPONENTS[component];
  if (component === "itinerary") {
    return {
      ...base,
      schema: itinerarySchema(expectedDurationDays),
      promptOptions: { extras: false, interestPrompts: false },
    };
  }
  if (component !== "suggestions") {
    return { ...base, promptOptions: { extras: false, interestPrompts: false } };
  }
  const extras = variant === "combined";
  return {
    ...base,
    schema: suggestionsSchema({ extras, interestPrompts: true }),
    maxOutputTokens: extras
      ? SUGGESTIONS_MAX_OUTPUT_TOKENS_COMBINED
      : SUGGESTIONS_MAX_OUTPUT_TOKENS_SPLIT,
    promptOptions: { extras, interestPrompts: true },
  };
}

/** A completed call, plus what validation had to do to it. */
export type ComponentResult = OpenAIResult & {
  validation: ValidationReport;
  /** The ceiling this call ran under, so telemetry can relate the two. */
  maxOutputTokens: number;
  /** One normally; two when the bounded itinerary correction was needed. */
  providerAttempts: number;
};

/**
 * Composes prompt + schema + ceiling for one component, makes the call, and
 * validates what comes back before anyone commits it.
 *
 * Validation lives here rather than at each entry point on purpose. The
 * duration-aware schema owns the itinerary count; application validation still
 * owns semantic checks and best-effort repair. Keeping both here prevents solo
 * and group generation from drifting apart.
 */
export async function runComponent(args: {
  component: Component;
  input: TripInput;
  interest?: string;
  alreadyRecommended?: string[];
  nearYouCandidates?: NearYouCandidate[];
  nearYouLocation?: NearYouLocationContext;
  variant?: SuggestionsVariant;
  /** Charges the second provider call before an automatic correction. */
  beforeValidationRetry?: (error: ValidationError) => Promise<void>;
  /** Deterministic test seam; production always uses `callOpenAI`. */
  callProvider?: typeof callOpenAI;
}): Promise<ComponentResult> {
  const variant = args.variant ?? SUGGESTIONS_VARIANT;
  const expectedDurationDays = durationDays(args.input);
  const spec = componentSpec(args.component, variant, expectedDurationDays);
  const provider = args.callProvider ?? callOpenAI;
  const baseUserPrompt = buildUserMessage(args.input, {
    interest: args.interest,
    alreadyRecommended: args.alreadyRecommended,
    nearYouCandidates: args.nearYouCandidates,
    nearYouLocation: args.nearYouLocation,
  });
  const accumulatedUsage = emptyUsage();
  let accumulatedDurationMs = 0;
  let providerAttempts = 0;

  for (let attempt = 1; attempt <= 2; attempt += 1) {
    providerAttempts += 1;
    let result: OpenAIResult;
    try {
      result = await provider({
        systemPrompt: buildSystemPrompt(
          args.component,
          args.input.mode,
          spec.promptOptions,
        ),
        userPrompt:
          attempt === 1
            ? baseUserPrompt
            : itineraryCorrectionPrompt(baseUserPrompt, expectedDurationDays),
        schema: spec.schema,
        schemaName: spec.schemaName,
        maxOutputTokens: spec.maxOutputTokens,
        ...(spec.model ? { model: spec.model } : {}),
        ...(spec.reasoning ? { reasoning: spec.reasoning } : {}),
        ...(args.component === "nearYou"
          ? {
            webSearch: {
              maxToolCalls: NEAR_YOU_MAX_SEARCH_CALLS,
              approximateLocation: {
                city: args.nearYouLocation?.city ?? destination(args.input),
              },
            },
          }
          : {}),
      });
    } catch (error) {
      if (error instanceof OpenAIError && providerAttempts > 1) {
        throw new OpenAIError(
          error.code,
          addUsage(accumulatedUsage, error.usage),
          accumulatedDurationMs + (error.durationMs ?? 0),
          providerAttempts,
        );
      }
      throw error;
    }

    addUsageInPlace(accumulatedUsage, result.usage);
    accumulatedDurationMs += result.durationMs;
    const validation = emptyReport();
    try {
      const data = validate(
        args.component,
        result.data,
        validation,
        args.nearYouCandidates,
        result.webSources,
        expectedDurationDays,
      );
      return {
        ...result,
        data,
        usage: accumulatedUsage,
        durationMs: accumulatedDurationMs,
        validation,
        maxOutputTokens: spec.maxOutputTokens,
        providerAttempts,
      };
    } catch (error) {
      if (!(error instanceof ValidationError)) throw error;
      error.withMetrics(
        { ...accumulatedUsage },
        accumulatedDurationMs,
        providerAttempts,
      );
      if (!shouldRetryItinerary(args.component, error, attempt)) throw error;
      await args.beforeValidationRetry?.(error);
    }
  }

  throw new Error("unreachable_component_generation_state");
}

function shouldRetryItinerary(
  component: Component,
  error: ValidationError,
  attempt: number,
): boolean {
  return component === "itinerary" &&
    attempt === 1 &&
    (error.code === "incomplete_itinerary" || error.code === "empty_itinerary");
}

function itineraryCorrectionPrompt(basePrompt: string, expectedDurationDays: number): string {
  const days = Math.max(1, Math.round(expectedDurationDays));
  const countRule = days <= 5
    ? `Return exactly ${days} non-empty itinerary segments, one for each day.`
    : "Return two to five non-empty ranged segments that cover every requested day.";
  return `${basePrompt}\n\nCORRECTION\nThe previous itinerary did not cover the requested duration. Regenerate it from scratch. ${countRule}`;
}

function emptyUsage(): OpenAIUsage {
  return {
    inputTokens: 0,
    cachedInputTokens: 0,
    outputTokens: 0,
    reasoningTokens: 0,
  };
}

function addUsageInPlace(total: OpenAIUsage, next: OpenAIUsage): void {
  total.inputTokens += next.inputTokens;
  total.cachedInputTokens += next.cachedInputTokens;
  total.outputTokens += next.outputTokens;
  total.reasoningTokens += next.reasoningTokens;
}

function addUsage(total: OpenAIUsage, next?: OpenAIUsage): OpenAIUsage {
  const combined = { ...total };
  if (next) addUsageInPlace(combined, next);
  return combined;
}

function validate(
  component: Component,
  data: unknown,
  report: ValidationReport,
  nearYouCandidates?: NearYouCandidate[],
  webSources: OpenAIResult["webSources"] = [],
  expectedDurationDays?: number,
): unknown {
  switch (component) {
    case "itinerary":
      return validateItinerary(data, report, expectedDurationDays);
    case "suggestions":
      return validateSuggestions(data, report);
    case "deepDive":
      return validateDeepDive(data, report);
    case "knowBeforeYouGo":
      // KBYG's conditional stable/verify rule is resolved by CoreModels after
      // decode; the strict schema already owns its backend shape.
      return data;
    case "worthIt":
      return validateWorthItResponse(data, report);
    case "whereToStay":
      return validateWhereToStayResponse(data, report);
    case "nearYou":
      return validateNearYou(data, report, nearYouCandidates ?? [], webSources);
  }
}

function destination(input: TripInput): string {
  return input.mode === "solo" ? input.solo.destination : input.group.destination;
}

function durationDays(input: TripInput): number {
  return input.mode === "solo" ? input.solo.durationDays : input.group.durationDays;
}
