//
//  Trip.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 6/7/25.
//

import Foundation

public struct Trip: Identifiable, Codable, Equatable, Hashable, Sendable {
    public let id = UUID()
    public let details: Details
    public let itinerary: Itinerary
    public let suggestions: Suggestions?
    public var favorites: Favorites
    /// The share code associated with this trip file. On a trip in `TripStorage`
    /// ("My Trips"), it means "I published this trip under this code." On a trip
    /// in the separate received-trips store ("Shared"), it means "I received this
    /// trip via this code." The two live in different folders, so there's no
    /// ambiguity between the two meanings in practice. `nil` for every trip saved
    /// before trip sharing shipped — decodes via `decodeIfPresent`, no migration.
    public var shareCode: String?

    public init(
        details: Details,
        itinerary: Itinerary,
        suggestions: Suggestions?,
        favorites: Favorites = .init(),
        shareCode: String? = nil
    ) {
        self.details     = details
        self.itinerary   = itinerary
        self.suggestions = suggestions
        self.favorites   = favorites
        self.shareCode   = shareCode
    }
    
    public var destination: String {
        itinerary.destination ?? details.destination.name
    }
}

public extension Trip {
    // Mock trips
    static var mockList: [Trip] {
        [
            Trip(
                details: Details(
                    destination: Place(name: "Barcelona, Spain"),
                    members: Details.Members(groupType: .couple),
                    duration: 3,
                    month: .may
                ),
                itinerary: Itinerary.mock,
                suggestions: Suggestions.mock
            ),
            Trip(
                details: Details(
                    destination: Place(name: "Athens, Greece"),
                    members: Details.Members(groupType: .couple),
                    duration: 3,
                    month: .may
                ),
                itinerary: Itinerary(
                    name: "Athens Adventure",
                    destination: "Athens, Greece",
                    title: "Athens Itinerary: Explore the Ancient City",
                    segments: [
                        .mock,
                        .mock2
                    ]
                ),
                suggestions: Suggestions.mock
            )
        ]
    }
}
