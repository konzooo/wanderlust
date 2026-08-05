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
    public static let currentSchemaVersion = 2

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

    /// Interest deep dives, kept apart from `suggestions.dynamicSuggestions` so
    /// they can be counted against the per-trip cap, shown with their own
    /// provenance, and migrated independently. Rendered inline in the feed.
    public var deepDives: [Suggestions.Category]?

    /// The traveller's Worth-it/Skip decisions. An absent entry is *undecided*,
    /// which is a real and common state — see ``WorthItDecision``.
    public var worthItDecisions: [UUID: WorthItDecision]?

    /// Coarse, personal, and never shared. See ``CoarseAccommodation``.
    public var accommodation: CoarseAccommodation?

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

    /// Designated initializer.
    public init(
        details: Details,
        itinerary: Itinerary,
        suggestionsState: ComponentState<Suggestions>,
        deepDives: [Suggestions.Category]? = nil,
        worthItDecisions: [UUID: WorthItDecision]? = nil,
        accommodation: CoarseAccommodation? = nil,
        favorites: Favorites = .init(),
        shareCode: String? = nil,
        tripKey: String? = nil,
        schemaVersion: Int = Trip.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.details = details
        self.itinerary = itinerary
        self.suggestionsState = suggestionsState
        self.deepDives = deepDives
        self.worthItDecisions = worthItDecisions
        self.accommodation = accommodation
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
        favorites: Favorites = .init(),
        shareCode: String? = nil,
        tripKey: String? = nil
    ) {
        self.init(
            details: details,
            itinerary: itinerary,
            suggestionsState: suggestions.map(ComponentState.ready) ?? .absent,
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
        case deepDives
        case worthItDecisions
        case accommodation
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

        deepDives = try container.decodeIfPresent([Suggestions.Category].self, forKey: .deepDives)
        worthItDecisions = try container.decodeIfPresent(
            [UUID: WorthItDecision].self, forKey: .worthItDecisions
        )
        accommodation = try container.decodeIfPresent(
            CoarseAccommodation.self, forKey: .accommodation
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
        try container.encodeIfPresent(deepDives, forKey: .deepDives)
        try container.encodeIfPresent(worthItDecisions, forKey: .worthItDecisions)
        try container.encodeIfPresent(accommodation, forKey: .accommodation)
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
            deepDives: deepDives ?? stored.deepDives,
            worthItDecisions: worthItDecisions ?? stored.worthItDecisions,
            accommodation: accommodation ?? stored.accommodation,
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
