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
    
    public init(
        details: Details,
        itinerary: Itinerary,
        suggestions: Suggestions?,
        favorites: Favorites = .init()
    ) {
        self.details     = details
        self.itinerary   = itinerary
        self.suggestions = suggestions
        self.favorites   = favorites
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
