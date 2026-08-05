import Combine
import ConvexMobile
import CoreModels
import Foundation

enum ConvexConfiguration {
    /// Convex dev deployment. There is only one environment today; once a
    /// production deployment exists this should gate on the build configuration.
    static let deploymentURL = "https://affable-pika-176.convex.cloud"
}

/// Thin wrapper around the Convex client for the Group Trips backend.
///
/// Authorization is entirely capability-token based (see
/// `ConvexBackend/README.md`) — this service never sends a device ID. Tokens
/// are minted server-side and persisted by the caller via
/// `GroupTripCredentialsStore`.
final class GroupTripService {
    static let shared = GroupTripService()

    private let client: ConvexClient

    init(deploymentURL: String = ConvexConfiguration.deploymentURL) {
        client = ConvexClient(deploymentUrl: deploymentURL)
    }

    // MARK: - Create / seed (M1)

    struct CreatedGroup: Decodable, Equatable {
        let groupId: String
        let code: String
        let adminToken: String
    }

    func createGroup(
        name: String,
        destination: String,
        durationDays: Int,
        startMonth: String
    ) async throws -> CreatedGroup {
        // Convex `v.number()` is float64; Swift's native `Int` would encode as
        // Convex's int64 wire format, which the validator rejects. Send `Double`.
        let args: [String: ConvexEncodable?] = [
            "name": name,
            "destination": destination,
            "durationDays": Double(durationDays),
            "startMonth": startMonth
        ]
        return try await client.mutation("groups:createGroup", with: args)
    }

    /// The admin adds their own name (first action on the members screen),
    /// creating their claimed roster slot and returning their member token.
    func addAdminSelf(groupId: String, adminToken: String, name: String) async throws -> ClaimResult {
        try await client.mutation("groups:addAdminSelf", with: [
            "groupId": groupId,
            "adminToken": adminToken,
            "name": name
        ])
    }

    struct MemberIDResult: Decodable, Equatable {
        let memberId: String
    }

    /// Admin seeds a placeholder roster slot for a friend who hasn't joined yet.
    func seedMember(groupId: String, adminToken: String, name: String) async throws -> MemberIDResult {
        try await client.mutation("groups:seedMember", with: [
            "groupId": groupId,
            "adminToken": adminToken,
            "name": name
        ])
    }

    // MARK: - Dashboard (M4)

    /// Live dashboard subscription. Emits a fresh `GroupDTO` whenever the roster
    /// or status changes. Requires the viewer's member token.
    func observeGroup(groupId: String, memberToken: String) -> AnyPublisher<GroupDTO, ClientError> {
        client.subscribe(
            to: "groups:getGroup",
            with: ["groupId": groupId, "memberToken": memberToken],
            yielding: GroupDTO.self
        )
    }

    // MARK: - Join (M5)

    /// Live join-screen subscription; `nil` when the code resolves to no group.
    func observeJoin(code: String) -> AnyPublisher<JoinDTO?, ClientError> {
        client.subscribe(
            to: "groups:joinResolve",
            with: ["code": code],
            yielding: JoinDTO?.self
        )
    }

    struct ClaimResult: Decodable, Equatable {
        let memberId: String
        let memberToken: String
    }

    /// Joiner claims one of the admin's pre-seeded slots.
    func claimSlot(groupId: String, memberId: String) async throws -> ClaimResult {
        try await client.mutation("groups:claimSlot", with: [
            "groupId": groupId,
            "memberId": memberId
        ])
    }

    /// Joiner adds themselves as a brand-new claimed slot.
    func addSelf(groupId: String, name: String) async throws -> ClaimResult {
        try await client.mutation("groups:addSelf", with: [
            "groupId": groupId,
            "name": name
        ])
    }

    /// Admin removes a still-pending slot.
    func removeMember(groupId: String, adminToken: String, memberId: String) async throws {
        let _: ConvexAck = try await client.mutation("groups:removeMember", with: [
            "groupId": groupId,
            "adminToken": adminToken,
            "memberId": memberId
        ])
    }

    // MARK: - Submit preferences (M3)

    func submitPreferences(
        groupId: String,
        memberId: String,
        memberToken: String,
        preferences: MemberPreferences
    ) async throws {
        let _: ConvexAck = try await client.mutation("groups:submitPreferences", with: [
            "groupId": groupId,
            "memberId": memberId,
            "memberToken": memberToken,
            "preferences": preferences
        ])
    }

    // MARK: - Generation controls (M6)

    /// Admin "Generate now" — closes the group and generates with whoever's done.
    func forceGenerate(groupId: String, adminToken: String) async throws {
        let _: ConvexAck = try await client.mutation("generate:forceGenerate", with: [
            "groupId": groupId,
            "adminToken": adminToken
        ])
    }

    /// Admin retry after a failed generation.
    func retryGeneration(groupId: String, adminToken: String) async throws {
        let _: ConvexAck = try await client.mutation("generate:retryGeneration", with: [
            "groupId": groupId,
            "adminToken": adminToken
        ])
    }
}

