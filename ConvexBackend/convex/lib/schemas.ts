/**
 * The ONE definition of every structured-output schema. Previously these were
 * hand-copied between `TripPlanningService.swift` and `generate.ts`, and the two
 * copies had already drifted: Swift declared `latitude`/`longitude` as
 * `["string","null"]` while the backend declared them as plain `string` and
 * still listed them in `required` under `strict: true` — so the group prompt
 * told the model to emit `null` for unknown coordinates while the schema made
 * that impossible. The model resolves that contradiction by inventing
 * coordinates. That is fixed here, once, for both platforms.
 *
 * Strict Structured Outputs rules that shape everything below:
 *   - every object needs `additionalProperties: false`
 *   - every declared property must appear in `required` — there is no `?`
 *   - "may be absent" is expressed as a nullable union, `{"type":["string","null"]}`
 *   - "may be empty" is a required array that arrives as `[]`, never absent
 */

function obj(properties: Record<string, unknown>, required: string[]): unknown {
  return { type: "object", additionalProperties: false, properties, required };
}

function arr(
  items: unknown,
  bounds?: { minItems?: number; maxItems?: number },
): unknown {
  return { type: "array", items, ...bounds };
}

const str = { type: "string" };
const nullableStr = { type: ["string", "null"] };

function strEnum(values: string[]): unknown {
  return { type: "string", enum: values };
}

/**
 * Canonical location. Must stay byte-for-byte equivalent to
 * `Trip.Itinerary.Location` in CoreModels — all three of `latitude`,
 * `longitude` and `placeID` are genuinely optional facts, so all three are
 * nullable unions rather than required strings.
 */
export const LOCATION = obj(
  {
    linkSubstring: str,
    placeName: str,
    latitude: nullableStr,
    longitude: nullableStr,
    placeID: nullableStr,
  },
  ["linkSubstring", "placeName", "latitude", "longitude", "placeID"],
);

/** A single piece of model prose plus the places named inside it. */
export const LINKABLE_TEXT = obj({ text: str, locations: arr(LOCATION) }, [
  "text",
  "locations",
]);

/**
 * The itinerary is the one component whose array count is a hard product
 * requirement. Base Structured Outputs models support `minItems`/`maxItems`,
 * so bind the schema to this trip's requested duration instead of relying on
 * prompt wording alone. Post-decode validation remains as a defensive check.
 */
export function itinerarySchema(expectedDurationDays?: number): unknown {
  const activity = LINKABLE_TEXT;
  const twoActivities = arr(activity);
  const description = obj(
    { morning: twoActivities, afternoon: twoActivities, evening: twoActivities },
    ["morning", "afternoon", "evening"],
  );
  const segment = obj({ title: str, description, secret_tip: activity }, [
    "title",
    "description",
    "secret_tip",
  ]);
  const segmentBounds = itinerarySegmentBounds(expectedDurationDays);
  return obj(
    {
      name: strEnum(["travel_itinerary_schema"]),
      destination: str,
      title: str,
      segments: arr(segment, segmentBounds),
    },
    ["name", "destination", "title", "segments"],
  );
}

/**
 * Up to five days means one segment per day. Longer trips are deliberately
 * grouped into two to five ranged segments so the response stays readable.
 */
export function itinerarySegmentBounds(
  expectedDurationDays?: number,
): { minItems?: number; maxItems?: number } {
  if (expectedDurationDays == null || !Number.isFinite(expectedDurationDays)) {
    return {};
  }
  const days = Math.max(1, Math.round(expectedDurationDays));
  return days <= 5
    ? { minItems: days, maxItems: days }
    : { minItems: 2, maxItems: 5 };
}

/** Unbounded fallback for tooling that does not yet have trip input in hand. */
export const ITINERARY_SCHEMA = itinerarySchema();

/** Category IDs the app knows how to render (icon + section identity). */
const DYNAMIC_CATEGORY_IDS = ["cafes", "vibe", "new", "rainy", "random"];
const STATIC_CATEGORY_IDS = ["month", "couples", "group", "solo", "family", "avoid"];

