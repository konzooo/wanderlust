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
    /// Trips with exactly the same `details` are considered duplicates.
    public var duplicateIdentity: Trip.Details { details }
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
