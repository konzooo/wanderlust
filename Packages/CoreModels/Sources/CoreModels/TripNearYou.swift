//
//  TripNearYou.swift
//  CoreModels
//
//  Grounded, personal recommendations around a traveller's coarse stay.
//

import Foundation

public extension Trip {
    /// One real place discovered and routed by MapKit before the model is called.
    ///
    /// The model never creates this value. It receives a privacy-minimised copy
    /// containing only `id`, `name`, `category`, `distanceMetres` and
    /// `walkingMinutes`, and may return only the `id`. Coordinates, route facts
    /// and the map URL remain MapKit-owned. A shared group result persists those
    /// client facts on the server so every member renders the same grounding,
    /// but they are still never passed to the model.
    struct NearYouCandidate: Codable, Equatable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let category: String
        public let latitude: Double
        public let longitude: Double
        public let distanceMetres: Int
        public let walkingMinutes: Int
        public let mapURL: URL

        public init(
            id: UUID,
            name: String,
            category: String,
            latitude: Double,
            longitude: Double,
            distanceMetres: Int,
            walkingMinutes: Int,
            mapURL: URL
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.latitude = latitude
            self.longitude = longitude
            self.distanceMetres = max(0, distanceMetres)
            self.walkingMinutes = max(1, walkingMinutes)
            self.mapURL = mapURL
        }

        /// The favourite row carries the grounded place and coordinates. Its id
        /// is the candidate id minted during discovery and persisted unchanged.
        public func favouriteText(explanation: String) -> LocationLinkableText {
            LocationLinkableText(
                text: "\(name) — \(explanation)",
                locations: [
                    Itinerary.Location(
                        linkSubstring: name,
                        placeName: name,
                        latitude: String(latitude),
                        longitude: String(longitude),
                        placeID: nil
                    )
                ],
                id: id
            )
        }
    }

    /// A model-selected candidate plus preference-aware editorial explanation.
    /// The venue and every practical fact still come from `candidate`.
    struct NearYouPick: Codable, Equatable, Hashable, Sendable, Identifiable {
        public var id: UUID { candidate.id }
        public let candidate: NearYouCandidate
        public let explanation: String

        public init(candidate: NearYouCandidate, explanation: String) {
            self.candidate = candidate
            self.explanation = explanation
        }
    }

    /// An adaptive editorial group. Titles and order come from the model; the
    /// places inside it must all resolve to supplied candidates on the client.
    struct NearYouSection: Codable, Equatable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public let title: String
        public let picks: [NearYouPick]

        public init(id: UUID = UUID(), title: String, picks: [NearYouPick]) {
            self.id = id
            self.title = title
            self.picks = picks
        }
    }

    /// A current web-sourced discovery outside the Apple Maps candidate pool.
    ///
    /// This is deliberately a different type from ``NearYouCandidate``: it has
    /// a visible source but no claimed walking distance or route. A temporary
    /// market that is absent from Maps can still be useful without pretending
    /// MapKit verified facts it did not provide.
    struct NearYouLiveFind: Codable, Equatable, Hashable, Sendable, Identifiable {
        public let id: UUID
        public let name: String
        public let category: String
        public let locationHint: String
        public let explanation: String
        public let accessNote: String?
        public let sourceTitle: String
        public let sourceURL: URL

        public init(
            id: UUID,
            name: String,
            category: String,
            locationHint: String,
            explanation: String,
            accessNote: String? = nil,
            sourceTitle: String,
            sourceURL: URL
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.locationHint = locationHint
            self.explanation = explanation
            self.accessNote = accessNote
            self.sourceTitle = sourceTitle
            self.sourceURL = sourceURL
        }

        public var favouriteText: LocationLinkableText {
            LocationLinkableText(
                text: "\(name) — \(explanation)",
                locations: [
                    Itinerary.Location(
                        linkSubstring: name,
                        placeName: "\(name), \(locationHint)",
                        latitude: nil,
                        longitude: nil,
                        placeID: nil
                    )
                ],
                id: id
            )
        }
    }

    /// Model-free reference categories rendered apart from editorial picks.
    enum NearYouPracticalKind: String, Codable, Equatable, Hashable, Sendable, CaseIterable {
        case transport
        case grocery
        case pharmacy

        public var title: String {
            switch self {
            case .transport: "Transport"
            case .grocery: "Grocery"
            case .pharmacy: "Pharmacy"
            }
        }
    }

    struct NearYouPracticalPlace: Codable, Equatable, Hashable, Sendable, Identifiable {
        public var id: String { kind.rawValue }
        public let kind: NearYouPracticalKind
        public let candidate: NearYouCandidate

        public init(kind: NearYouPracticalKind, candidate: NearYouCandidate) {
            self.kind = kind
            self.candidate = candidate
        }
    }

    /// The complete, already-grounded result persisted with a solo or group trip.
    ///
    /// `sparseMessage` is allowed to be non-nil even when there are editorial
    /// sections: it is the honest note that the real candidate pool was thin.
    /// No placeholder candidates are ever added to make the layout look full.
    struct NearYou: Codable, Equatable, Hashable, Sendable {
        public let sections: [NearYouSection]
        public let liveFinds: [NearYouLiveFind]
        public let practical: [NearYouPracticalPlace]
        public let unavailablePracticalKinds: Set<NearYouPracticalKind>
        public let sparseMessage: String?

        public init(
            sections: [NearYouSection],
            liveFinds: [NearYouLiveFind] = [],
            practical: [NearYouPracticalPlace],
            unavailablePracticalKinds: Set<NearYouPracticalKind> = [],
            sparseMessage: String? = nil
        ) {
            self.sections = sections
            self.liveFinds = liveFinds
            self.practical = practical
            self.unavailablePracticalKinds = unavailablePracticalKinds
            self.sparseMessage = sparseMessage
        }

        public var editorialPicks: [NearYouPick] { sections.flatMap(\.picks) }

        private enum CodingKeys: String, CodingKey {
            case sections, liveFinds, practical, unavailablePracticalKinds, sparseMessage
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            sections = try container.decode([NearYouSection].self, forKey: .sections)
            liveFinds = try container.decodeIfPresent(
                [NearYouLiveFind].self, forKey: .liveFinds
            ) ?? []
            practical = try container.decode(
                [NearYouPracticalPlace].self, forKey: .practical
            )
            unavailablePracticalKinds = try container.decodeIfPresent(
                Set<NearYouPracticalKind>.self, forKey: .unavailablePracticalKinds
            ) ?? []
            sparseMessage = try container.decodeIfPresent(
                String.self, forKey: .sparseMessage
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(sections, forKey: .sections)
            try container.encode(liveFinds, forKey: .liveFinds)
            try container.encode(practical, forKey: .practical)
            try container.encode(unavailablePracticalKinds, forKey: .unavailablePracticalKinds)
            try container.encodeIfPresent(sparseMessage, forKey: .sparseMessage)
        }
    }
}
