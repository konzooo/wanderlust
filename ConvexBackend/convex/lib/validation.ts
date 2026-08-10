/**
 * Post-decode validation for structured output.
 *
 * §3 of the plan: strict JSON Schema can express "this property exists and is a
 * string". It cannot express "between two and four of these", "between four and six",
 * "at most 28 characters", or "required only when X" — `minItems`, `maxItems`
 * and conditional subschemas are all ignored under `strict: true`. Every one of
 * those rules therefore has to be enforced here, in application code, **with a
 * defined fallback** rather than an exception.
 *
 * The defined fallback is always the same shape: repair what is repairable,
 * count the repair so it lands in telemetry, and reject only when what came
 * back is unusable. A component the traveller can still read is worth more than
 * a hard failure, but a silent repair nobody can see would let the model drift
 * without anyone noticing — which is exactly what the D15 measurement needs to
 * be able to detect.
 */

import type { OpenAIWebSource } from "./openai";
import type { NearYouCandidate } from "./prompts";

/** Maximum number of cards Worth-it/Skip shows (D7). */
export const WORTH_IT_COUNT = 4;
/** Below this the section is not worth rendering at all. */
const WORTH_IT_MIN = 2;

/** Where-to-stay compares four to six areas (D10). */
const STAY_MIN = 3;
const STAY_MAX = 6;

/** Model-picked interest chips (D8). The app adds three fixed ones. */
export const INTEREST_PROMPT_COUNT = 3;
const INTEREST_PROMPT_MAX_LENGTH = 40;

/** Chips the app already shows; a model-picked duplicate is dropped (D8). */
const FIXED_INTEREST_CHIPS = ["running routes", "remote-work cafes", "climbing gyms"];

export class ValidationError extends Error {
  constructor(public readonly code: string) {
    super(code);
    this.name = "ValidationError";
  }
}

/**
 * What validation had to do to a response.
 *
 * `repairs` is the number of individual fixes applied — a truncated array, a
 * dropped malformed item, an over-long label. It is recorded per call so a
 * prompt that quietly stopped obeying its own instructions shows up as a rising
 * repair rate rather than as a vague sense that output got worse.
 */
export type ValidationReport = {
  repairs: number;
  /** Set when a whole optional section had to be discarded. */
  droppedSections: string[];
};

export function emptyReport(): ValidationReport {
  return { repairs: 0, droppedSections: [] };
}

