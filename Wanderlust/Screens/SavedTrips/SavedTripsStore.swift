//
//  SavedTripsStore.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 7/7/25.
//

import CoreArchitecture
import Combine
import CoreModels
import Foundation

class SavedTripsStore: ObservableStore {
    @Published var state: State
    
    init(initialState: State = .init()) {
        state = initialState
    }
    
    func send(_ action: Action) {
        switch action {
        case .loadSavedTrips:
            loadSavedTrips()
            
        case .tripTapped(let trip):
            print("Trip tapped: \(trip)")
        }
    }
    
    func loadSavedTrips() {
        state.savedTrips = .loading
        
        Task {
            do {
                let sortedTrips = try Self.loadTrips()
                
                await MainActor.run {
                    self.state.savedTrips = .loaded(sortedTrips)
                }
            } catch {
                await MainActor.run {
                    self.state.savedTrips = .error(error)
                }
            }
        }
    }

    /// Shared read path for My Trips and Home. The legacy-date write is a
    /// one-time migration and deliberately does not emit a change notification.
    nonisolated static func loadTrips() throws -> [Trip] {
        let storage = try TripStorage()
        let candidates = try storage.fetchAllWithMetadata().map {
            StoredTripCandidate(trip: $0.value, fallbackCreatedAt: $0.creationDate)
        }
        return newestFirstUnique(candidates).map { candidate in
            var trip = candidate.trip
            guard trip.createdAt == nil,
                  let fallback = candidate.fallbackCreatedAt else { return trip }
            trip.createdAt = fallback
            _ = try? storage.save(trip)
            return trip
        }
    }

    /// Sort before de-duplicating so that, if an older app left two files for
    /// the same logical trip, the most recently created copy is the one kept.
    /// Legacy trips without a creation date stay visible after dated trips and
    /// retain a deterministic alphabetical order.
    nonisolated static func newestFirstUnique(_ trips: [Trip]) -> [Trip] {
        newestFirstUnique(
            trips.map { StoredTripCandidate(trip: $0, fallbackCreatedAt: nil) }
        ).map(\.trip)
    }

    nonisolated static func newestFirstUnique(
        _ candidates: [StoredTripCandidate]
    ) -> [StoredTripCandidate] {
        let sorted = candidates.sorted { lhs, rhs in
            switch (lhs.effectiveCreatedAt, rhs.effectiveCreatedAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.trip.details.destination.name.localizedCaseInsensitiveCompare(
                    rhs.trip.details.destination.name
                ) == .orderedAscending
            }
        }

        var seen: Set<TripStorageIdentity> = []
        return sorted.filter { seen.insert($0.trip.duplicateIdentity).inserted }
    }

    struct StoredTripCandidate: Sendable {
        let trip: Trip
        let fallbackCreatedAt: Date?

        var effectiveCreatedAt: Date? { trip.createdAt ?? fallbackCreatedAt }
    }
}

extension SavedTripsStore {
    struct State: Equatable, Hashable {
        var savedTrips: AsyncValue<[Trip]> = .initial
    }
    
    enum Action: Equatable {
        case loadSavedTrips
        case tripTapped(Trip)
    }
}

enum TripOutputStateFactory {
    @MainActor
    static func savedTrip(_ trip: Trip) -> TripOutputStore.State {
        let suggestions: AsyncValue<Trip.Suggestions> = trip.suggestions.map(AsyncValue.loaded) ?? .initial
        var state = TripOutputStore.State(
            details: trip.details,
            selectedContentTab: .discover,
            favorites: trip.favorites,
            saved: true,
            mode: .savedTrip,
            shareCode: trip.shareCode,
            itineraryResponse: .loaded(trip.itinerary),
            suggestionsResponse: suggestions,
            knowBeforeYouGoResponse: trip.knowBeforeYouGo.map(AsyncValue.loaded) ?? .initial
        )
        state.worthItResponse = trip.worthItItems.map(AsyncValue.loaded) ?? .initial
        state.whereToStayResponse = trip.whereToStay.map(AsyncValue.loaded) ?? .initial
        state.interestPrompts = trip.interestPrompts ?? []
        state.worthItDecisions = trip.worthItDecisions ?? [:]
        state.deepDives = trip.deepDives
        state.accommodation = trip.accommodation
        state.nearYouResponse = trip.nearYouState.asyncValue
        if let imageURL = trip.imageUrl.flatMap(URL.init(string:)) {
            state.imageUrlResponse = .loaded(imageURL)
        }
        state.manualGenerationRequest = TripGenerationRequest(
            tripKey: trip.tripKey ?? TripKey.mint(),
            input: trip.generationInput
                ?? TripGenerationInput(details: trip.details, answers: [])
        )
        return state
    }
}
