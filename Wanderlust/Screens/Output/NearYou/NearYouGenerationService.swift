//
//  NearYouGenerationService.swift
//  Wanderlust
//
//  Privacy-minimised backend contract and client-side candidate validation.
//

import ConvexMobile
import CoreModels
import Foundation

/// The complete candidate shape allowed to leave the device.
///
/// Deliberately absent: accommodation input/label, centre coordinates, venue
/// coordinates and map links. A regression test JSON-encodes this contract and
/// guards that boundary.
struct NearYouBackendCandidate: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let category: String
    let distanceMetres: Int
    let walkingMinutes: Int

    init(candidate: Trip.NearYouCandidate) {
        id = candidate.id
        name = candidate.name
        category = candidate.category
        distanceMetres = candidate.distanceMetres
        walkingMinutes = candidate.walkingMinutes
    }
}

extension NearYouBackendCandidate: ConvexEncodable {}

/// Privacy-safe location context for model-led live discovery.
/// The exact address and centre coordinate are structurally absent.
struct NearYouLocationContext: Codable, Equatable, Sendable {
    let area: String
    let city: String
}

extension NearYouLocationContext: ConvexEncodable {}

/// What the model returns now: named places it believes are near the traveller,
/// each with the hint the device needs to find it on a map.
///
/// Nothing here is trusted. `materialize` is deliberately absent — a payload
/// cannot become a `Trip.NearYou` on its own, because every place must first
/// survive ``NearYouMapServicing/resolve(proposals:around:)``.
struct NearYouProposalPayload: Decodable, Equatable, Sendable {
    struct Place: Decodable, Equatable, Sendable {
        let name: String
        let category: String
        let locationHint: String
        let explanation: String
        let accessNote: String?
    }

    let places: [Place]
    let sparseMessage: String?

    init(places: [Place], sparseMessage: String? = nil) {
        self.places = places
        self.sparseMessage = sparseMessage
    }

    private enum CodingKeys: String, CodingKey {
        case places, sparseMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        places = try container.decodeIfPresent([Place].self, forKey: .places) ?? []
        sparseMessage = try container.decodeIfPresent(String.self, forKey: .sparseMessage)
    }

    var proposals: [NearYouProposal] {
        places.map {
            NearYouProposal(
                name: $0.name,
                category: $0.category,
                locationHint: $0.locationHint,
                explanation: $0.explanation,
                accessNote: $0.accessNote
            )
        }
    }
}

protocol NearYouGenerating {
    /// No candidates are sent any more: supplying them would anchor the model
    /// to the same narrow category sweep the redesign exists to escape.
    func generate(
        _ request: TripGenerationRequest,
        location: NearYouLocationContext,
        alreadyRecommended: [String]
    ) async throws -> NearYouProposalPayload
}

struct BackendNearYouService: NearYouGenerating {
    var service: TripGenerationService = .shared

    func generate(
        _ request: TripGenerationRequest,
        location: NearYouLocationContext,
        alreadyRecommended: [String]
    ) async throws -> NearYouProposalPayload {
        try await service.generate(
            .nearYou,
            for: request,
            alreadyRecommended: alreadyRecommended,
            nearYouCandidates: nil,
            nearYouLocation: location
        )
    }
}

struct MockNearYouService: NearYouGenerating {
    var delayNanoseconds: UInt64 = 600_000_000

    func generate(
        _ request: TripGenerationRequest,
        location: NearYouLocationContext,
        alreadyRecommended: [String]
    ) async throws -> NearYouProposalPayload {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        return NearYouProposalPayload(
            places: [
                .init(
                    name: "Mercat de la Concepció",
                    category: "Market",
                    locationHint: "Carrer d'Aragó 313",
                    explanation: "The flower stalls are the reason to come early.",
                    accessNote: "Liveliest on Saturday mornings."
                ),
                .init(
                    name: "Federal Café",
                    category: "Café",
                    locationHint: "Carrer del Parlament 39",
                    explanation: "Comfortable to sit alone with a book for an hour.",
                    accessNote: nil
                )
            ]
        )
    }
}

enum NearYouServices {
    static func map() -> any NearYouMapServicing { MapKitNearYouService() }

    static func generation() -> any NearYouGenerating {
        DebugSettings.useMockTripData ? MockNearYouService() : BackendNearYouService()
    }
}

// MARK: - Shared group Near You

