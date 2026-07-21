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
                let loadedTrips = try storage.fetchAll()
                // Defensive de‑duplication in memory by duplicateIdentity
                var seen: Set<Trip.Details> = []
                let uniqueTrips = loadedTrips.filter { trip in
                    if seen.contains(trip.duplicateIdentity) { return false }
                    seen.insert(trip.duplicateIdentity)
                    return true
                }
                let sortedTrips = uniqueTrips.sorted { $0.details.destination.name.localizedCaseInsensitiveCompare($1.details.destination.name) == .orderedAscending }
                
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
