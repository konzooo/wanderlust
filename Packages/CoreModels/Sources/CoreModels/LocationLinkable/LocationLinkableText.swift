//
//  LocationLinkableText.swift
//  CoreModels
//
//  Created by Rodrigo Mato on 30/6/25.
//

import Foundation

// LocationLinkableText is used both for decoding backend responses (which never include id)
// and for local persistence (where id should be saved and restored). Thus, we implement
// custom Codable logic to generate a new id if missing, but persist it if present.
public struct LocationLinkableText: Hashable, Codable, Equatable, LocationLinkable, Sendable {
    // id is always present locally, but may be missing from backend JSON
    public var id: UUID
    public let text: String
    public let locations: [Trip.Itinerary.Location]?

    // Standard initializer, allows setting id or generating a new one
    public init(text: String, locations: [Trip.Itinerary.Location]? = nil, id: UUID = UUID()) {
        self.id = id
        self.text = text
        self.locations = locations
    }

    // CodingKeys includes id so it is encoded/decoded for local persistence
    private enum CodingKeys: String, CodingKey {
        case id
        case text
        case locations
    }

    // Custom decoder: if id is missing (e.g., from backend), generate a new one
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // If id is present (e.g., from file), use it; otherwise, generate a new UUID
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.text = try container.decode(String.self, forKey: .text)
        self.locations = try container.decodeIfPresent([Trip.Itinerary.Location].self, forKey: .locations)
    }

    // Always encode id for local persistence
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(locations, forKey: .locations)
    }
}
