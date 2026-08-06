/**
 * The §13 evaluation matrix, as data.
 *
 * "One Barcelona generation proves nothing." These fixtures are checked into
 * the repo so runs stay comparable over time: change a prompt, re-run, and the
 * numbers are against the same travellers rather than against whatever came to
 * mind that afternoon.
 *
 * The destination axis covers each archetype the plan names, because they break
 * different things — an island has no metro to recommend, a rural valley has
 * four restaurants total, and a small Nordic city makes half the "what to
 * avoid" advice about pickpockets read as nonsense.
 */

import type { SoloTripInput } from "../convex/lib/prompts";

/** Which §13 destination archetype a fixture is standing in for. */
export type Archetype =
  | "large-european-city"
  | "small-nordic-city"
  | "island"
  | "multi-island-country"
  | "rural-mountain"
  | "high-transport-friction"
  | "natural-hazards";

export type Fixture = {
  id: string;
  archetype: Archetype;
  /** What this row is here to catch. Read alongside the scores. */
  watchFor: string;
  input: SoloTripInput;
  /**
   * Another fixture this one should differ from. Same destination, different
   * traveller: if the two get materially the same places back, the output is
   * not personalised and the whole preference apparatus is decoration.
   */
  contrastWith?: string;
};

type Choice = "left" | "right" | "both";

/**
 * Seven answers in question order. Written positionally because that is how the
 * questionnaire reads, and a fixture file full of `{questionID: "4"}` objects is
 * unreadable at the size this file wants to grow to.
 *
 * 1 city/landscape · 2 unwind/adventure · 3 favourites/off-path ·
 * 4 street food/fine dining · 5 ruins/modern · 6 nightlife/quiet · 7 budget/spend
 */
function answers(...choices: Choice[]) {
  return choices.map((choice, index) => ({
    questionID: String(index + 1),
    choice,
  }));
}

