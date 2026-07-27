//
//  TravelItinerary.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 2/27/25.
//

import Foundation
import class UIKit.NSMutableParagraphStyle
import class UIKit.UIFont

/// Top-level itinerary model
extension Trip {
    public struct Itinerary: Hashable, Codable, Equatable, Sendable {
        public let name: String
        public let destination: String?
        public let title: String?
        public let segments: [Segment]
        
        public init(name: String, destination: String, title: String, segments: [Segment]) {
            self.name = name
            self.destination = destination
            self.title = title
            self.segments = segments
        }
        
        public var attributedTitle: AttributedString {
            guard let title else { return AttributedString("")}
            var attributedString = AttributedString(title)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.minimumLineHeight = 25
            paragraphStyle.maximumLineHeight = 25
            
            attributedString.uiKit.paragraphStyle = paragraphStyle
            attributedString.uiKit.font = UIFont(name: "Kanit-Regular", size: 28) ?? UIFont.systemFont(ofSize: 28)
            return attributedString
        }
        
        
        public struct Segment: Codable, Equatable, Hashable, Sendable {
            public let title: String
            public let description: SubSegments
            public let secretTip: SecretTip?
            
            public init(title: String, description: SubSegments, secretTip: SecretTip?) {
                self.title = title
                self.description = description
                self.secretTip = secretTip
            }
            
            public enum CodingKeys: String, CodingKey {
                case title
                case description
                case secretTip = "secret_tip"
            }
            
            public struct SubSegments: Hashable, Codable, Equatable, Sendable {
                public let morning: [LocationLinkableText]?
                public let afternoon: [LocationLinkableText]?
                public let evening: [LocationLinkableText]?
                
                public init(morning: [LocationLinkableText]? = nil, afternoon: [LocationLinkableText]? = nil, evening: [LocationLinkableText]? = nil) {
                    self.morning = morning
                    self.afternoon = afternoon
                    self.evening = evening
                }
            }
        }
        
        // SecretTip is used both for decoding backend responses (which never include id)
        // and for local persistence (where id should be saved and restored). Thus, we implement
        // custom Codable logic to generate a new id if missing, but persist it if present.
        public struct SecretTip: Hashable, Codable, Equatable, LocationLinkable, Sendable {
            // id is always present locally, but may be missing from backend JSON
            public let id: UUID
            public let text: String
            public let locations: [Location]?

            // Standard initializer, allows setting id or generating a new one
            public init(text: String, locations: [Location]? = nil, id: UUID = UUID()) {
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
                self.locations = try container.decodeIfPresent([Location].self, forKey: .locations)
            }

            // Always encode id for local persistence
            public func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(id, forKey: .id)
                try container.encode(text, forKey: .text)
                try container.encodeIfPresent(locations, forKey: .locations)
            }
        }
        
        public struct Location: Hashable, Codable, Equatable, Sendable {
            public let linkSubstring: String
            /// Fully searchable name, city included ("Brunch & Cake, Barcelona") so a
            /// place without coordinates can still be found by name.
            public let placeName: String
            /// Nil whenever the model isn't confident about the exact spot — the link
            /// then falls back to a Maps search rather than pinning the wrong block.
            public let latitude: String?
            public let longitude: String?
            public let placeID: String?

            public init(linkSubstring: String, placeName: String, latitude: String? = nil, longitude: String? = nil, placeID: String? = nil) {
                self.linkSubstring = linkSubstring
                self.placeName = placeName
                self.latitude = latitude
                self.longitude = longitude
                self.placeID = placeID
            }
        }
    }
}

public extension Trip.Itinerary {
    static let mock: Self = .init(
        name: "Hidden Gems & Iconic Vibes",
        destination: "Barcelona, Spain",
        title: "Barcelona Itinerary: A biutiful expiriens",
        segments: [
            .mock,
            .mock2,
            .mock3
        ]
    )
}

public extension Trip.Itinerary.Segment {
    static let mock: Self = .init(
        title: "🏙️ Day 1: The Mediterranean Breeze",
        description: SubSegments(
            morning: [
                LocationLinkableText(text: "Take a leisurely walk or bike ride along Barceloneta Beach."),
                LocationLinkableText(text: "Grab a coffee at Surf House Barcelona.")
            ],
            afternoon: [
                LocationLinkableText(text: "Enjoy a casual seafood lunch at Can Majó."),
                LocationLinkableText(text: "Visit the lesser-known Parc del Poblenou.")
            ],
            evening: [
                LocationLinkableText(text: "Take a sunset sailboat tour from Port Olímpic."),
                LocationLinkableText(text: "Have dinner at a seaside restaurant, like Pez Vela.")
            ]
        ),
        secretTip: Trip.Itinerary.SecretTip(text: "End your night with a quiet drink at Dr. Stravinsky.")
    )

    static let mock2: Self = .init(
        title: "🎨 Day 2: Art & Soul of the City",
        description: SubSegments(
            morning: [
                LocationLinkableText(text: "Explore the colorful Park Güell."),
                LocationLinkableText(text: "Have breakfast at Granja Viader.")
            ],
            afternoon: [
                LocationLinkableText(text: "Visit the Picasso Museum."),
                LocationLinkableText(text: "Wander the El Born neighborhood.")
            ],
            evening: [
                LocationLinkableText(text: "Catch a flamenco show at Palau Dalmases."),
                LocationLinkableText(text: "Enjoy tapas at El Xampanyet.")
            ]
        ),
        secretTip: Trip.Itinerary.SecretTip(text: "Try the hot chocolate with churros at La Nena.")
    )

    static let mock3: Self = .init(
        title: "🌄 Day 3: Heights & Horizons",
        description: SubSegments(
            morning: [
                LocationLinkableText(text: "Take the cable car up to Montjuïc Castle."),
                LocationLinkableText(text: "Walk through the Botanical Gardens.")
            ],
            afternoon: [
                LocationLinkableText(text: "Tour the Joan Miró Foundation."),
                LocationLinkableText(text: "Lunch with a view at Terraza Martínez.")
            ],
            evening: [
                LocationLinkableText(text: "Watch the Magic Fountain show at Plaça d'Espanya."),
                LocationLinkableText(text: "End with cocktails at SkyBar in the Grand Hotel Central.")
            ]
        ),
        secretTip: Trip.Itinerary.SecretTip(text: "Check out the rooftop at MNAC for panoramic views.")
    )
}