function category(
  ids: string[],
  textBounds?: { minItems?: number; maxItems?: number },
): unknown {
  return obj({ ID: strEnum(ids), title: str, texts: arr(LINKABLE_TEXT, textBounds) }, [
    "ID",
    "title",
    "texts",
  ]);
}

/**
 * A focused second pass for a suggestions response that was usable but thin.
 *
 * Every field is required because strict Structured Outputs requires it. A
 * target the first response already satisfied is represented by JSON null;
 * every missing target is a category whose `texts` count is bound to precisely
 * the number of new cards needed to reach the four-card product minimum. This
 * keeps the repair call small without throwing away the useful first response.
 */
export function suggestionsTopUpSchema(plan: {
  dynamic: { ids: string[]; count: number } | null;
  month: { ids: string[]; count: number } | null;
  party: { ids: string[]; count: number } | null;
  avoid: { ids: string[]; count: number } | null;
}): unknown {
  const target = (value: { ids: string[]; count: number } | null) => {
    if (!value) return { type: "null" };
    const count = Math.max(1, Math.min(4, Math.round(value.count)));
    return category(value.ids, { minItems: count, maxItems: count });
  };
  return obj(
    {
      dynamic: target(plan.dynamic),
      month: target(plan.month),
      party: target(plan.party),
      avoid: target(plan.avoid),
    },
    ["dynamic", "month", "party", "avoid"],
  );
}

/**
 * One Worth-it/Skip card (D7). Mirrors `Trip.WorthItItem` in CoreModels.
 *
 * One `locations` array per card rather than one per prose field: the link
 * substrings are matched against all three fields on the device, so a per-field
 * array would store the same places three times.
 *
 * This optional, best-effort section intentionally stays permissive at the
 * schema boundary. Its count is repaired after decode in `validation.ts`, so a
 * slightly short response can be dropped without failing the required
 * itinerary alongside it.
 */
export const WORTH_IT_ITEM = obj(
  {
    place: str,
    theCase: str,
    theCatch: str,
    verdict: str,
    locations: arr(LOCATION),
  },
  ["place", "theCase", "theCatch", "verdict", "locations"],
);

/** One neighbourhood in the where-to-stay guide (D10). */
export const STAY_AREA = obj(
  {
    area: str,
    theCase: str,
    bestFor: str,
    watchOut: str,
    locations: arr(LOCATION),
  },
  ["area", "theCase", "bestFor", "watchOut", "locations"],
);

/** Three model-picked interest labels; the app adds three fixed ones (D8). */
const INTEREST_PROMPTS = arr(str);

export const WORTH_IT_SCHEMA = obj({ items: arr(WORTH_IT_ITEM) }, ["items"]);

export const WHERE_TO_STAY_SCHEMA = obj({ areas: arr(STAY_AREA) }, ["areas"]);

/**
 * The suggestions schema, which is the subject of the D15 experiment.
 *
 * `extras: false` is the pre-S5 shape — four themed categories and nothing
 * else. `extras: true` is the enlarged combined call that also carries the
 * Worth-it/Skip cards and the where-to-stay guide. Which one runs is a
 * measured decision, not an argued one (see `SUGGESTIONS_VARIANT`).
 *
 * `interestPrompts` rides along in BOTH shapes on purpose: three short labels
 * are not worth a call of their own under any variant, so splitting them was
 * never one of the options being weighed.
 */
export function suggestionsSchema(opts: {
  extras: boolean;
  interestPrompts: boolean;
}): unknown {
  const properties: Record<string, unknown> = {
    dynamicSuggestions: arr(category(DYNAMIC_CATEGORY_IDS)),
    staticSuggestions: arr(category(STATIC_CATEGORY_IDS)),
  };
  if (opts.interestPrompts) properties.interestPrompts = INTEREST_PROMPTS;
  if (opts.extras) {
    properties.worthIt = arr(WORTH_IT_ITEM);
    properties.whereToStay = arr(STAY_AREA);
  }
  return obj(properties, Object.keys(properties));
}