export const FIXTURES: Fixture[] = [
  {
    id: "barcelona-couple-weekend",
    archetype: "large-european-city",
    watchFor:
      "The baseline. Everything works here, so anything that fails on this row is broken outright rather than merely untested.",
    contrastWith: "barcelona-family-summer",
    input: {
      destination: "Barcelona, Spain",
      groupType: "couple",
      durationDays: 3,
      startMonth: "may",
      avgAge: 31,
      gender: "mixed",
      customizations: "We would rather eat well than see everything.",
      answers: answers("left", "left", "both", "left", "both", "right", "both"),
      profile: null,
    },
  },
  {
    id: "barcelona-family-summer",
    archetype: "large-european-city",
    watchFor:
      "Same city, opposite traveller. The personalisation score is the overlap between this row's places and the couple's — high overlap means the preferences are not reaching the output.",
    contrastWith: "barcelona-couple-weekend",
    input: {
      destination: "Barcelona, Spain",
      groupType: "family",
      durationDays: 7,
      startMonth: "august",
      avgAge: 38,
      gender: "mixed",
      customizations: "Two kids, 6 and 9. Early nights, and the heat is a real problem for us.",
      answers: answers("right", "left", "left", "left", "left", "right", "left"),
      profile: {
        questionnaireVersion: 1,
        scaleAnswers: [
          { dimension: "advice_detail", value: 4 },
          { dimension: "physical_energy", value: 2 },
          { dimension: "experience_breadth", value: 2 },
          { dimension: "day_rhythm", value: 1 },
          { dimension: "structure", value: 5 },
        ],
        usuallySkip: ["queueing for anything", "late dinners"],
        mustHaves: ["somewhere the kids can run", "a swim most days"],
      },
    },
  },
  {
    id: "bergen-solo-winter",
    archetype: "small-nordic-city",
    watchFor:
      "A city where scams and pickpockets are not a topic. If 'What to Avoid' still warns about them, the category is running on a template rather than on the destination.",
    input: {
      destination: "Bergen, Norway",
      groupType: "solo",
      durationDays: 4,
      startMonth: "february",
      avgAge: 29,
      gender: "female",
      customizations: "Travelling alone and happy to be out after dark if it's sensible.",
      answers: answers("right", "left", "right", "left", "right", "right", "left"),
      profile: null,
    },
  },
  {
    id: "naxos-couple-shoulder",
    archetype: "island",
    watchFor:
      "A small island in the shoulder season: half of what a guide would list is closed, and there is no rainy-day museum backup. Padding shows up here first.",
    input: {
      destination: "Naxos, Greece",
      groupType: "couple",
      durationDays: 5,
      startMonth: "october",
      avgAge: 44,
      gender: "mixed",
      customizations: null,
      answers: answers("right", "left", "right", "left", "both", "right", "both"),
      profile: null,
    },
  },
  {
    id: "cape-verde-group-multiisland",
    archetype: "multi-island-country",
    watchFor:
      "Getting between islands is the trip. An itinerary that hops islands as if they were neighbourhoods is a factual failure, not a taste failure.",
    input: {
      destination: "Cape Verde",
      groupType: "group",
      durationDays: 12,
      startMonth: "january",
      avgAge: 27,
      gender: "mixed",
      customizations: "Six of us, up for moving around but nobody wants to spend the trip in transit.",
      answers: answers("right", "right", "right", "left", "right", "left", "left"),
      profile: null,
    },
  },
  {
    id: "dolomites-solo-autumn",
    archetype: "rural-mountain",
    watchFor:
      "Sparse candidates and real distances. Where-to-stay has to name valleys and villages rather than city districts, and 'nearest' means a drive.",
    input: {
      destination: "Val Gardena, Dolomites, Italy",
      groupType: "solo",
      durationDays: 6,
      startMonth: "september",
      avgAge: 35,
      gender: "male",
      customizations: "Walking every day. No car, so anything I can reach by bus matters.",
      answers: answers("right", "right", "right", "left", "left", "right", "both"),
      profile: {
        questionnaireVersion: 1,
        scaleAnswers: [
          { dimension: "advice_detail", value: 5 },
          { dimension: "physical_energy", value: 5 },
          { dimension: "experience_breadth", value: 2 },
          { dimension: "day_rhythm", value: 1 },
          { dimension: "structure", value: 2 },
        ],
        usuallySkip: ["cable cars when the walk is possible"],
        mustHaves: ["a long walk most days", "somewhere to eat late after one"],
      },
    },
  },
  {
    id: "sri-lanka-couple-friction",
    archetype: "high-transport-friction",
    watchFor:
      "Where the model most wants to invent a bus that runs. Distances that read as trivial and are half a day are the failure to watch for.",
    input: {
      destination: "Sri Lanka",
      groupType: "couple",
      durationDays: 14,
      startMonth: "march",
      avgAge: 33,
      gender: "mixed",
      customizations: "Trains where possible. We do not want to be in a car for six hours.",
      answers: answers("both", "both", "right", "left", "left", "right", "left"),
      profile: null,
    },
  },
  {
    id: "reykjavik-solo-hazards",
    archetype: "natural-hazards",
    watchFor:
      "Real hazards — weather closures, roads, water. The lane test is whether the safety content stays practical instead of turning into a second suggestions feed.",
    input: {
      destination: "Reykjavík and South Iceland",
      groupType: "solo",
      durationDays: 8,
      startMonth: "november",
      avgAge: 41,
      gender: "male",
      customizations: "Driving myself. First time somewhere with weather like this.",
      answers: answers("right", "both", "both", "both", "right", "right", "right"),
      profile: null,
    },
  },
];

/**
 * The token ceiling used to force a truncation on purpose.
 *
 * §13 lists "truncated output at the token ceiling" as a first-class failure
 * case, and the only honest way to know how the system behaves there is to make
 * it happen. Deliberately far below any real ceiling.
 */
export const TRUNCATION_PROBE_CEILING = 1_024;
