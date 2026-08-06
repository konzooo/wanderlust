//
//  TripPlanningService.swift
//  Wanderlust
//
//  Trip planning services. Generation happens behind the backend; DEBUG builds
//  can still swap in bundled mock data instead of calling it while testing the
//  flow.
//

import CoreArchitecture
import CoreModels
import Foundation

// MARK: - Wire payloads

/// What the suggestions call returns, in either variant.
///
/// One decode target for both arms of the D15 experiment. Under `combined` the
/// extras arrive here; under `split` they arrive from their own calls and the
/// corresponding properties are `nil`. The store fans the parts out into the
/// same per-section state either way, so nothing downstream — the UI, the
/// favourites plumbing, persistence, sharing — can tell which arm ran.
struct SuggestionsPayload: Decodable, Equatable, Sendable {
    let suggestions: Trip.Suggestions
    /// The three model-picked chip labels. Empty is normal and not a failure.
    let interestPrompts: [String]
    /// `nil` under the split variant, where these come from their own calls.
    let worthIt: [Trip.WorthItItem]?
    let whereToStay: [Trip.StayArea]?

    init(
        suggestions: Trip.Suggestions,
        interestPrompts: [String] = [],
        worthIt: [Trip.WorthItItem]? = nil,
        whereToStay: [Trip.StayArea]? = nil
    ) {
        self.suggestions = suggestions
        self.interestPrompts = interestPrompts
        self.worthIt = worthIt
        self.whereToStay = whereToStay
    }

    private enum CodingKeys: String, CodingKey {
        case dynamicSuggestions, staticSuggestions
        case interestPrompts, worthIt, whereToStay
    }

    /// The extras decode leniently on purpose.
    ///
    /// The categories are what the traveller opened the tab for; a malformed
    /// Worth-it card must not take the whole suggestions feed down with it. The
    /// backend has already validated counts and dropped unusable items — this
    /// is the second line, for the case where an older build meets a newer
    /// server shape.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        suggestions = Trip.Suggestions(
            dynamicSuggestions: try container.decodeIfPresent(
                [Trip.Suggestions.Category].self, forKey: .dynamicSuggestions
            ) ?? [],
            staticSuggestions: try container.decodeIfPresent(
                [Trip.Suggestions.Category].self, forKey: .staticSuggestions
            ) ?? []
        )
        interestPrompts = (try? container.decodeIfPresent(
            [String].self, forKey: .interestPrompts
        )) ?? []
        worthIt = try? container.decodeIfPresent([Trip.WorthItItem].self, forKey: .worthIt)
        whereToStay = try? container.decodeIfPresent([Trip.StayArea].self, forKey: .whereToStay)
    }
}

/// The split-variant Worth-it/Skip call's envelope.
struct WorthItPayload: Decodable, Equatable, Sendable {
    let items: [Trip.WorthItItem]
}

/// The split-variant where-to-stay call's envelope.
struct WhereToStayPayload: Decodable, Equatable, Sendable {
    let areas: [Trip.StayArea]
}

// MARK: - Protocols

/// Produces a trip itinerary from this trip's generation request.
protocol ItineraryGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary
}

/// Produces trip suggestions — and, under the combined variant, the rest of
/// the Discover content — from this trip's generation request.
protocol SuggestionsGenerating {
    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload
}

/// Produces the four Worth-it/Skip cards. Only used by the split variant.
protocol WorthItGenerating {
    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> [Trip.WorthItItem]
}

/// Produces the where-to-stay guide. Only used by the split variant.
protocol WhereToStayGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> [Trip.StayArea]
}

/// Produces the Know Before You Go briefing from this trip's generation request.
protocol KnowBeforeYouGoGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.KnowBeforeYouGo
}

/// Produces one append-only category for the interest the traveller tapped.
protocol DeepDiveGenerating {
    func generate(
        _ request: TripGenerationRequest,
        interest: String,
        alreadyRecommended: [String]
    ) async throws -> Trip.Suggestions.Category
}

