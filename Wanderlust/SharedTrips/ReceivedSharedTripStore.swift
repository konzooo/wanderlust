import CoreArchitecture
import CoreModels

/// Local, durable copies of trips shared WITH this device. A completely
/// separate on-disk root from `TripStorage` ("TripStore") — received trips
/// never appear in "My Trips" and vice versa. Once a trip lands here (on
/// first successful open of a share link), it is this device's own copy:
/// nothing here changes if the original sharer edits or deletes their trip.
///
/// Reuses `Trip`'s existing `FilePersistable` conformance (`TripStore.swift`)
/// end to end — same encode/decode/dedupe logic as "My Trips", just a
/// different root folder.
public typealias ReceivedSharedTripStorage = FileStore<Trip>

public extension ReceivedSharedTripStorage {
    static func received() throws -> FileStore<Trip> {
        try FileStore<Trip>(rootFolderName: "ReceivedSharedTripStore")
    }
}
