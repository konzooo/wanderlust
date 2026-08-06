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
    /// and the map URL remain client-owned from discovery through rendering.
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

    /// The complete, already-grounded result persisted with a solo trip.
    ///
    /// `sparseMessage` is allowed to be non-nil even when there are editorial
    /// sections: it is the honest note that the real candidate pool was thin.
    /// No placeholder candidates are ever added to make the layout look full.
    struct NearYou: Codable, Equatable, Hashable, Sendable {
        public let sections: [NearYouSection]
        public let practical: [NearYouPracticalPlace]
        public let unavailablePracticalKinds: Set<NearYouPracticalKind>
        public let sparseMessage: String?

        public init(
            sections: [NearYouSection],
            practical: [NearYouPracticalPlace],
            unavailablePracticalKinds: Set<NearYouPracticalKind> = [],
            sparseMessage: String? = nil
        ) {
            self.sections = sections
            self.practical = practical
            self.unavailablePracticalKinds = unavailablePracticalKinds
            self.sparseMessage = sparseMessage
        }

        public var editorialPicks: [NearYouPick] { sections.flatMap(\.picks) }
    }
}
