//
//  Trip.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 6/7/25.
//

import Foundation

/// One saved trip, as it exists on disk.
///
/// **Storage optionality is not schema optionality.** A `Trip` is JSON read back
/// with `try?`, so a new non-optional field makes every previously saved trip
/// vanish silently, with no error anywhere. Every field added after v1 is
/// therefore optional and decoded with `decodeIfPresent`, following the
/// precedent `shareCode` set. That has nothing to do with the strict JSON
/// schemas the backend sends the model, where optionality is expressed as a
/// nullable union and every property is required.
public struct Trip: Identifiable, Codable, Equatable, Hashable, Sendable {
    /// Bumped whenever the on-disk shape changes in a way a reader must know
    /// about. v1 files predate the field entirely and decode as 1.
    ///
    /// - 1: itinerary + optional `suggestions` + favourites (+ later `shareCode`).
    /// - 2: components carry explicit ``ComponentState``; adds `tripKey`,
    ///   `deepDives`, `worthItDecisions` and `accommodation`.
    /// - 3: the rest of the generated content — `whereToStay` and
    ///   `interestPrompts` and `knowBeforeYouGoState`.
    /// - 4: grounded `nearYouState` and the generation input needed only for an
    ///   explicit manual regeneration after reopening a saved trip.
    public static let currentSchemaVersion = 4

    public let id = UUID()
    public let schemaVersion: Int
    public let details: Details
    public let itinerary: Itinerary

    /// Suggestions as an explicit state.
    ///
    /// The bug this replaced: saving wrote `suggestions ?? Suggestions()`, so a
    /// trip saved while its suggestions call was still running stored an empty
    /// value that was indistinguishable from a genuine empty result. It could
    /// never be retried and never be explained.
    public var suggestionsState: ComponentState<Suggestions>

    /// Know Before You Go, as an explicit state for the same reason suggestions
    /// is one: a trip saved while the call was still running must record "not
    /// yet", not an empty briefing that can never be retried or explained.
    ///
    /// Shared content — it travels in a share and a group trip has one — and it
    /// is never regenerated on reopen.
    public var knowBeforeYouGoState: ComponentState<KnowBeforeYouGo>

    /// Interest deep dives, kept apart from `suggestions.dynamicSuggestions` so
    /// they can be counted against the per-trip cap, shown with their own
    /// provenance, and migrated independently. Rendered inline in the feed.
    public var deepDives: [Suggestions.Category]?

    /// The Worth-it/Skip cards themselves. Shared content — it travels in a
    /// share; the *decisions* below deliberately do not.
    public var worthItItems: [WorthItItem]?

    /// The traveller's Worth-it/Skip decisions. An absent entry is *undecided*,
    /// which is a real and common state — see ``WorthItDecision``.
    public var worthItDecisions: [UUID: WorthItDecision]?

    /// The where-to-stay guide (D10). Shared content; not heartable (§9).
    public var whereToStay: [StayArea]?

    /// The three model-picked interest chip labels (D8).
    ///
    /// Only the model's three are stored. The three fixed chips — Running
    /// routes, Remote-work cafés, Climbing gyms — are a client-side constant
    /// and are deliberately not persisted: writing them into every trip file
    /// would mean an old saved trip could never pick up a change to the fixed
    /// set, and the plan's own migration note (§4) is that the fixed three
    /// still render when this is missing.
    public var interestPrompts: [String]?

    /// Coarse, personal, and never shared. See ``CoarseAccommodation``.
    public var accommodation: CoarseAccommodation?

    /// Grounded Near You output, personal to a solo traveller and never shared.
    /// Explicit state keeps a failed attempt distinct from an old trip that has
    /// never requested the component. It is never generated automatically.
    public var nearYouState: ComponentState<NearYou>

    /// The structured preferences used for this trip's model calls.
    ///
    /// Optional for backward compatibility. It lets a saved trip explicitly
    /// regenerate Near You without falling back to destination-only context;
    /// it is never part of a published share.
    public var generationInput: TripGenerationInput?

    public var favorites: Favorites

    /// The share code associated with this trip file. On a trip in `TripStorage`
    /// ("My Trips"), it means "I published this trip under this code." On a trip
    /// in the separate received-trips store ("Shared"), it means "I received this
    /// trip via this code." The two live in different folders, so there's no
    /// ambiguity between the two meanings in practice. `nil` for every trip saved
    /// before trip sharing shipped — decodes via `decodeIfPresent`, no migration.
    public var shareCode: String?

