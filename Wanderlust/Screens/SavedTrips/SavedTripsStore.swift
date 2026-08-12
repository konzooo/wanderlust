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
                let storage = try TripStorage()
                let candidates = try storage.fetchAllWithMetadata().map {
                    StoredTripCandidate(
                        trip: $0.value,
                        fallbackCreatedAt: $0.creationDate
                    )
                }
                let uniqueCandidates = Self.newestFirstUnique(candidates)
                let sortedTrips = uniqueCandidates.map { candidate in
                    var trip = candidate.trip
                    guard trip.createdAt == nil,
                          let fallback = candidate.fallbackCreatedAt else {
                        return trip
                    }

                    // One-time migration for pre-v5 files. Once the fallback is
                    // inside the JSON, later edits cannot change its ordering.
                    trip.createdAt = fallback
                    _ = try? storage.save(trip)
                    return trip
                }
                
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

        var seen: Set<Trip.Details> = []
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