// MARK: - Live services

/// Every live service is thin: everything that used to make these interesting
/// — the prompt, the JSON schema, the token ceiling, the model — moved to the
/// backend, where the solo and group paths share one copy of each.
struct BackendItineraryService: ItineraryGenerating {
    var service: TripGenerationService = .shared

    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary {
        try await service.generate(.itinerary, for: request)
    }
}

struct BackendSuggestionsService: SuggestionsGenerating {
    var service: TripGenerationService = .shared

    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        try await service.generate(
            .suggestions,
            for: request,
            alreadyRecommended: alreadyRecommended
        )
    }
}

struct BackendWorthItService: WorthItGenerating {
    var service: TripGenerationService = .shared

    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> [Trip.WorthItItem] {
        let payload: WorthItPayload = try await service.generate(
            .worthIt,
            for: request,
            alreadyRecommended: alreadyRecommended
        )
        return payload.items
    }
}

struct BackendWhereToStayService: WhereToStayGenerating {
    var service: TripGenerationService = .shared

    func generate(_ request: TripGenerationRequest) async throws -> [Trip.StayArea] {
        // Deliberately no `alreadyRecommended`: this call names neighbourhoods
        // to sleep in, and telling it to avoid the places the itinerary already
        // uses would push it away from exactly the areas worth staying in.
        let payload: WhereToStayPayload = try await service.generate(.whereToStay, for: request)
        return payload.areas
    }
}

struct BackendKnowBeforeYouGoService: KnowBeforeYouGoGenerating {
    var service: TripGenerationService = .shared

    func generate(_ request: TripGenerationRequest) async throws -> Trip.KnowBeforeYouGo {
        try await service.generate(.knowBeforeYouGo, for: request)
    }
}

struct BackendDeepDiveService: DeepDiveGenerating {
    var service: TripGenerationService = .shared

    func generate(
        _ request: TripGenerationRequest,
        interest: String,
        alreadyRecommended: [String]
    ) async throws -> Trip.Suggestions.Category {
        try await service.generate(
            .deepDive,
            for: request,
            interest: interest,
            alreadyRecommended: alreadyRecommended
        )
    }
}

enum TripPlanningServices {
    static func itinerary() -> any ItineraryGenerating {
        DebugSettings.useMockTripData ? MockItineraryService() : BackendItineraryService()
    }

    static func suggestions() -> any SuggestionsGenerating {
        DebugSettings.useMockTripData ? MockSuggestionsService() : BackendSuggestionsService()
    }

    static func worthIt() -> any WorthItGenerating {
        DebugSettings.useMockTripData ? MockWorthItService() : BackendWorthItService()
    }

    static func whereToStay() -> any WhereToStayGenerating {
        DebugSettings.useMockTripData ? MockWhereToStayService() : BackendWhereToStayService()
    }

    static func knowBeforeYouGo() -> any KnowBeforeYouGoGenerating {
        DebugSettings.useMockTripData
            ? MockKnowBeforeYouGoService()
            : BackendKnowBeforeYouGoService()
    }

    static func deepDive() -> any DeepDiveGenerating {
        DebugSettings.useMockTripData ? MockDeepDiveService() : BackendDeepDiveService()
    }
}

// MARK: - Bridging the in-flight state to the persisted one

extension AsyncValue where Value: Codable & Hashable {
    /// How a component's live screen state is written to disk.
    ///
    /// `.initial` and `.loading` both become `.absent`: nothing was lost, and a
    /// later re-save merges the real result in. What must never happen — and is
    /// what this replaced — is writing an empty value to stand in for a call
    /// that hadn't finished.
    var persisted: ComponentState<Value> {
        switch self {
        case .initial, .loading:
            return .absent
        case .error(let error):
            return .failed(code: Self.failureCode(for: error))
        case .loaded(let value):
            return .ready(value)
        }
    }

