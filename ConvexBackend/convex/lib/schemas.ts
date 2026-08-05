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

function arr(items: unknown): unknown {
  return { type: "array", items };
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

export const ITINERARY_SCHEMA = (() => {
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
  return obj(
    {
      name: strEnum(["travel_itinerary_schema"]),
      destination: str,
      title: str,
      segments: arr(segment),
    },
    ["name", "destination", "title", "segments"],
  );
})();

/** Category IDs the app knows how to render (icon + section identity). */
const DYNAMIC_CATEGORY_IDS = ["cafes", "vibe", "new", "rainy", "random"];
const STATIC_CATEGORY_IDS = ["month", "couples", "group", "solo", "family", "avoid"];

function category(ids: string[]): unknown {
  return obj({ ID: strEnum(ids), title: str, texts: arr(LINKABLE_TEXT) }, [
    "ID",
    "title",
    "texts",
  ]);
}

export const SUGGESTIONS_SCHEMA = obj(
  {
    dynamicSuggestions: arr(category(DYNAMIC_CATEGORY_IDS)),
    staticSuggestions: arr(category(STATIC_CATEGORY_IDS)),
  },
  ["dynamicSuggestions", "staticSuggestions"],
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