/**
 * Know Before You Go.
 *
 * Eight buckets, with stable topic IDs for the fixed subcategories and a
 * generated title only for the destination-essential bucket. `topic` is what
 * lets validation distinguish "three transport modes" from three arbitrary
 * rows without dictating how the model lays out each row's prose and bullets.
 * The flat array is deliberate: old saved/shared KBYG payloads still decode,
 * while the client can group both generations through the same path.
 *
 * `volatility` is the whole confidence mechanism. There is no global
 * disclaimer and no per-section badge: a `stable` section reads with full
 * confidence, and a `verify` section carries one line naming the authority to
 * check. The conditional rule that follows from that — a `verify` section MUST
 * name a source — cannot be expressed in strict JSON Schema (§3), so it is
 * validated after decode in `Trip.KnowBeforeYouGo.Section`, which downgrades an
 * unsourced `verify` to `stable` rather than rendering "check with (nobody)".
 *
 * `sourceURL` is nullable and the prompt says never to guess one: a fabricated
 * official URL is worse than a named authority with no link, because the link
 * is the part a traveller would trust.
 */
const KBYG_BUCKETS = [
  "beforeYouLeave",
  "onTheGround",
  "money",
  "gettingAround",
  "culture",
  "destinationEssential",
  "healthAndSafety",
  "otherTips",
];

const KBYG_TOPICS = [
  "entryRequirements",
  "arrivalTransport",
  "monthPacking",
  "simInternet",
  "apps",
  "electricity",
  "onGroundWildcard",
  "currencyExchange",
  "costSnapshot",
  "tipping",
  "paymentMethods",
  "localTransport",
  "culture",
  "language",
  "destinationEssential",
  "healthSafety",
  "otherTips",
];

export const KNOW_BEFORE_YOU_GO_SCHEMA = obj(
  {
    sections: arr(
      obj(
        {
          bucket: strEnum(KBYG_BUCKETS),
          topic: strEnum(KBYG_TOPICS),
          bucketTitle: nullableStr,
          title: str,
          body: str,
          bullets: arr(str),
          volatility: strEnum(["stable", "verify"]),
          sourceLead: nullableStr,
          source: nullableStr,
          sourceURL: nullableStr,
          locations: arr(LOCATION),
        },
        [
          "bucket",
          "topic",
          "bucketTitle",
          "title",
          "body",
          "bullets",
          "volatility",
          "sourceLead",
          "source",
          "sourceURL",
          "locations",
        ],
      ),
    ),
  },
  ["sections"],
);

/**
 * An interest deep dive is one extra category appended to the feed. It carries
 * no `ID`: its provenance is "the traveller asked for this", not one of the
 * fixed sections, and the app renders it with its own icon. `Trip.Suggestions.
 * Category` decodes a missing `ID` as `nil`, so this drops straight in.
 */
export const DEEP_DIVE_SCHEMA = obj({ title: str, texts: arr(LINKABLE_TEXT) }, [
  "title",
  "texts",
]);

/**
 * One place the model believes is near the traveller's address.
 *
 * It is a *proposal*, not a fact. Every entry is resolved against MapKit and
 * given a real walking route on the client before the traveller sees it;
 * anything that fails to resolve or falls outside the radius is discarded.
 * That gate is also what filters invented venues, so the model is asked for
 * precision in `name`/`locationHint` rather than for restraint.
 *
 * There is deliberately still no distance, walking-time, coordinate or
 * map-link field: those remain MapKit's to author. `accessNote` may carry a
 * recurring rhythm or an access caveat, never a computed journey time.
 */
const NEAR_YOU_PROPOSAL = obj(
  {
    name: str,
    category: str,
    locationHint: str,
    explanation: str,
    accessNote: nullableStr,
  },
  ["name", "category", "locationHint", "explanation", "accessNote"],
);

export const NEAR_YOU_SCHEMA = obj(
  {
    places: arr(NEAR_YOU_PROPOSAL),
    sparseMessage: nullableStr,
  },
  ["places", "sparseMessage"],
);