    private static func failureCode(for error: Error) -> String {
        if let generation = error as? TripGenerationError { return generation.code }
        return AnalyticsSanitizer.errorCategory(error).rawValue
    }
}

extension ComponentState {
    /// Restores a persisted component into the screen's independent live state.
    /// No work is started here: `.absent` remains `.initial` and `.failed`
    /// remains an explicit retryable error until the traveller acts.
    var asyncValue: AsyncValue<Value> {
        switch self {
        case .absent:
            return .initial
        case .failed(let code):
            return .error(TripGenerationError(code: code))
        case .ready(let value):
            return .loaded(value)
        }
    }
}

extension AsyncValue {
    /// The content to persist for a section stored as a plain optional array.
    ///
    /// `nil` while a call is in flight or after it failed, so a re-save merges
    /// over whatever is already on disk rather than erasing it. The distinction
    /// `ComponentState` draws is not carried for these sections: §4 stores them
    /// as plain fields, and a trip is never re-generated on reopen, so "failed"
    /// and "not there" lead to exactly the same behaviour next launch.
    var persistedContent: Value? {
        guard case let .loaded(value) = self else { return nil }
        return value
    }
}

// MARK: - Mock services

/// Returns bundled mock itinerary data after a short delay so the loading state
/// is still exercised. Never calls the network.
struct MockItineraryService: ItineraryGenerating {
    var delayNanoseconds: UInt64 = 1_000_000_000

    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return .mock
    }
}

/// Returns bundled mock suggestions data after a short delay. Never calls the network.
struct MockSuggestionsService: SuggestionsGenerating {
    var delayNanoseconds: UInt64 = 1_000_000_000

    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> SuggestionsPayload {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        // Mirrors the SPLIT variant: extras arrive from their own mock calls,
        // so the mock path exercises the same fan-out the default build uses.
        return SuggestionsPayload(
            suggestions: .mock,
            interestPrompts: ["Natural wine bars", "Rooftop sunsets", "Modernista rooftops"]
        )
    }
}

struct MockWorthItService: WorthItGenerating {
    var delayNanoseconds: UInt64 = 1_200_000_000

    func generate(
        _ request: TripGenerationRequest,
        alreadyRecommended: [String]
    ) async throws -> [Trip.WorthItItem] {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return Trip.WorthItItem.mockSet
    }
}

struct MockWhereToStayService: WhereToStayGenerating {
    var delayNanoseconds: UInt64 = 1_200_000_000

    func generate(_ request: TripGenerationRequest) async throws -> [Trip.StayArea] {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return Trip.StayArea.mockSet
    }
}

/// Returns a bundled mock briefing after a short delay. Never calls the network.
struct MockKnowBeforeYouGoService: KnowBeforeYouGoGenerating {
    var delayNanoseconds: UInt64 = 1_000_000_000

    func generate(_ request: TripGenerationRequest) async throws -> Trip.KnowBeforeYouGo {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return .mock
    }
}

struct MockDeepDiveService: DeepDiveGenerating {
    var delayNanoseconds: UInt64 = 1_000_000_000

    func generate(
        _ request: TripGenerationRequest,
        interest: String,
        alreadyRecommended: [String]
    ) async throws -> Trip.Suggestions.Category {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        let sample = Trip.Suggestions.mock.dynamicSuggestions[0]
        return Trip.Suggestions.Category(
            ID: nil,
            title: interest,
            texts: sample.texts
        )
    }
}

// MARK: - Debug settings

/// DEBUG-only feature flags. In release builds the flag is compiled out and
/// always reports its production default.
enum DebugSettings {
    /// Shared `UserDefaults` key so the toggle UI and the flag stay in sync.
    static let useMockTripDataKey = "debug_useMockTripData"

    /// When `true`, trip planning uses bundled mock data instead of the backend.
    /// Always `false` in release builds.
    static var useMockTripData: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: useMockTripDataKey)
        #else
        return false
        #endif
    }
}