/// Full MapKit-owned venue facts sent for server persistence. The backend
/// strips this to `NearYouBackendCandidate` before composing the model prompt.
struct GroupNearYouGroundedCandidate: Codable, Equatable, Sendable {
    let id: UUID
    let name: String
    let category: String
    let latitude: Double
    let longitude: Double
    let distanceMetres: Int
    let walkingMinutes: Int
    let mapURL: String

    init(_ candidate: Trip.NearYouCandidate) {
        id = candidate.id
        name = candidate.name
        category = candidate.category
        latitude = candidate.latitude
        longitude = candidate.longitude
        distanceMetres = candidate.distanceMetres
        walkingMinutes = candidate.walkingMinutes
        mapURL = candidate.mapURL.absoluteString
    }
}

extension GroupNearYouGroundedCandidate: ConvexEncodable {}

struct GroupNearYouPracticalInput: Codable, Equatable, Sendable {
    let kind: String
    let candidate: GroupNearYouGroundedCandidate

    init(_ value: Trip.NearYouPracticalPlace) {
        kind = value.kind.rawValue
        candidate = GroupNearYouGroundedCandidate(value.candidate)
    }
}

extension GroupNearYouPracticalInput: ConvexEncodable {}

struct GroupNearYouAccommodationInput: Codable, Equatable, Sendable {
    let label: String
    let latitude: Double
    let longitude: Double
    let precision: String

    init(_ value: CoarseAccommodation) {
        label = value.label
        latitude = value.latitude
        longitude = value.longitude
        precision = value.precision.rawValue
    }
}

extension GroupNearYouAccommodationInput: ConvexEncodable {}

/// The verified result is sent back whole rather than re-flattened into wire
/// structs: it is already exactly the shape every member's client decodes, so
/// mirroring it here would only create a second definition to keep in step.
extension Trip.NearYou: @retroactive ConvexEncodable {}

/// What the group's proposal call returns before anything is verified.
///
/// It carries the operation bookkeeping straight back to `commitVerified`
/// untouched: the device is a courier for those numbers, and the backend
/// re-checks them so a stale second attempt cannot overwrite a fresher result.
struct GroupNearYouProposalDTO: Decodable, Equatable, Sendable {
    let places: [NearYouProposalPayload.Place]
    let sparseMessage: String?
    let setBy: String
    private let operationVersionRaw: Double
    private let previousSuccessfulCountRaw: Double
    var operationVersion: Int { Int(operationVersionRaw) }
    var previousSuccessfulCount: Int { Int(previousSuccessfulCountRaw) }

    var proposals: [NearYouProposal] {
        places.map {
            NearYouProposal(
                name: $0.name,
                category: $0.category,
                locationHint: $0.locationHint,
                explanation: $0.explanation,
                accessNote: $0.accessNote
            )
        }
    }

    private enum CodingKeys: String, CodingKey {
        case places, sparseMessage, setBy
        case operationVersionRaw = "operationVersion"
        case previousSuccessfulCountRaw = "previousSuccessfulCount"
    }
}

struct GroupNearYouResultDTO: Decodable, Equatable, Sendable {
    let accommodation: CoarseAccommodation
    let nearYou: Trip.NearYou
    let nearYouSetBy: String
    private let generationCountRaw: Double
    var generationCount: Int { Int(generationCountRaw) }

    init(
        accommodation: CoarseAccommodation,
        nearYou: Trip.NearYou,
        nearYouSetBy: String,
        generationCount: Int
    ) {
        self.accommodation = accommodation
        self.nearYou = nearYou
        self.nearYouSetBy = nearYouSetBy
        generationCountRaw = Double(generationCount)
    }

    private enum CodingKeys: String, CodingKey {
        case accommodation, nearYou, nearYouSetBy
        case generationCountRaw = "generationCount"
    }
}

protocol GroupNearYouGenerating {
    /// Ask the model for places. Reserves the group's Near You operation, so a
    /// caller that gets a payload back owes it either a commit or a timeout.
    func proposeGroupNearYou(
        groupId: String,
        memberToken: String,
        researchArea: String,
        replace: Bool
    ) async throws -> GroupNearYouProposalDTO

    /// Persist what MapKit actually confirmed, for every member to read.
    func commitGroupNearYou(
        groupId: String,
        memberToken: String,
        operationVersion: Int,
        previousSuccessfulCount: Int,
        accommodation: CoarseAccommodation,
        nearYou: Trip.NearYou
    ) async throws -> GroupNearYouResultDTO
}
