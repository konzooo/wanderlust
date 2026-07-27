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
