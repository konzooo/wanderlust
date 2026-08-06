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

/// The model may return only client-issued candidate IDs and editorial prose.
/// There is no venue name, coordinate, distance, duration or map link field for
/// it to fill in.
struct NearYouSelectionPayload: Decodable, Equatable, Sendable {
    struct Section: Decodable, Equatable, Sendable {
        let title: String
        let picks: [Pick]
    }

    struct Pick: Decodable, Equatable, Sendable {
        let candidateID: UUID
        let explanation: String
    }

    let sections: [Section]
    let sparseMessage: String?

    /// Reattaches model choices to the original grounded values. Unknown IDs
    /// fail the whole focused component: silently dropping one would disguise a
    /// responsibility-boundary violation as an ordinary sparse result.
    func materialize(discovery: NearYouDiscovery) throws -> Trip.NearYou {
        let candidates = Dictionary(
            uniqueKeysWithValues: discovery.editorialCandidates.map { ($0.id, $0) }
        )
        var used = Set<UUID>()
        var groundedSections: [Trip.NearYouSection] = []

        for section in sections {
            var picks: [Trip.NearYouPick] = []
            for selection in section.picks {
                guard let candidate = candidates[selection.candidateID] else {
                    throw NearYouSelectionError.unknownCandidateID(selection.candidateID)
                }
                guard used.insert(selection.candidateID).inserted else { continue }
                picks.append(.init(candidate: candidate, explanation: selection.explanation))
            }
            if !picks.isEmpty {
                groundedSections.append(.init(title: section.title, picks: picks))
            }
        }

        return Trip.NearYou(
            sections: groundedSections,
            practical: discovery.practical,
            unavailablePracticalKinds: discovery.unavailablePracticalKinds,
            sparseMessage: sparseMessage
        )
    }
}

enum NearYouSelectionError: Error, Equatable {
    case unknownCandidateID(UUID)
}

protocol NearYouGenerating {
    func generate(
        _ request: TripGenerationRequest,
        candidates: [Trip.NearYouCandidate],
        alreadyRecommended: [String]
    ) async throws -> NearYouSelectionPayload
}

struct BackendNearYouService: NearYouGenerating {
    var service: TripGenerationService = .shared

    func generate(
        _ request: TripGenerationRequest,
        candidates: [Trip.NearYouCandidate],
        alreadyRecommended: [String]
    ) async throws -> NearYouSelectionPayload {
        try await service.generate(
            .nearYou,
            for: request,
            alreadyRecommended: alreadyRecommended,
            nearYouCandidates: candidates.map(NearYouBackendCandidate.init)
        )
    }
}

struct MockNearYouService: NearYouGenerating {
    var delayNanoseconds: UInt64 = 600_000_000

    func generate(
        _ request: TripGenerationRequest,
        candidates: [Trip.NearYouCandidate],
        alreadyRecommended: [String]
    ) async throws -> NearYouSelectionPayload {
        try? await Task.sleep(nanoseconds: delayNanoseconds)
        let picks = candidates.prefix(4).map {
            NearYouSelectionPayload.Pick(
                candidateID: $0.id,
                explanation: "A strong match for the way you like to travel."
            )
        }
        return NearYouSelectionPayload(
            sections: picks.isEmpty
                ? []
                : [.init(title: "A good first wander", picks: picks)],
            sparseMessage: candidates.count < 4
                ? "There are only a few genuinely useful places within reach here."
                : nil
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

/// Exact address input is structurally absent. It exists only in the transient
/// store action that asks MapKit to resolve a centre.
struct GroupNearYouActionPayload: Codable, Equatable, Sendable {
    let accommodation: GroupNearYouAccommodationInput
    let candidates: [GroupNearYouGroundedCandidate]
    let practical: [GroupNearYouPracticalInput]
    let unavailablePracticalKinds: [String]
    let replace: Bool

    init(accommodation: CoarseAccommodation, discovery: NearYouDiscovery, replace: Bool) {
        self.accommodation = GroupNearYouAccommodationInput(accommodation)
        candidates = discovery.editorialCandidates.map(GroupNearYouGroundedCandidate.init)
        practical = discovery.practical.map(GroupNearYouPracticalInput.init)
        unavailablePracticalKinds = discovery.unavailablePracticalKinds
            .map(\.rawValue)
            .sorted()
        self.replace = replace
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
    func generateGroupNearYou(
        groupId: String,
        memberToken: String,
        payload: GroupNearYouActionPayload
    ) async throws -> GroupNearYouResultDTO
}
