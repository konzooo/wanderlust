//
//  TripStore.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 7/7/25.
//

import CoreArchitecture
import CoreModels

// ---------------------------------------------------------------------------
// MARK: - 3. Make Trip conform to FilePersistable
// ---------------------------------------------------------------------------

extension Trip: @retroactive FilePersistable {
    /// Folder == destination name ("Barcelona_Spain").
    public var groupingFolder: String {
        itinerary.destination ?? details.destination.name
    }
    /// A generated trip's backend key is also its durable local identity.
    /// Two independently generated trips may have identical destination/date/
    /// party details but different answers and output, so those trips must not
    /// overwrite one another when automatic persistence runs. Files written
    /// before `tripKey` existed retain the legacy details-based behaviour.
    public var duplicateIdentity: TripStorageIdentity {
        tripKey.map(TripStorageIdentity.tripKey) ?? .legacyDetails(details)
    }
}

public enum TripStorageIdentity: Hashable, Sendable {
    case tripKey(String)
    case legacyDetails(Trip.Details)
}

public typealias TripStorage = FileStore<Trip>


// ---------------------------------------------------------------------------
// MARK: - 5. Example usage (uncomment inside a unit test or SwiftUI preview)
// ---------------------------------------------------------------------------
//
// do {
//     let store = try TripStore()
//
//     // Save mock trips
//     try Trip.mockList.forEach { try store.save($0) }
//
//     // Fetch everything
//     let all = try store.fetchAll()
//     print("All trips:", all.count)
//
//     // Fetch only Barcelona
//     let barcelona = try store.fetch(inGrouping: "Barcelona, Spain")
//     print("Barcelona trips:", barcelona.count)
//
//     // Fetch single by id
//     if let first = all.first, let found = try store.fetch(id: first.id) {
//         print("Found trip \(found.id) – destination:", found.details.destination.name)
//     }
// } catch {
//     print("FileStore error:", error)
// }
//
