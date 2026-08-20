import {
  buildSuggestionTopUpSystemPrompt,
  buildSuggestionTopUpUserMessage,
  type SuggestionTopUpPromptPlan,
  type SuggestionTopUpPromptTarget,
  type TripInput,
} from "./prompts";
import { callOpenAI, type OpenAIResult } from "./openai";
import { suggestionsTopUpSchema } from "./schemas";
import { emptyReport, validateSuggestions, type ValidationReport } from "./validation";

const MIN_CARDS = 4;
const MAX_CARDS = 5;
const MAX_OUTPUT_TOKENS = 3_072;
const DYNAMIC_IDS = ["cafes", "vibe", "new", "rainy", "random"];

export type SuggestionCategorySnapshot = {
  ID?: string | null;
  title: string;
  texts: string[];
};

export type SuggestionsSnapshot = {
  dynamicSuggestions: SuggestionCategorySnapshot[];
  staticSuggestions: SuggestionCategorySnapshot[];
};

export type SuggestionTopUpPlan = SuggestionTopUpPromptPlan & {
  complete: boolean;
  partyID: string;
};

type RecordValue = Record<string, unknown>;

/** Classifies a readable first response and describes only what it lacks. */
export function suggestionTopUpPlan(
  existing: SuggestionsSnapshot,
  input: TripInput,
): SuggestionTopUpPlan {
  const partyID = expectedPartyID(input);
  const dynamic = existing.dynamicSuggestions.find((category) =>
    category.ID != null && DYNAMIC_IDS.includes(category.ID)
  ) ?? null;
  const month = categoryWithID(existing.staticSuggestions, "month");
  const party = categoryWithID(existing.staticSuggestions, partyID);
  const avoid = categoryWithID(existing.staticSuggestions, "avoid");

  const plan = {
    dynamic: target(dynamic, dynamic?.ID ? [dynamic.ID] : DYNAMIC_IDS),
    month: target(month, ["month"]),
    party: target(party, [partyID]),
    avoid: target(avoid, ["avoid"]),
  };
  return {
    ...plan,
    complete: Object.values(plan).every((value) => value === null),
    partyID,
  };
}

function target(
  existing: SuggestionCategorySnapshot | null,
  ids: string[],
): SuggestionTopUpPromptTarget | null {
  const texts = existing?.texts.filter((text) => text.trim().length > 0) ?? [];
  const count = Math.max(0, MIN_CARDS - texts.length);
  if (count === 0) return null;
  return {
    ids,
    count,
    existingTitle: existing?.title?.trim() || null,
    existingTexts: texts.slice(0, MAX_CARDS),
  };
}

function categoryWithID(
  categories: SuggestionCategorySnapshot[],
  id: string,
): SuggestionCategorySnapshot | null {
  return categories.find((category) => category.ID === id) ?? null;
}

export function expectedPartyID(input: TripInput): string {
  if (input.mode === "group") return "group";
  switch (input.solo.groupType.toLowerCase()) {
    case "couple":
    case "couples":
      return "couples";
    case "family":
      return "family";
    case "group":
      return "group";
    default:
      return "solo";
  }
}

export type SuggestionTopUpResult = OpenAIResult & {
  validation: ValidationReport;
  maxOutputTokens: number;
  providerAttempts: number;
};

/** Runs one bounded, focused completion call. It never regenerates good cards. */
export async function runSuggestionTopUp(args: {
  input: TripInput;
  existing: SuggestionsSnapshot;
  alreadyRecommended?: string[];
  callProvider?: typeof callOpenAI;
}): Promise<SuggestionTopUpResult | null> {
  const plan = suggestionTopUpPlan(args.existing, args.input);
  if (plan.complete) return null;

  const provider = args.callProvider ?? callOpenAI;
  const result = await provider({
    systemPrompt: buildSuggestionTopUpSystemPrompt(args.input.mode, plan),
    userPrompt: buildSuggestionTopUpUserMessage(
      args.input,
      plan,
      args.alreadyRecommended,
    ),
    schema: suggestionsTopUpSchema(plan),
    schemaName: "travel_suggestions_top_up_schema",
    maxOutputTokens: MAX_OUTPUT_TOKENS,
  });

  const raw = isRecord(result.data) ? result.data : {};
  const dynamic = isRecord(raw.dynamic) ? [raw.dynamic] : [];
  const staticSuggestions = [raw.month, raw.party, raw.avoid].filter(isRecord);
  const validation = emptyReport();
  const data = validateSuggestions(
    { dynamicSuggestions: dynamic, staticSuggestions },
    validation,
  );
  return {
    ...result,
    data,
    validation,
    maxOutputTokens: MAX_OUTPUT_TOKENS,
    providerAttempts: 1,
  };
}

/**
 * Append-only merge used by group generation. The Swift client mirrors this
 * rule for solo trips: existing IDs and card order win, additions fill toward
 * five, and a duplicate top-up card is ignored.
 */
export function mergeSuggestions(
  existing: unknown,
  additions: unknown,
  input: TripInput,
): RecordValue {
  const base = isRecord(existing) ? existing : {};
  const patch = isRecord(additions) ? additions : {};
  const dynamic = mergeCategoryArrays(
    arrayOfRecords(base.dynamicSuggestions),
    arrayOfRecords(patch.dynamicSuggestions),
  );
  const staticMerged = mergeCategoryArrays(
    arrayOfRecords(base.staticSuggestions),
    arrayOfRecords(patch.staticSuggestions),
  );
  const partyID = expectedPartyID(input);
  const orderedStatic: RecordValue[] = [];
  const used = new Set<RecordValue>();
  for (const id of ["month", partyID, "avoid"]) {
    const category = staticMerged.find((candidate) => candidate.ID === id);
    if (category) {
      orderedStatic.push(category);
      used.add(category);
    }
  }
  orderedStatic.push(...staticMerged.filter((category) => !used.has(category)));
  return {
    ...base,
    dynamicSuggestions: dynamic,
    staticSuggestions: orderedStatic,
  };
}

function mergeCategoryArrays(base: RecordValue[], patch: RecordValue[]): RecordValue[] {
  const result = [...base];
  for (const addition of patch) {
    const id = typeof addition.ID === "string" ? addition.ID : null;
    const index = result.findIndex((category) =>
      id != null && category.ID === id
    );
    if (index < 0) {
      result.push(addition);
      continue;
    }
    const current = result[index];
    const texts = arrayOfRecords(current.texts);
    const seen = new Set(texts.map(textKey));
    for (const card of arrayOfRecords(addition.texts)) {
      if (texts.length >= MAX_CARDS) break;
      const key = textKey(card);
      if (!key || seen.has(key)) continue;
      seen.add(key);
      texts.push(card);
    }
    result[index] = { ...current, texts };
  }
  return result;
}

function textKey(card: RecordValue): string {
  return typeof card.text === "string"
    ? card.text.toLowerCase().replace(/\s+/g, " ").trim()
    : "";
}

function isRecord(value: unknown): value is RecordValue {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function arrayOfRecords(value: unknown): RecordValue[] {
  return Array.isArray(value) ? value.filter(isRecord) : [];
}
