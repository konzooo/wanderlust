//
//  TripStay.swift
//  CoreModels
//
//  The where-to-stay guide: which neighbourhood to sleep in, for someone who
//  hasn't booked anything yet.
//

import Foundation

extension Trip {
    /// One neighbourhood in the where-to-stay guide (D10).
    ///
    /// Shaped like ``Trip/WorthItItem`` and for the same reason: three prose
    /// fields sharing a single item-level `locations` array, because the link
    /// substrings are matched against all of them and a per-field array would
    /// store the same places three times over.
    ///
    /// **Not heartable.** §9 lists the where-to-stay options as reference
    /// rather than as things a traveller would want a list of, so this type
    /// deliberately has no arm in ``Trip/favouriteCandidates``. The `id` here
    /// exists for stable rendering, not for a favourites key — but it is still
    /// persisted rather than regenerated on decode, because a `ForEach` whose
    /// identity changes on every reload animates as a full replacement.
    public struct StayArea: Codable, Equatable, Hashable, Sendable, Identifiable {
        public let id: UUID
        /// The neighbourhood, as both locals and booking sites name it.
        public let area: String
        /// What it is actually like to stay there.
        public let theCase: String
        /// Who it suits, in one short phrase.
        public let bestFor: String
        /// The honest trade-off. Every area has one.
        public let watchOut: String
        /// Places named anywhere in the three prose fields.
        public let locations: [Itinerary.Location]?

        public init(
            area: String,
            theCase: String,
            bestFor: String,
            watchOut: String,
            locations: [Itinerary.Location]? = nil,
            id: UUID = UUID()
        ) {
            self.id = id
            self.area = area
            self.theCase = theCase
            self.bestFor = bestFor
            self.watchOut = watchOut
            self.locations = locations
        }

        private enum CodingKeys: String, CodingKey {
            case id, area, theCase, bestFor, watchOut, locations
        }

        /// The backend never sends an `id`; a saved file always does.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            area = try container.decode(String.self, forKey: .area)
            theCase = try container.decode(String.self, forKey: .theCase)
            bestFor = try container.decode(String.self, forKey: .bestFor)
            watchOut = try container.decode(String.self, forKey: .watchOut)
            locations = try container.decodeIfPresent(
                [Itinerary.Location].self, forKey: .locations
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(area, forKey: .area)
            try container.encode(theCase, forKey: .theCase)
            try container.encode(bestFor, forKey: .bestFor)
            try container.encode(watchOut, forKey: .watchOut)
            try container.encodeIfPresent(locations, forKey: .locations)
        }

        /// One prose field, ready to render with its place links attached.
        public func linkable(_ field: Field) -> LocationLinkableText {
            LocationLinkableText(text: prose(field), locations: locations, id: id)
        }

        /// The neighbourhood's name, linkable.
        ///
        /// The area is named in the title and nowhere else — the prose describes
        /// it without repeating it. Before this, the §13 matrix measured link
        /// resolution in this section at exactly zero: every location entry
        /// pointed at a name that appeared in no rendered text.
        public var linkableTitle: LocationLinkableText {
            LocationLinkableText(text: area, locations: locations, id: id)
        }

        public enum Field: CaseIterable, Sendable {
            case theCase, bestFor, watchOut

            /// The eyebrow above the field. Chrome, not model output.
            public var label: String {
                switch self {
                case .theCase: "What it's like"
                case .bestFor: "Best for"
                case .watchOut: "Watch out"
                }
            }
        }

        private func prose(_ field: Field) -> String {
            switch field {
            case .theCase: theCase
            case .bestFor: bestFor
            case .watchOut: watchOut
            }
        }
    }
}

public extension Trip.StayArea {
    /// Five areas, the shape the guide arrives in. Content only.
    static let mockSet: [Trip.StayArea] = [
        .init(
            area: "El Born",
            theCase: "Medieval lanes that open onto a bar every fifty metres, and you can walk to the beach, the Gothic Quarter and Estació de França without a metro ticket.",
            bestFor: "A first visit where you want everything on foot",
            watchOut: "Narrow streets carry sound straight up. Ask for a room off the street or bring earplugs."
        ),
        .init(
            area: "Gràcia",
            theCase: "A village that got swallowed by the city and never quite noticed — squares full of people at tables, and prices that still make sense.",
            bestFor: "A slower second visit, or anyone who wants a neighbourhood over a sight",
            watchOut: "It is up the hill and away from the water. Twenty-five minutes on the metro to the beach."
        ),
        .init(
            area: "Eixample Dreta",
            theCase: "Wide blocks, Gaudí on the doorstep, and the flattest walking in the city. The grid means you are never lost.",
            bestFor: "Couples, and anyone who wants space and a lift in the building",
            watchOut: "Passeig de Gràcia is a shopping street first. The blocks nearest it are quiet in a slightly corporate way."
        ),
        .init(
            area: "Poble Sec",
            theCase: "Under Montjuïc, with Carrer Blai's tapas run at one end and the funicular at the other. Locals still outnumber visitors here.",
            bestFor: "Eating well on a budget",
            watchOut: "The blocks nearest Paral·lel are scruffier at night than the ones up the hill."
        ),
        .init(
            area: "Barceloneta",
            theCase: "You wake up two streets from the sand, and the old fishermen's blocks are genuinely lovely at seven in the morning.",
            bestFor: "A short trip that is mostly about the beach",
            watchOut: "In summer it is loud, crowded and priced for it, and it is a long walk back from anywhere else."
        )
    ]
}