    /// Scopes the backend's per-trip generation caps. Minted once when the trip
    /// is first generated and persisted so the cap follows the trip instead of
    /// resetting every time the traveller reopens it. `nil` on trips saved
    /// before it existed; a caller that needs one mints it and re-saves.
    public var tripKey: String?

    /// The generated suggestions, if there are any. Kept as the primary
    /// read path so the rest of the app is unaffected by the state change;
    /// reach for ``suggestionsState`` when absent-vs-failed matters.
    public var suggestions: Suggestions? { suggestionsState.value }

    /// The generated briefing, if there is one. Same read-path convention as
    /// ``suggestions``.
    public var knowBeforeYouGo: KnowBeforeYouGo? { knowBeforeYouGoState.value }

    public var nearYou: NearYou? { nearYouState.value }

    /// Designated initializer.
    public init(
        details: Details,
        itinerary: Itinerary,
        suggestionsState: ComponentState<Suggestions>,
        knowBeforeYouGoState: ComponentState<KnowBeforeYouGo> = .absent,
        deepDives: [Suggestions.Category]? = nil,
        worthItItems: [WorthItItem]? = nil,
        worthItDecisions: [UUID: WorthItDecision]? = nil,
        whereToStay: [StayArea]? = nil,
        interestPrompts: [String]? = nil,
        accommodation: CoarseAccommodation? = nil,
        nearYouState: ComponentState<NearYou> = .absent,
        generationInput: TripGenerationInput? = nil,
        favorites: Favorites = .init(),
        shareCode: String? = nil,
        tripKey: String? = nil,
        schemaVersion: Int = Trip.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.details = details
        self.itinerary = itinerary
        self.suggestionsState = suggestionsState
        self.knowBeforeYouGoState = knowBeforeYouGoState
        self.deepDives = deepDives
        self.worthItItems = worthItItems
        self.worthItDecisions = worthItDecisions
        self.whereToStay = whereToStay
        self.interestPrompts = interestPrompts
        self.accommodation = accommodation
        self.nearYouState = nearYouState
        self.generationInput = generationInput
        self.favorites = favorites
        self.shareCode = shareCode
        self.tripKey = tripKey
    }

    /// Convenience for the many callers that hold a plain optional — a `nil`
    /// here means "there are none", which is `.absent`. A caller that knows a
    /// generation *failed* should use the designated initializer and say so.
    public init(
        details: Details,
        itinerary: Itinerary,
        suggestions: Suggestions?,
        knowBeforeYouGo: KnowBeforeYouGo? = nil,
        favorites: Favorites = .init(),
        shareCode: String? = nil,
        tripKey: String? = nil
    ) {
        self.init(
            details: details,
            itinerary: itinerary,
            suggestionsState: suggestions.map(ComponentState.ready) ?? .absent,
            knowBeforeYouGoState: knowBeforeYouGo.map(ComponentState.ready) ?? .absent,
            favorites: favorites,
            shareCode: shareCode,
            tripKey: tripKey
        )
    }

