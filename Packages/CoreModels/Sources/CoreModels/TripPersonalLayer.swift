//
//  TripPersonalLayer.swift
//  CoreModels
//
//  The parts of a trip that belong to one traveller rather than to the trip:
//  decisions they made, and roughly where they are staying. Neither travels in
//  a share.
//

import Foundation

/// What the traveller decided about one Worth-it/Skip card.
///
/// Favourites is a `Set<UUID>` and can only say liked-or-not, which cannot
/// express *undecided*. Undecided is the state that matters here — it is what
/// the four cards start in, and what Undo returns them to — so it is
/// represented by the absence of an entry rather than by a third case.
public enum WorthItDecision: String, Codable, Hashable, Sendable {
    /// Kept. Always accompanied by an entry in `Favorites`.
    case kept
    /// Skipped. Deliberately leaves `Favorites` untouched.
    case skipped
}

/// Where the traveller is staying, stored deliberately coarsely.
///
/// Enough to re-run a nearby search; not a record of where someone slept. The
/// exact resolved address never leaves the device and is never persisted — see
/// the plan's D13. Rounding happens in ``init(label:latitude:longitude:precision:)``
/// so a caller cannot store a precise point by forgetting to.
public struct CoarseAccommodation: Codable, Hashable, Sendable {
    /// What to show the traveller, e.g. "El Born, Barcelona". Never a street address.
    public let label: String
    /// Rounded to three decimal places — roughly 100 m.
    public let latitude: Double
    public let longitude: Double
    public let precision: Precision

    /// How exact the underlying search centre was, so the UI can be honest
    /// about whether distances are real or approximate.
    public enum Precision: String, Codable, Hashable, Sendable {
        /// Resolved from an address or a specific place the traveller chose.
        case address
        /// A neighbourhood centroid, chosen before anything was booked.
        case neighbourhood
    }

    public init(label: String, latitude: Double, longitude: Double, precision: Precision) {
        self.label = label
        self.latitude = (latitude * 1_000).rounded() / 1_000
        self.longitude = (longitude * 1_000).rounded() / 1_000
        self.precision = precision
    }
}
