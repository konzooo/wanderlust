import CoreModels
import Foundation

/// Resolves a share code into a displayable trip, local-first:
/// 1. Is this device the one who published it? Show their own saved copy.
/// 2. Has this device already received it? Show the local cache — instant,
///    offline, and immune to the sharer later editing or deleting their trip.
/// 3. Otherwise, fetch it once from Convex, persist a local copy, then show it.
///
/// Deliberately not a live subscription: once a shared trip lands locally, it
/// is never fetched again (see `ReceivedSharedTripStorage`).
final class SharedTripStore: ObservableObject {
    @Published var state: State

    init(code: String) {
        state = State(code: code)
        resolve(code: code)
    }

    private func resolve(code: String) {
        state.resolved = .loading
        Task { @MainActor in
            do {
                let ownedAll = try TripStorage().fetchAll()
                if let owned = ownedAll.first(where: { $0.shareCode == code }) {
                    state.resolved = .loaded(Self.outputState(for: owned, mode: .savedTrip))
                    return
                }
                let receivedAll = try ReceivedSharedTripStorage.received().fetchAll()
                if let received = receivedAll.first(where: { $0.shareCode == code }) {
                    state.resolved = .loaded(Self.outputState(for: received, mode: .sharedTrip))
                    return
                }
                guard let dto = try await SharedTripService.shared.fetchOnce(code: code) else {
                    state.resolved = .failed
                    return
                }
                let trip = Trip(
                    details: Trip.Details(
                        destination: Place(name: dto.destination),
                        members: Trip.Details.Members(groupType: Trip.Details.GroupType(rawValue: dto.groupType) ?? .solo),
                        duration: dto.durationDays,
                        month: Month(rawValue: dto.startMonth) ?? .january
                    ),
                    itinerary: dto.itinerary,
                    suggestions: dto.suggestions,
                    favorites: dto.favorites ?? .init(),
                    shareCode: code
                )
                try ReceivedSharedTripStorage.received().save(trip)
                state.resolved = .loaded(Self.outputState(for: trip, mode: .sharedTrip))
            } catch {
                state.resolved = .failed
            }
        }
    }

    private static func outputState(for trip: Trip, mode: TripOutputStore.State.Mode) -> TripOutputStore.State {
        var output = TripOutputStore.State(
            tripSummary: trip.destination,
            details: trip.details,
            favorites: trip.favorites,
            saved: mode == .savedTrip,
            mode: mode,
            shareCode: trip.shareCode
        )
        output.itineraryResponse = .loaded(trip.itinerary)
        if let suggestions = trip.suggestions {
            output.suggestionsResponse = .loaded(suggestions)
        }
        return output
    }
}

extension SharedTripStore {
    struct State {
        let code: String
        var resolved: Resolution = .loading
    }

    /// A small store-local resolution enum, rather than reusing the shared
    /// `AsyncValue<Value: Sendable>` — `TripOutputStore.State` isn't declared
    /// `Sendable`, and this avoids taking on that cross-module conformance
    /// just for this one screen.
    enum Resolution {
        case loading
        case loaded(TripOutputStore.State)
        case failed
    }
}
