import { v } from "convex/values";

/**
 * The three possible swipe outcomes, mirroring the questionnaire card engine
 * and the Swift `PreferenceChoice`. Raw values are the wire format shared with
 * the app, so they must stay lowercase and stable.
 */
export const preferenceChoice = v.union(
  v.literal("left"),
  v.literal("right"),
  v.literal("both"),
);

/** A single answered question. */
export const preferenceAnswer = v.object({
  questionID: v.string(),
  choice: preferenceChoice,
});

export const travellerDNADimension = v.union(
  v.literal("advice_detail"),
  v.literal("physical_energy"),
  v.literal("experience_breadth"),
  v.literal("day_rhythm"),
  v.literal("structure"),
);

export const profileScaleAnswer = v.object({
  dimension: travellerDNADimension,
  value: v.number(),
});

/** Privacy-minimized snapshot; local profile IDs and display names are omitted. */
export const travellerProfileSnapshot = v.object({
  questionnaireVersion: v.number(),
  scaleAnswers: v.array(profileScaleAnswer),
  usuallySkip: v.array(v.string()),
  mustHaves: v.array(v.string()),
  additionalNotes: v.optional(v.string()),
});

/**
 * A member's structured questionnaire answers. Mirrors the Swift
 * `MemberPreferences`. Stored on the `members` table only once a member
 * completes swiping.
 */
export const memberPreferences = v.object({
  questionnaireVersion: v.number(),
  answers: v.array(preferenceAnswer),
  profile: v.optional(travellerProfileSnapshot),
});

/**
 * A solo traveller's structured trip inputs — the exact contract the app sends
 * to `trips:generateComponent`. The app no longer formats a prose trip summary:
 * the backend owns prompt assembly end to end (see lib/prompts.ts), so what
 * crosses the wire is data, not a partially-written prompt.
 *
 * The nullable unions are not decoration. The Swift `ConvexEncodable`
 * dictionary sends an absent `Optional` as JSON `null` rather than omitting the
 * key, so a plain `v.optional(v.string())` would hard-fail for any traveller
 * who left the age or notes field empty.
 */
export const soloTripInput = v.object({
  destination: v.string(),
  /** `Trip.Details.GroupType` rawValue. */
  groupType: v.string(),
  durationDays: v.number(),
  /** `Month` rawValue — MIXED CASE ("June", "january"). */
  startMonth: v.string(),
  avgAge: v.optional(v.union(v.number(), v.null())),
  gender: v.optional(v.union(v.string(), v.null())),
  customizations: v.optional(v.union(v.string(), v.null())),
  answers: v.array(preferenceAnswer),
  profile: v.optional(v.union(travellerProfileSnapshot, v.null())),
});

/** Input size ceilings. Free text reaches a paid model, so it is bounded here. */
export const MAX_DESTINATION_INPUT_LENGTH = 160;
export const MAX_CUSTOMIZATIONS_LENGTH = 2_000;
export const MAX_INTEREST_LENGTH = 80;
export const MAX_ALREADY_RECOMMENDED_ITEMS = 200;

export const TRAVELLER_DNA_VERSIONS: Record<number, readonly string[]> = {
  1: [
    "advice_detail",
    "physical_energy",
    "experience_breadth",
    "day_rhythm",
    "structure",
  ],
};

/** Group lifecycle. `collecting` is the only state that accepts joins/submits. */
export const groupStatus = v.union(
  v.literal("collecting"),
  v.literal("generating"),
  v.literal("ready"),
  v.literal("error"),
);

/** Per-slot status. `skipped` = pending when the admin generated without them. */
export const memberStatus = v.union(
  v.literal("pending"),
  v.literal("completed"),
  v.literal("skipped"),
);

export const memberRole = v.union(v.literal("admin"), v.literal("member"));

/**
 * The exact question IDs expected for each questionnaire revision. The backend
 * requires an exact match on `submitPreferences` so a member who swiped on a
 * stale or unknown questionnaire is never silently counted as complete.
 *
 * Keep this in sync with the app's questionnaire definition
 * (`TripOrganizer.defaultQuestionaire`).
 */
export const QUESTIONNAIRE_VERSIONS: Record<number, readonly string[]> = {
  1: ["1", "2", "3", "4", "5", "6", "7"],
};

/** Minimum members before a group can auto-generate (prevents a 1-person trip). */
export const MIN_MEMBERS_TO_GENERATE = 2;

/**
 * The state of one generated component, stored per component on a group.
 *
 * A bare optional payload could only say "there is nothing here", which the
 * client cannot act on: never generated, currently generating and failed all
 * looked identical, so there was nothing to retry and nothing honest to show.
 * Mirrors `ComponentState` in CoreModels, plus a `generating` case the device
 * doesn't need (it tracks its own in-flight work, the group's is server-side).
 */
export const componentState = v.union(
  v.object({ state: v.literal("absent") }),
  v.object({ state: v.literal("generating") }),
  v.object({ state: v.literal("failed"), code: v.string() }),
  v.object({ state: v.literal("ready") }),
);

/**
 * Per-component state for a group's generated output. The payloads themselves
 * stay in `groups.itinerary` / `groups.suggestions`; this records what actually
 * happened to each. Absent entirely on groups generated before it existed —
 * `deriveComponentStates` reconstructs those from the payloads.
 */
export const groupComponentStates = v.object({
  itinerary: componentState,
  suggestions: componentState,
});
