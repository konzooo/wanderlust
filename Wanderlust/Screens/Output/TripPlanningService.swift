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

// MARK: - Protocols

/// Produces a trip itinerary from this trip's generation request.
protocol ItineraryGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.Itinerary
}

/// Produces trip suggestions from this trip's generation request.
protocol SuggestionsGenerating {
    func generate(_ request: TripGenerationRequest) async throws -> Trip.Suggestions
}

// MARK: - Live services

/// Both live services are thin: everything that used to make these interesting
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

    func generate(_ request: TripGenerationRequest) async throws -> Trip.Suggestions {
        try await service.generate(.suggestions, for: request)
    }
}

enum TripPlanningServices {
    static func itinerary() -> any ItineraryGenerating {
        DebugSettings.useMockTripData ? MockItineraryService() : BackendItineraryService()
    }

    static func suggestions() -> any SuggestionsGenerating {
        DebugSettings.useMockTripData ? MockSuggestionsService() : BackendSuggestionsService()
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

    func generate(_ request: TripGenerationRequest) async throws -> Trip.Suggestions {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return .mock
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
