import { v } from "convex/values";
import {
  DEEP_DIVE_SCHEMA,
  ITINERARY_SCHEMA,
  WHERE_TO_STAY_SCHEMA,
  WORTH_IT_SCHEMA,
  suggestionsSchema,
} from "./schemas";
import {
  buildSystemPrompt,
  buildUserMessage,
  type Component,
  type PromptOptions,
  type TripInput,
} from "./prompts";
import { callOpenAI, type OpenAIResult } from "./openai";
import {
  emptyReport,
  validateDeepDive,
  validateItinerary,
  validateSuggestions,
  validateWhereToStayResponse,
  validateWorthItResponse,
  type ValidationReport,
} from "./validation";

export type { Component } from "./prompts";

/** Wire validator for the component name. Shared by every entry point. */
export const generationComponent = v.union(
  v.literal("itinerary"),
  v.literal("suggestions"),
  v.literal("deepDive"),
  v.literal("worthIt"),
  v.literal("whereToStay"),
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
    ? ["itinerary", "suggestions"]
    : ["itinerary", "suggestions", "worthIt", "whereToStay"];
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
    // Observed max 547. Four cards is a fixed shape, so this barely varies.
    maxOutputTokens: 2_048,
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
};

/** Resolves the schema, ceiling and prompt options for one run. */
export function componentSpec(
  component: Component,
  variant: SuggestionsVariant,
): ComponentSpec & { promptOptions: PromptOptions } {
  const base = COMPONENTS[component];
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
};

/**
 * Composes prompt + schema + ceiling for one component, makes the call, and
 * validates what comes back before anyone commits it.
 *
 * Validation lives here rather than at each entry point on purpose: strict mode
 * guarantees the *shape*, never the counts or the lengths, and a rule enforced
 * in one of the two entry points is a rule the other one silently doesn't have.
 */
export async function runComponent(args: {
  component: Component;
  input: TripInput;
  interest?: string;
  alreadyRecommended?: string[];
  variant?: SuggestionsVariant;
}): Promise<ComponentResult> {
  const variant = args.variant ?? SUGGESTIONS_VARIANT;
  const spec = componentSpec(args.component, variant);

  const result = await callOpenAI({
    systemPrompt: buildSystemPrompt(
      args.component,
      args.input.mode,
      spec.promptOptions,
    ),
    userPrompt: buildUserMessage(args.input, {
      interest: args.interest,
      alreadyRecommended: args.alreadyRecommended,
    }),
    schema: spec.schema,
    schemaName: spec.schemaName,
    maxOutputTokens: spec.maxOutputTokens,
  });

  const validation = emptyReport();
  const data = validate(args.component, result.data, validation);
  return { ...result, data, validation, maxOutputTokens: spec.maxOutputTokens };
}

function validate(
  component: Component,
  data: unknown,
  report: ValidationReport,
): unknown {
  switch (component) {
    case "itinerary":
      return validateItinerary(data, report);
    case "suggestions":
      return validateSuggestions(data, report);
    case "deepDive":
      return validateDeepDive(data, report);
    case "worthIt":
      return validateWorthItResponse(data, report);
    case "whereToStay":
      return validateWhereToStayResponse(data, report);
  }
}
