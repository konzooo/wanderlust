/**
 * Scoring for the §13 matrix.
 *
 * Everything here is mechanical. Factuality is not — no offline check knows
 * whether a restaurant exists — so the runner keeps every raw response in
 * `results/` for reading, and this file scores only what can be scored the same
 * way twice.
 *
 * The two most useful numbers are the least obvious ones:
 *
 * - **Link resolution.** The app makes a place name tappable by finding
 *   `linkSubstring` inside the text it belongs to. A location entry whose
 *   substring is not actually in the text is a link that silently does not
 *   render — invisible in the JSON, visible to every traveller. This applies
 *   the app's own matching rule.
 * - **Cross-component repetition.** Places recurring across components is fine
 *   and expected (§12). Repeated *sentences* are the bug, so that is what is
 *   counted.
 */

/**
 * One heartable/renderable thing: every string the app draws for it, and the
 * single `locations` array they share.
 *
 * Grouped rather than one-unit-per-string because that is how the app works. A
 * Worth-it card draws four strings — its title and three prose fields — against
 * one locations array, and the link renders if the substring is found in ANY of
 * them. Scoring each string separately makes good prose look like a defect: a
 * card whose body says "this masterpiece" instead of repeating "Sagrada
 * Família" four times would score three misses for writing well.
 */
export type Unit = {
  component: string;
  texts: string[];
  locations: RawLocation[];
};

type RawLocation = {
  linkSubstring?: unknown;
  placeName?: unknown;
  latitude?: unknown;
  longitude?: unknown;
};

function isRecord(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null && !Array.isArray(v);
}

function asArray(v: unknown): unknown[] {
  return Array.isArray(v) ? v : [];
}

function locationsOf(v: unknown): RawLocation[] {
  return asArray(v).filter(isRecord) as RawLocation[];
}

/** Flattens one component's payload into prose-plus-places units. */
export function unitsOf(component: string, data: unknown): Unit[] {
  if (!isRecord(data)) return [];
  const units: Unit[] = [];
  /** One item: every string the app renders for it, sharing one locations array. */
  const push = (texts: unknown[], locations: unknown) => {
    const strings = texts.filter(
      (t): t is string => typeof t === "string" && t.trim().length > 0,
    );
    if (strings.length > 0) {
      units.push({ component, texts: strings, locations: locationsOf(locations) });
    }
  };

  switch (component) {
    case "itinerary":
      for (const segment of asArray(data.segments)) {
        if (!isRecord(segment)) continue;
        const description = isRecord(segment.description) ? segment.description : {};
        for (const slot of ["morning", "afternoon", "evening"]) {
          for (const activity of asArray(description[slot])) {
            if (isRecord(activity)) push([activity.text], activity.locations);
          }
        }
        const tip = segment.secret_tip;
        if (isRecord(tip)) push([tip.text], tip.locations);
      }
      break;

    case "suggestions":
      for (const key of ["dynamicSuggestions", "staticSuggestions"]) {
        for (const category of asArray(data[key])) {
          if (!isRecord(category)) continue;
          for (const text of asArray(category.texts)) {
            if (isRecord(text)) push([text.text], text.locations);
          }
        }
      }
      // The combined variant carries the other two sections here.
      units.push(...unitsOf("worthIt", { items: data.worthIt ?? [] }));
      units.push(...unitsOf("whereToStay", { areas: data.whereToStay ?? [] }));
      break;

    // `place` and `area` are included because the app renders both as linkable
    // text: the card's headline is usually the only place its subject is named
    // at all, so scoring the prose alone would measure a surface the traveller
    // does not see.
    case "worthIt":
      for (const item of asArray(data.items)) {
        if (!isRecord(item)) continue;
        push(
          ["place", "theCase", "theCatch", "verdict"].map((f) => item[f]),
          item.locations,
        );
      }
      break;

    case "whereToStay":
      for (const area of asArray(data.areas)) {
        if (!isRecord(area)) continue;
        push(
          ["area", "theCase", "bestFor", "watchOut"].map((f) => area[f]),
          area.locations,
        );
      }
      break;

    case "deepDive":
      for (const text of asArray(data.texts)) {
        if (isRecord(text)) push([text.text], text.locations);
      }
      break;
  }
  return units;
}

