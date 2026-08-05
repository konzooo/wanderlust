//
//  TripWorthIt.swift
//  CoreModels
//
//  The "worth it or skip" cards: the four things a traveller has already half
//  decided to do, argued both ways so they can decide properly.
//

import Foundation

extension Trip {
    /// One Worth-it/Skip card.
    ///
    /// Shape follows the plan's canonical strict-schema example verbatim —
    /// `place`, `theCase`, `theCatch`, `verdict` and a single item-level
    /// `locations` array. The prose fields are plain `String` **because** there
    /// is one `locations` array per card rather than one per sentence: the link
    /// substrings are matched against all three fields, so wrapping each of them
    /// in its own `LocationLinkableText` would mean storing the same locations
    /// three times and inventing three ids nothing needs.
    ///
    /// The id that does matter is this card's own. It is the unit the traveller
    /// hearts and decides on, so — exactly like ``LocationLinkableText`` — it is
    /// generated once and then persisted, never regenerated on decode. A
    /// decision keyed to an id that changed on reload would silently reset.
    public struct WorthItItem: Codable, Equatable, Hashable, Sendable, Identifiable {
        /// Stable across save/reopen. Keys both ``Trip/worthItDecisions`` and
        /// the favourites set.
        public let id: UUID
        /// The place or activity being weighed up.
        public let place: String
        /// Why it might genuinely be worth it.
        public let theCase: String
        /// The honest catch — queues, price, tourist tax on your afternoon.
        public let theCatch: String
        /// The friend's actual call.
        public let verdict: String
        /// Places named anywhere in the three prose fields.
        public let locations: [Itinerary.Location]?

        public init(
            place: String,
            theCase: String,
            theCatch: String,
            verdict: String,
            locations: [Itinerary.Location]? = nil,
            id: UUID = UUID()
        ) {
            self.id = id
            self.place = place
            self.theCase = theCase
            self.theCatch = theCatch
            self.verdict = verdict
            self.locations = locations
        }

        private enum CodingKeys: String, CodingKey {
            case id, place, theCase, theCatch, verdict, locations
        }

        /// The backend never sends an `id`; a saved file always does.
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
            place = try container.decode(String.self, forKey: .place)
            theCase = try container.decode(String.self, forKey: .theCase)
            theCatch = try container.decode(String.self, forKey: .theCatch)
            verdict = try container.decode(String.self, forKey: .verdict)
            locations = try container.decodeIfPresent(
                [Itinerary.Location].self, forKey: .locations
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(place, forKey: .place)
            try container.encode(theCase, forKey: .theCase)
            try container.encode(theCatch, forKey: .theCatch)
            try container.encode(verdict, forKey: .verdict)
            try container.encodeIfPresent(locations, forKey: .locations)
        }

        /// One prose field, ready to render with its place links attached.
        ///
        /// The locations are shared across the three fields; `linkedText` simply
        /// finds whichever substrings occur in this one.
        public func linkable(_ field: Field) -> LocationLinkableText {
            LocationLinkableText(text: prose(field), locations: locations, id: id)
        }

        public enum Field: CaseIterable, Sendable {
            case theCase, theCatch, verdict

            /// The eyebrow above the field. Chrome, not model output.
            public var label: String {
                switch self {
                case .theCase: "The case"
                case .theCatch: "The catch"
                case .verdict: "Verdict"
                }
            }
        }

        private func prose(_ field: Field) -> String {
            switch field {
            case .theCase: theCase
            case .theCatch: theCatch
            case .verdict: verdict
            }
        }

        /// How this card reads once it is in the favourites list, where there is
        /// no room for the full argument — the place, and the call that was made
        /// about it.
        public var favouriteText: LocationLinkableText {
            LocationLinkableText(
                text: "**\(place)** — \(verdict)",
                locations: locations,
                id: id
            )
        }
    }
}

public extension Trip.WorthItItem {
    /// Four cards, as the plan specifies. Content only — nothing generates these
    /// yet; the generation call is the next session's work.
    static let mockSet: [Trip.WorthItItem] = [
        .init(
            place: "Sagrada Família",
            theCase: "There is nothing else like the inside of it at midday, when the east windows throw blue and the west throw orange across the whole nave.",
            theCatch: "Tickets sell out weeks ahead and the queue outside is brutal in the sun. The plaza photo is free; the inside is not.",
            verdict: "Worth it — but book the earliest slot of the day, and go inside or don't bother."
        ),
        .init(
            place: "Park Güell",
            theCase: "The mosaic terrace is genuinely lovely, and the free park above it has the better view anyway.",
            theCatch: "The paid Monumental Zone is half an hour of content for a timed ticket and a long uphill walk.",
            verdict: "Half worth it. Walk up for the free part at sunset, skip the paid zone unless Gaudí is the reason you came."
        ),
        .init(
            place: "La Rambla",
            theCase: "You will end up walking it once, and the Boqueria side streets are worth the detour.",
            theCatch: "Every restaurant on it is a tourist trap, and it is the city's pickpocket capital by a distance.",
            verdict: "Walk it, eat nothing on it."
        ),
        .init(
            place: "Camp Nou tour",
            theCase: "Even if you don't follow football, the scale of the place lands in person.",
            theCatch: "Mid-renovation the tour is a fraction of what it was, for most of the old price.",
            verdict: "Skip it this year unless you're a Barça fan — a match ticket is the better spend."
        )
    ]
}