// MARK: - Primitives ----------------------------------------------------------

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nonEmptyString(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

/** Every prose field present and non-blank. A card missing one cannot render. */
function hasProse(item: Record<string, unknown>, fields: string[]): boolean {
  return fields.every((field) => nonEmptyString(item[field]));
}

// MARK: - Link repair ----------------------------------------------------------

/**
 * Makes `linkSubstring` an actual substring of the text it belongs to.
 *
 * The app turns a place name into a tap target by searching the rendered text
 * for `linkSubstring`. A substring that isn't in the text is a link that
 * silently doesn't render — invisible in the JSON, missing for every traveller.
 *
 * The §13 matrix put a number on how often that happens: across a full run only
 * 65-70% of location entries resolved overall, and 16% in the where-to-stay
 * guide. The failure was almost always the same one — the model writing the
 * full searchable name into both fields, so the text says "Chök" and the
 * substring says "Chök, Barcelona".
 *
 * Tightening the prompt fixed it at source (97-98% on the re-run, and this
 * repair did not have to fire once). It stays as the net underneath: the same
 * mistake will come back the next time the model changes, and it should cost a
 * counted repair rather than a feature that quietly stops working.
 *
 * That specific mistake is deterministically repairable: drop the trailing
 * comma-separated qualifiers until what is left is genuinely present. No model
 * call, no guessing. `placeName` is never touched — it is the searchable name,
 * and it is also what §11 derives `alreadyRecommended` from.
 */
function repairLocations(
  container: Record<string, unknown>,
  textFields: string[],
  report: ValidationReport,
): void {
  const locations = container.locations;
  if (!Array.isArray(locations)) return;

  const haystack = textFields
    .map((field) => (typeof container[field] === "string" ? (container[field] as string) : ""))
    .join(" \0 ")
    .toLowerCase();

  for (const location of locations) {
    if (!isRecord(location)) continue;
    const raw = location.linkSubstring;
    if (typeof raw !== "string" || raw.trim().length === 0) continue;
    if (haystack.includes(raw.toLowerCase().trim())) continue;

    const repaired = longestPresentPrefix(raw, haystack);
    if (repaired && repaired !== raw) {
      location.linkSubstring = repaired;
      report.repairs += 1;
    }
  }
}

/**
 * "Chök, Barcelona" → "Chök", if that is what the text actually says.
 *
 * Only ever shortens, and only on comma boundaries: a looser match would start
 * linking the wrong words. A prefix under three characters is rejected, because
 * linking "El" everywhere it appears is worse than not linking at all.
 */
function longestPresentPrefix(value: string, haystack: string): string | null {
  const parts = value.split(",");
  for (let take = parts.length - 1; take >= 1; take--) {
    const candidate = parts.slice(0, take).join(",").trim();
    if (candidate.length >= 3 && haystack.includes(candidate.toLowerCase())) {
      return candidate;
    }
  }
  return null;
}

// MARK: - Sections ------------------------------------------------------------

/**
 * Worth-it/Skip: two to four usable cards.
 *
 * Extra cards are dropped rather than kept — four is the product maximum (D7),
 * and a fifth card would render but would not have been designed for. Below two
 * usable cards the section is too thin to render as a decision set.
 */
export function validateWorthIt(
  raw: unknown,
  report: ValidationReport,
): Record<string, unknown>[] | null {
  if (!Array.isArray(raw)) return null;

  const fields = ["place", "theCase", "theCatch", "verdict"];
  const usable = raw.filter((item) => isRecord(item) && hasProse(item, fields));
  report.repairs += raw.length - usable.length;
  // The card's own title is rendered as linkable text too, so it counts as
  // haystack — the place a card is about is named there and nowhere else.
  for (const item of usable) repairLocations(item as Record<string, unknown>, fields, report);

  if (usable.length < WORTH_IT_MIN) {
    if (raw.length > 0) report.droppedSections.push("worthIt");
    return null;
  }
  if (usable.length > WORTH_IT_COUNT) report.repairs += 1;
  return usable.slice(0, WORTH_IT_COUNT) as Record<string, unknown>[];
}

/** Where-to-stay: three to six usable areas, same discipline. */
export function validateWhereToStay(
  raw: unknown,
  report: ValidationReport,
): Record<string, unknown>[] | null {
  if (!Array.isArray(raw)) return null;

  const fields = ["area", "theCase", "bestFor", "watchOut"];
  const usable = raw.filter((item) => isRecord(item) && hasProse(item, fields));
  report.repairs += raw.length - usable.length;
  for (const item of usable) repairLocations(item as Record<string, unknown>, fields, report);

  if (usable.length < STAY_MIN) {
    if (raw.length > 0) report.droppedSections.push("whereToStay");
    return null;
  }
  if (usable.length > STAY_MAX) report.repairs += 1;
  return usable.slice(0, STAY_MAX) as Record<string, unknown>[];
}

/**
 * Interest prompts: up to three short, distinct labels.
 *
 * Unlike the two sections above this one degrades to `[]` rather than to
 * `null`, because the app always renders three fixed chips regardless — an
 * empty model contribution costs the traveller nothing and there is no failure
 * to explain.
 */
export function validateInterestPrompts(
  raw: unknown,
  report: ValidationReport,
): string[] {
  if (!Array.isArray(raw)) return [];

  // Seeded through the same normaliser the candidates go through, or the
  // comparison never matches: "Climbing Gyms" normalises to "climbing-gyms"
  // and would sail past a set holding the raw "climbing gyms".
  const seen = new Set(FIXED_INTEREST_CHIPS.map(normaliseChip));
  const result: string[] = [];
  for (const entry of raw) {
    if (!nonEmptyString(entry)) {
      report.repairs += 1;
      continue;
    }
    const label = entry.trim().replace(/\s+/g, " ");
    const key = normaliseChip(label);
    if (seen.has(key) || label.length > INTEREST_PROMPT_MAX_LENGTH) {
      report.repairs += 1;
      continue;
    }
    seen.add(key);
    result.push(label);
  }
  if (result.length > INTEREST_PROMPT_COUNT) report.repairs += 1;
  return result.slice(0, INTEREST_PROMPT_COUNT);
}

/** Folds accents and punctuation so "Remote-work cafés" matches the fixed chip. */
function normaliseChip(label: string): string {
  return label
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

// MARK: - Whole responses -----------------------------------------------------

/**
 * Validates and repairs a suggestions response in place, whichever variant
 * produced it.
 *
 * The categories themselves are the one part that can genuinely fail the call:
 * a suggestions response with no readable category is not a degraded feed, it
 * is an empty screen, and the client needs a `failed` state it can retry rather
 * than a successful-looking empty result.
 */
export function validateSuggestions(
  data: unknown,
  report: ValidationReport,
): Record<string, unknown> {
  if (!isRecord(data)) throw new ValidationError("invalid_suggestions_shape");

  const dynamic = validateCategories(data.dynamicSuggestions, report);
  const staticCategories = validateCategories(data.staticSuggestions, report);
  if (dynamic.length + staticCategories.length === 0) {
    throw new ValidationError("empty_suggestions");
  }

  const result: Record<string, unknown> = {
    dynamicSuggestions: dynamic,
    staticSuggestions: staticCategories,
  };

  if ("interestPrompts" in data) {
    result.interestPrompts = validateInterestPrompts(data.interestPrompts, report);
  }
  if ("worthIt" in data) {
    const worthIt = validateWorthIt(data.worthIt, report);
    if (worthIt) result.worthIt = worthIt;
  }
  if ("whereToStay" in data) {
    const whereToStay = validateWhereToStay(data.whereToStay, report);
    if (whereToStay) result.whereToStay = whereToStay;
  }
  return result;
}

/** A category with no readable text is dropped; the app cannot render it. */
function validateCategories(
  raw: unknown,
  report: ValidationReport,
): Record<string, unknown>[] {
  if (!Array.isArray(raw)) return [];
  const usable = raw.filter(
    (category) =>
      isRecord(category) &&
      nonEmptyString(category.title) &&
      Array.isArray(category.texts) &&
      category.texts.some((t) => isRecord(t) && nonEmptyString(t.text)),
  );
  report.repairs += raw.length - usable.length;
  for (const category of usable) repairTexts((category as Record<string, unknown>).texts, report);
  return usable as Record<string, unknown>[];
}

/** Repairs a `[{text, locations}]` array in place — the feed's common shape. */
function repairTexts(raw: unknown, report: ValidationReport): void {
  if (!Array.isArray(raw)) return;
  for (const entry of raw) {
    if (isRecord(entry)) repairLocations(entry, ["text"], report);
  }
}

/** The split-arm Worth-it/Skip call. Its whole payload is the section. */
export function validateWorthItResponse(
  data: unknown,
  report: ValidationReport,
): Record<string, unknown> {
  const items = isRecord(data) ? validateWorthIt(data.items, report) : null;
  if (!items) throw new ValidationError("empty_worth_it");
  return { items };
}

/** The split-arm where-to-stay call. */
export function validateWhereToStayResponse(
  data: unknown,
  report: ValidationReport,
): Record<string, unknown> {
  const areas = isRecord(data) ? validateWhereToStay(data.areas, report) : null;
  if (!areas) throw new ValidationError("empty_where_to_stay");
  return { areas };
}

/**
 * A deep dive is one category. Same "must have something readable" rule as the
 * suggestions feed, for the same reason.
 */
export function validateDeepDive(
  data: unknown,
  report: ValidationReport,
): Record<string, unknown> {
  if (!isRecord(data) || !nonEmptyString(data.title)) {
    throw new ValidationError("invalid_deep_dive_shape");
  }
  const texts = Array.isArray(data.texts)
    ? data.texts.filter((t) => isRecord(t) && nonEmptyString(t.text))
    : [];
  report.repairs += (Array.isArray(data.texts) ? data.texts.length : 0) - texts.length;
  if (texts.length === 0) throw new ValidationError("empty_deep_dive");
  repairTexts(texts, report);
  return { title: data.title, texts };
}

/**
 * Grounded Near You: every selected ID must belong to the supplied MapKit set.
 * Unknown IDs are a hard component failure, not a repair; silently dropping
 * one would disguise a responsibility-boundary violation as sparse output.
 */
export function validateNearYou(
  data: unknown,
  report: ValidationReport,
  candidates: NearYouCandidate[],
  webSources: OpenAIWebSource[] = [],
): Record<string, unknown> {
  if (!isRecord(data)) throw new ValidationError("invalid_near_you_shape");

  const allowed = new Set(candidates.map((candidate) => candidate.id));
  const used = new Set<string>();
  const rawSections = Array.isArray(data.sections) ? data.sections : [];
  const sections: Record<string, unknown>[] = [];
  let selectedCount = 0;

  for (const rawSection of rawSections) {
    if (!isRecord(rawSection) || !nonEmptyString(rawSection.title)) {
      report.repairs += 1;
      continue;
    }
    if (containsMapFactClaim(rawSection.title)) {
      // Never render model-authored proximity as a grounded fact. Dropping the
      // noncompliant editorial group preserves independently sourced live finds
      // and the deterministic MapKit practical layer from the same response.
      report.repairs += 1;
      continue;
    }
    const rawPicks = Array.isArray(rawSection.picks) ? rawSection.picks : [];
    const picks: Record<string, unknown>[] = [];
    for (const rawPick of rawPicks) {
      if (
        !isRecord(rawPick) ||
        !nonEmptyString(rawPick.candidateID) ||
        !nonEmptyString(rawPick.explanation)
      ) {
        report.repairs += 1;
        continue;
      }
      const candidateID = rawPick.candidateID.trim();
      if (!allowed.has(candidateID)) {
        throw new ValidationError("unknown_near_you_candidate");
      }
      if (containsMapFactClaim(rawPick.explanation)) {
        report.repairs += 1;
        continue;
      }
      if (used.has(candidateID) || selectedCount >= 10) {
        report.repairs += 1;
        continue;
      }
      used.add(candidateID);
      selectedCount += 1;
      picks.push({
        candidateID,
        explanation: rawPick.explanation.trim(),
      });
    }
    if (picks.length > 0) {
      sections.push({ title: rawSection.title.trim(), picks });
    } else if (rawPicks.length > 0) {
      report.repairs += 1;
    }
  }

  let sparseMessage =
    typeof data.sparseMessage === "string" && data.sparseMessage.trim().length > 0
      ? data.sparseMessage.trim()
      : null;
  if (sparseMessage && containsMapFactClaim(sparseMessage)) {
    sparseMessage = null;
    report.repairs += 1;
  }
  const sourcesByURL = new Map(
    webSources
      .map((source) => [canonicalSourceURL(source.url), source] as const)
      .filter(([url]) => url.length > 0),
  );
  const candidateNames = new Set(
    candidates.map((candidate) => candidate.name.trim().toLocaleLowerCase()),
  );
  const seenLiveFinds = new Set<string>();
  const rawLiveFinds = Array.isArray(data.liveFinds) ? data.liveFinds : [];
  const liveFinds: Record<string, unknown>[] = [];
  for (const rawFind of rawLiveFinds) {
    if (liveFinds.length >= 6) {
      report.repairs += 1;
      continue;
    }
    if (
      !isRecord(rawFind) ||
      !nonEmptyString(rawFind.name) ||
      !nonEmptyString(rawFind.category) ||
      !nonEmptyString(rawFind.locationHint) ||
      !nonEmptyString(rawFind.explanation) ||
      !nonEmptyString(rawFind.sourceTitle) ||
      !nonEmptyString(rawFind.sourceURL) ||
      !(rawFind.accessNote === null || typeof rawFind.accessNote === "string")
    ) {
      report.repairs += 1;
      continue;
    }
    const name = rawFind.name.trim().slice(0, 160);
    const normalizedName = name.toLocaleLowerCase();
    const sourceURL = rawFind.sourceURL.trim();
    const consultedSource = sourcesByURL.get(canonicalSourceURL(sourceURL));
    if (
      candidateNames.has(normalizedName) ||
      seenLiveFinds.has(normalizedName) ||
      !consultedSource
    ) {
      report.repairs += 1;
      continue;
    }
    seenLiveFinds.add(normalizedName);
    liveFinds.push({
      name,
      category: rawFind.category.trim().slice(0, 80),
      locationHint: rawFind.locationHint.trim().slice(0, 200),
      explanation: rawFind.explanation.trim().slice(0, 600),
      accessNote:
        typeof rawFind.accessNote === "string" && rawFind.accessNote.trim()
          ? rawFind.accessNote.trim().slice(0, 300)
          : null,
      sourceTitle: (consultedSource.title ?? rawFind.sourceTitle).trim().slice(0, 200),
      sourceURL: consultedSource.url,
    });
  }

  if (candidates.length + liveFinds.length < 4 && sparseMessage === null) {
    sparseMessage =
      "The verified local result is limited here, so the list is intentionally short.";
    report.repairs += 1;
  }

  return { sections, liveFinds, sparseMessage };
}

function canonicalSourceURL(raw: string): string {
  try {
    const url = new URL(raw);
    if (url.protocol !== "https:") return "";
    for (const key of [...url.searchParams.keys()]) {
      if (key.toLowerCase().startsWith("utm_")) url.searchParams.delete(key);
    }
    url.hash = "";
    return url.toString().replace(/\/$/, "");
  } catch {
    return "";
  }
}

function containsMapFactClaim(value: string): boolean {
  return /\b(?:walk|walking|seconds?|minutes?|mins?|hours?|hrs?|feet|foot|yards?|metres?|meters?|kilometres?|kilometers?|km|miles?|distance|nearby|nearest|closest|doorstep|blocks? away)\b|around the corner/i.test(
    value,
  );
}

/**
 * The itinerary is the required component, so it gets the strictest check: a
 * trip with no segments is not a degraded itinerary, it is no itinerary, and
 * committing it would make the whole trip look ready when it is not.
 */
export function validateItinerary(
  data: unknown,
  report: ValidationReport,
  expectedDurationDays?: number,
): Record<string, unknown> {
  if (!isRecord(data)) throw new ValidationError("invalid_itinerary_shape");
  const segments = Array.isArray(data.segments)
    ? data.segments.filter((s) => isRecord(s) && nonEmptyString(s.title))
    : [];
  report.repairs += (Array.isArray(data.segments) ? data.segments.length : 0) - segments.length;
  if (segments.length === 0) throw new ValidationError("empty_itinerary");

  if (expectedDurationDays != null && Number.isFinite(expectedDurationDays)) {
    const days = Math.max(1, Math.round(expectedDurationDays));
    const hasCompleteCoverage =
      days <= 5
        ? segments.length === days
        : segments.length >= 2 && segments.length <= 5;
    if (!hasCompleteCoverage) {
      throw new ValidationError("incomplete_itinerary");
    }
  }

  for (const segment of segments) {
    const description = isRecord((segment as Record<string, unknown>).description)
      ? ((segment as Record<string, unknown>).description as Record<string, unknown>)
      : {};
    for (const slot of ["morning", "afternoon", "evening"]) {
      repairTexts(description[slot], report);
    }
    const tip = (segment as Record<string, unknown>).secret_tip;
    if (isRecord(tip)) repairLocations(tip, ["text"], report);
  }
  return { ...data, segments };
}