/** Every distinct place a set of units names, normalised for comparison. */
export function placeNames(units: Unit[]): Set<string> {
  const names = new Set<string>();
  for (const unit of units) {
    for (const location of unit.locations) {
      if (typeof location.placeName === "string" && location.placeName.trim()) {
        names.add(normalise(location.placeName));
      }
    }
  }
  return names;
}

export type LinkScore = {
  locations: number;
  /** `linkSubstring` actually occurs in the text it was attached to. */
  resolvable: number;
  /** Both coordinates present. Missing is normal and expected, not a fault. */
  withCoordinates: number;
};

/**
 * Applies the app's own substring rule. A location that fails this is a place
 * name that will render as plain text with no tap target, which is the single
 * most common way generated output silently loses a feature.
 */
export function linkScore(units: Unit[]): LinkScore {
  let locations = 0;
  let resolvable = 0;
  let withCoordinates = 0;
  for (const unit of units) {
    // Every string the app draws for this item. The link renders if the
    // substring is in any one of them, so that is what is checked.
    const haystack = unit.texts.join("   ").toLowerCase();
    for (const location of unit.locations) {
      locations += 1;
      const needle =
        typeof location.linkSubstring === "string"
          ? location.linkSubstring.toLowerCase().trim()
          : "";
      if (needle && haystack.includes(needle)) resolvable += 1;
      if (
        typeof location.latitude === "string" &&
        typeof location.longitude === "string"
      ) {
        withCoordinates += 1;
      }
    }
  }
  return { locations, resolvable, withCoordinates };
}

/**
 * Sentences repeated across two different components.
 *
 * Deliberately not "places repeated" — the plan is explicit that a place
 * appearing in both the itinerary and the suggestions feed is expected and
 * fine. A whole sentence appearing twice is the model padding one component
 * with another's work.
 */
export function repeatedSentences(units: Unit[]): string[] {
  const byS = new Map<string, Set<string>>();
  for (const unit of units) {
    for (const sentence of unit.texts.flatMap(sentences)) {
      if (sentence.length < 40) continue; // too short to be a meaningful repeat
      const set = byS.get(sentence) ?? new Set<string>();
      set.add(unit.component);
      byS.set(sentence, set);
    }
  }
  return [...byS.entries()]
    .filter(([, components]) => components.size > 1)
    .map(([sentence]) => sentence);
}

function sentences(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+/)
    .map(normalise)
    .filter((s) => s.length > 0);
}

function normalise(value: string): string {
  return value.toLowerCase().replace(/\s+/g, " ").trim();
}

/** How much two travellers' output overlaps. 0 = nothing shared, 1 = identical. */
export function jaccard(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 && b.size === 0) return 0;
  let shared = 0;
  for (const value of a) if (b.has(value)) shared += 1;
  return shared / (a.size + b.size - shared);
}

export type Completeness = {
  categories: number;
  suggestionTexts: number;
  worthItItems: number;
  stayAreas: number;
  interestPrompts: number;
  /** Suggestions that name no findable place at all. The prompt asks for most. */
  unfindableTexts: number;
};

/** Did the model return the shape the product asked for, section by section? */
export function completeness(data: unknown): Completeness {
  const empty: Completeness = {
    categories: 0,
    suggestionTexts: 0,
    worthItItems: 0,
    stayAreas: 0,
    interestPrompts: 0,
    unfindableTexts: 0,
  };
  if (!isRecord(data)) return empty;

  const categories = [
    ...asArray(data.dynamicSuggestions),
    ...asArray(data.staticSuggestions),
  ].filter(isRecord);

  let suggestionTexts = 0;
  let unfindableTexts = 0;
  for (const category of categories) {
    for (const text of asArray(category.texts)) {
      if (!isRecord(text)) continue;
      suggestionTexts += 1;
      if (locationsOf(text.locations).length === 0) unfindableTexts += 1;
    }
  }

  return {
    categories: categories.length,
    suggestionTexts,
    worthItItems: asArray(data.worthIt ?? data.items).length,
    stayAreas: asArray(data.whereToStay ?? data.areas).length,
    interestPrompts: asArray(data.interestPrompts).length,
    unfindableTexts,
  };
}