/// Decodes any Convex mutation that returns an acknowledgement object (e.g.
/// `{ submitted: true }`). The library's no-result `mutation` overload decodes
/// into `String?`, which throws on an object return — using this empty struct
/// (which accepts any keyed object) instead is what fixes the false
/// "couldn't submit" errors on otherwise-successful writes.
private struct ConvexAck: Decodable {}

// MARK: - DTOs (mirror ConvexBackend/convex/lib/dto.ts)

/// Full dashboard shape. Counts are decoded via `Double` then exposed as `Int`
/// to avoid any float64-vs-int wire ambiguity from Convex.
struct GroupDTO: Decodable, Equatable {
    let groupId: String
    let code: String
    let name: String
    let destination: String
    let startMonth: String
    let status: GroupStatus
    let viewerIsAdmin: Bool
    let canAutoGenerate: Bool
    let members: [MemberDTO]
    let itinerary: Trip.Itinerary?
    let suggestions: Trip.Suggestions?
    let knowBeforeYouGo: Trip.KnowBeforeYouGo?
    /// What happened to each component, keyed by component name. A `nil`
    /// payload alone could not distinguish "not generated" from "failed", so
    /// there was nothing to offer a retry on.
    let componentStates: [String: GroupComponentStateDTO]
    /// Whether the server has anything left worth re-running.
    let canRetry: Bool
    let imageUrl: String?
    let errorCode: String?

    private let completedCountRaw: Double
    private let memberCountRaw: Double
    var completedCount: Int { Int(completedCountRaw) }
    var memberCount: Int { Int(memberCountRaw) }

    func state(of component: TripComponent) -> GroupComponentStateDTO {
        componentStates[component.rawValue] ?? .init(state: .absent, code: nil)
    }

    enum CodingKeys: String, CodingKey {
        case groupId, code, name, destination, startMonth, status
        case viewerIsAdmin, canAutoGenerate, members, itinerary, suggestions
        case knowBeforeYouGo, componentStates, canRetry, imageUrl, errorCode
        case completedCountRaw = "completedCount"
        case memberCountRaw = "memberCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupId = try container.decode(String.self, forKey: .groupId)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        destination = try container.decode(String.self, forKey: .destination)
        startMonth = try container.decode(String.self, forKey: .startMonth)
        status = try container.decode(GroupStatus.self, forKey: .status)
        viewerIsAdmin = try container.decode(Bool.self, forKey: .viewerIsAdmin)
        canAutoGenerate = try container.decode(Bool.self, forKey: .canAutoGenerate)
        members = try container.decode([MemberDTO].self, forKey: .members)
        itinerary = try? container.decodeIfPresent(Trip.Itinerary.self, forKey: .itinerary)
        suggestions = try? container.decodeIfPresent(Trip.Suggestions.self, forKey: .suggestions)
        knowBeforeYouGo = try? container.decodeIfPresent(
            Trip.KnowBeforeYouGo.self, forKey: .knowBeforeYouGo
        )
        // Tolerated rather than required: a client running against a backend
        // that predates per-component state should still show the trip.
        componentStates = (try? container.decodeIfPresent(
            [String: GroupComponentStateDTO].self, forKey: .componentStates
        )) ?? [:]
        canRetry = (try? container.decodeIfPresent(Bool.self, forKey: .canRetry)) ?? false
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        errorCode = try container.decodeIfPresent(String.self, forKey: .errorCode)
        completedCountRaw = try container.decode(Double.self, forKey: .completedCountRaw)
        memberCountRaw = try container.decode(Double.self, forKey: .memberCountRaw)
    }
}

/// Mirrors `ComponentStateDTO` in `ConvexBackend/convex/lib/dto.ts`.
struct GroupComponentStateDTO: Decodable, Equatable {
    enum Kind: String, Decodable {
        case absent, generating, failed, ready
    }

    let state: Kind
    /// Present only on `failed`.
    let code: String?

    var isReady: Bool { state == .ready }
    var isGenerating: Bool { state == .generating }
    var needsRetry: Bool { state == .failed || state == .absent }
}

enum GroupStatus: String, Decodable, Equatable {
    case collecting, generating, ready, error
}

struct MemberDTO: Decodable, Equatable, Identifiable {
    let memberId: String
    let name: String
    let role: String
    let status: MemberStatus
    let claimed: Bool
    let isYou: Bool

    var id: String { memberId }
    var isAdmin: Bool { role == "admin" }
}

enum MemberStatus: String, Decodable, Equatable {
    case pending, completed, skipped
}

/// Slimmer shape returned by `joinResolve` — names + claim availability only.
struct JoinDTO: Decodable, Equatable {
    let groupId: String
    let code: String
    let name: String
    let destination: String
    let status: GroupStatus
    let members: [JoinMemberDTO]
}

struct JoinMemberDTO: Decodable, Equatable, Identifiable {
    let memberId: String
    let name: String
    let status: MemberStatus
    let claimed: Bool

    var id: String { memberId }
}

// Lets `MemberPreferences` ride as a nested Convex mutation argument; the default
// `Encodable` path JSON-encodes it, so `questionnaireVersion` arrives as a plain
// number (matching `v.number()`) and choices as their lowercase raw values.
extension MemberPreferences: @retroactive ConvexEncodable {}