    public var destination: String {
        itinerary.destination ?? details.destination.name
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case details
        case itinerary
        /// v1 shape: the suggestions value itself, or the key absent entirely.
        case suggestions
        /// v2 shape: an explicit `ComponentState`.
        case suggestionsState
        case knowBeforeYouGoState
        case deepDives
        case worthItItems
        case worthItDecisions
        case whereToStay
        case interestPrompts
        case accommodation
        case nearYouState
        case generationInput
        case favorites
        case shareCode
        case tripKey
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        details = try container.decode(Details.self, forKey: .details)
        itinerary = try container.decode(Itinerary.self, forKey: .itinerary)

        // v2 first, then the v1 fallback. A v1 file that simply omitted
        // `suggestions` becomes `.absent`, which is exactly what it meant.
        if let state = try container.decodeIfPresent(
            ComponentState<Suggestions>.self, forKey: .suggestionsState
        ) {
            suggestionsState = state
        } else if let legacy = try container.decodeIfPresent(
            Suggestions.self, forKey: .suggestions
        ) {
            suggestionsState = .ready(legacy)
        } else {
            suggestionsState = .absent
        }

        // Absent on every trip saved before v3, which is exactly `.absent`:
        // nothing was requested and nothing was lost.
        knowBeforeYouGoState = try container.decodeIfPresent(
            ComponentState<KnowBeforeYouGo>.self, forKey: .knowBeforeYouGoState
        ) ?? .absent

        deepDives = try container.decodeIfPresent([Suggestions.Category].self, forKey: .deepDives)
        worthItItems = try container.decodeIfPresent([WorthItItem].self, forKey: .worthItItems)
        worthItDecisions = try container.decodeIfPresent(
            [UUID: WorthItDecision].self, forKey: .worthItDecisions
        )
        whereToStay = try container.decodeIfPresent([StayArea].self, forKey: .whereToStay)
        interestPrompts = try container.decodeIfPresent([String].self, forKey: .interestPrompts)
        accommodation = try container.decodeIfPresent(
            CoarseAccommodation.self, forKey: .accommodation
        )
        nearYouState = try container.decodeIfPresent(
            ComponentState<NearYou>.self, forKey: .nearYouState
        ) ?? .absent
        generationInput = try container.decodeIfPresent(
            TripGenerationInput.self, forKey: .generationInput
        )
        favorites = try container.decodeIfPresent(Favorites.self, forKey: .favorites) ?? .init()
        shareCode = try container.decodeIfPresent(String.self, forKey: .shareCode)
        tripKey = try container.decodeIfPresent(String.self, forKey: .tripKey)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Trip.currentSchemaVersion, forKey: .schemaVersion)
        try container.encode(details, forKey: .details)
        try container.encode(itinerary, forKey: .itinerary)
        try container.encode(suggestionsState, forKey: .suggestionsState)
        try container.encode(knowBeforeYouGoState, forKey: .knowBeforeYouGoState)
        try container.encodeIfPresent(deepDives, forKey: .deepDives)
        try container.encodeIfPresent(worthItItems, forKey: .worthItItems)
        try container.encodeIfPresent(worthItDecisions, forKey: .worthItDecisions)
        try container.encodeIfPresent(whereToStay, forKey: .whereToStay)
        try container.encodeIfPresent(interestPrompts, forKey: .interestPrompts)
        try container.encodeIfPresent(accommodation, forKey: .accommodation)
        try container.encode(nearYouState, forKey: .nearYouState)
        try container.encodeIfPresent(generationInput, forKey: .generationInput)
        try container.encode(favorites, forKey: .favorites)
        try container.encodeIfPresent(shareCode, forKey: .shareCode)
        try container.encodeIfPresent(tripKey, forKey: .tripKey)
    }
}

// MARK: - Merge-on-complete

public extension Trip {
    /// The version of this trip that should actually be written, given what is
    /// already on disk for it.
    ///
    /// A trip becomes saveable as soon as its itinerary is ready; anything still
    /// generating is written as `.absent` and merged in when it lands. The whole
    /// policy rests on one rule — **an unfinished component must never erase a
    /// finished one** — so every field here either takes the newer value or
    /// falls back to the stored one, and none of them clobbers with emptiness.
    ///
    /// The personal layer (favourites, decisions, accommodation) always takes
    /// the in-memory value: it reflects what the traveller just did.
    func merged(over stored: Trip) -> Trip {
        Trip(
            details: details,
            itinerary: itinerary,
            suggestionsState: suggestionsState.merged(over: stored.suggestionsState),
            knowBeforeYouGoState: knowBeforeYouGoState.merged(over: stored.knowBeforeYouGoState),
            deepDives: deepDives ?? stored.deepDives,
            worthItItems: worthItItems ?? stored.worthItItems,
            worthItDecisions: worthItDecisions ?? stored.worthItDecisions,
            whereToStay: whereToStay ?? stored.whereToStay,
            interestPrompts: interestPrompts ?? stored.interestPrompts,
            accommodation: accommodation ?? stored.accommodation,
            nearYouState: nearYouState.merged(over: stored.nearYouState),
            generationInput: generationInput ?? stored.generationInput,
            favorites: favorites,
            shareCode: shareCode ?? stored.shareCode,
            tripKey: tripKey ?? stored.tripKey
        )
    }
}

public extension Trip {
    // Mock trips
    static var mockList: [Trip] {
        [
            Trip(
                details: Details(
                    destination: Place(name: "Barcelona, Spain"),
                    members: Details.Members(groupType: .couple),
                    duration: 3,
                    month: .may
                ),
                itinerary: Itinerary.mock,
                suggestions: Suggestions.mock
            ),
            Trip(
                details: Details(
                    destination: Place(name: "Athens, Greece"),
                    members: Details.Members(groupType: .couple),
                    duration: 3,
                    month: .may
                ),
                itinerary: Itinerary(
                    name: "Athens Adventure",
                    destination: "Athens, Greece",
                    title: "Athens Itinerary: Explore the Ancient City",
                    segments: [
                        .mock,
                        .mock2
                    ]
                ),
                suggestions: Suggestions.mock
            )
        ]
    }
}