/**
 * Whether the itinerary obeyed its own segmentation rule.
 *
 * The prompt is explicit: one segment per day for trips of five days or fewer,
 * and no more than five segments for longer ones. This check was missing from
 * the first two matrix runs, and its absence hid a live defect — short trips
 * came back as a **single** segment ("3 days" rendered as one card), and some
 * long trips came back with one segment per day instead of grouped.
 *
 * It is separated from `laneViolations` because it needs the trip's length,
 * which is a property of the request rather than of the response.
 */
export function itineraryShapeViolations(
  data: unknown,
  durationDays: number,
): string[] {
  if (!isRecord(data)) return ["itinerary is not an object"];
  const segments = asArray(data.segments).length;

  if (durationDays <= 5) {
    return segments === durationDays
      ? []
      : [`${durationDays}-day trip returned ${segments} segments, expected one per day`];
  }
  if (segments < 2 || segments > 5) {
    return [`${durationDays}-day trip returned ${segments} segments, expected 2-5`];
  }
  return [];
}

/**
 * Lane checks the prompts can actually be held to.
 *
 * Each of these is a rule stated in a prompt, so a violation is the model
 * ignoring an instruction rather than a matter of taste — which is exactly the
 * kind of drift a matrix is supposed to catch before it ships.
 */
export function laneViolations(component: string, data: unknown): string[] {
  const violations: string[] = [];
  if (!isRecord(data)) return violations;

  const areas = asArray(data.whereToStay ?? (component === "whereToStay" ? data.areas : []));
  for (const area of areas) {
    if (!isRecord(area)) continue;
    const prose = ["theCase", "bestFor", "watchOut"]
      .map((f) => (typeof area[f] === "string" ? (area[f] as string) : ""))
      .join(" ");
    // "Areas only. Do not name hotels and do not quote prices."
    if (/\b(hotel|hostel|airbnb|b&b|guesthouse)\b/i.test(prose)) {
      violations.push(`whereToStay names lodging: ${String(area.area)}`);
    }
    if (/[€$£]\s?\d|\b\d+\s?(euros?|dollars?|pounds?)\b/i.test(prose)) {
      violations.push(`whereToStay quotes a price: ${String(area.area)}`);
    }
  }

  const items = asArray(data.worthIt ?? (component === "worthIt" ? data.items : []));
  for (const item of items) {
    if (!isRecord(item)) continue;
    const verdict = typeof item.verdict === "string" ? item.verdict : "";
    // "A verdict that decides nothing is not a verdict."
    if (!/\b(worth it|skip|half worth|do it|don't bother|go|worth the)\b/i.test(verdict)) {
      violations.push(`worthIt verdict decides nothing: ${String(item.place)}`);
    }
  }

  for (const prompt of asArray(data.interestPrompts)) {
    if (typeof prompt !== "string") continue;
    if (prompt.trim().endsWith("?")) {
      violations.push(`interest prompt is a question: ${prompt}`);
    }
  }

  return violations;
}

/**
 * gpt-4o-mini list pricing, USD per million tokens, as of the run recorded in
 * `results/`. Kept here rather than inlined so a re-run under different pricing
 * is a one-line change and the old numbers stay interpretable.
 */
export const PRICING = {
  inputPerMillion: 0.15,
  cachedInputPerMillion: 0.075,
  outputPerMillion: 0.6,
};

export function costUSD(usage: {
  inputTokens: number;
  cachedInputTokens: number;
  outputTokens: number;
}): number {
  const uncachedInput = Math.max(0, usage.inputTokens - usage.cachedInputTokens);
  return (
    (uncachedInput * PRICING.inputPerMillion +
      usage.cachedInputTokens * PRICING.cachedInputPerMillion +
      usage.outputTokens * PRICING.outputPerMillion) /
    1_000_000
  );
}
