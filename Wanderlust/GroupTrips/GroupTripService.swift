import Combine
import ConvexMobile
import CoreArchitecture
import CoreModels
import Foundation

enum ConvexConfiguration {
    /// Which Convex deployment this build talks to.
    ///
    /// Gated on the build configuration rather than hand-edited, because the
    /// failure mode of a hand-edited URL is silent and expensive: a Release
    /// build accidentally left on dev ships every real traveller's group trip
    /// into a deployment that `npx convex dev` overwrites at will.
    ///
    /// The consequence to remember: **dev and prod are separate databases with
    /// separate environment variables.** A schema change, a new function, or a
    /// new API key added to dev does not exist in prod until `npx convex deploy`
    /// and `npx convex env set --prod` are run for it. Archiving a release
    /// without that is the one way this goes wrong.
    static let deploymentURL = {
        #if DEBUG
        "https://affable-pika-176.convex.cloud"   // dev:affable-pika-176
        #else
        "https://clean-bulldog-349.convex.cloud"  // prod:clean-bulldog-349
        #endif
    }()
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
        let startMonth: String
        private let durationDaysRaw: Double
        private let createdAtRaw: Double

        var durationDays: Int { Int(durationDaysRaw) }
        var createdAt: Date { Date(timeIntervalSince1970: createdAtRaw / 1_000) }

        private enum CodingKeys: String, CodingKey {
            case groupId, code, adminToken, startMonth
            case durationDaysRaw = "durationDays"
            case createdAtRaw = "createdAt"
        }
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
            "installToken": InstallIdentity.token(),
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

    /// Adds one organizer-triggered deep dive to shared group state.
    func generateGroupDeepDive(
        groupId: String,
        adminToken: String,
        interest: String
    ) async throws -> Trip.Suggestions.Category {
        do {
            return try await client.action("groupDeepDives:generate", with: [
                "groupId": groupId,
                "adminToken": adminToken,
                "interest": interest
            ])
        } catch let error as ClientError {
            throw TripGenerationService.mapped(error)
        }
    }

    /// Any member may set the one shared Near You result, in two steps: the
    /// model proposes here, the device verifies each place against MapKit, and
    /// `commitGroupNearYou` persists only what survived. Neither call carries a
    /// raw address — MapKit resolved that locally before either ran.
    func proposeGroupNearYou(
        groupId: String,
        memberToken: String,
        researchArea: String,
        replace: Bool
    ) async throws -> GroupNearYouProposalDTO {
        do {
            return try await client.action("groupNearYou:propose", with: [
                "groupId": groupId,
                "memberToken": memberToken,
                "researchArea": researchArea,
                "replace": replace
            ])
        } catch let error as ClientError {
            throw TripGenerationService.mapped(error)
        }
    }

    func commitGroupNearYou(
        groupId: String,
        memberToken: String,
        operationVersion: Int,
        previousSuccessfulCount: Int,
        accommodation: CoarseAccommodation,
        nearYou: Trip.NearYou
    ) async throws -> GroupNearYouResultDTO {
        do {
            return try await client.mutation("groupNearYou:commitVerified", with: [
                "groupId": groupId,
                "memberToken": memberToken,
                "operationVersion": Double(operationVersion),
                "previousSuccessfulCount": Double(previousSuccessfulCount),
                "accommodation": GroupNearYouAccommodationInput(accommodation),
                "nearYou": nearYou
            ])
        } catch let error as ClientError {
            throw TripGenerationService.mapped(error)
        }
    }

    /// Recent model calls with their computed cost. Debug reporting only —
    /// nothing in the product reads this.
    func recentCosts(limit: Int = 20) async throws -> [GenerationCostRow] {
        // ConvexMobile exposes subscriptions rather than one-shot queries, so
        // take the first emission and drop the subscription. Live updates would
        // be noise here: the panel reports calls that already happened.
        let publisher: AnyPublisher<[GenerationCostRow], ClientError> = client.subscribe(
            to: "costs:recent",
            with: ["limit": Double(limit)],
            yielding: [GenerationCostRow].self
        )
        for try await rows in publisher.values { return rows }
        return []
    }
}

/// One recorded model call, priced. DEBUG surface only.
struct GenerationCostRow: Decodable, Equatable, Identifiable, Sendable {
    var id: Double { createdAtRaw }
    let component: String
    let mode: String
    let model: String?
    let errorCode: String?
    private let inputTokensRaw: Double
    private let cachedInputTokensRaw: Double
    private let outputTokensRaw: Double
    private let durationMsRaw: Double
    private let webSearchCallsRaw: Double
    private let createdAtRaw: Double
    /// Nil where the row predates model recording or names an unpriced model.
    let costUSD: Double?

    var durationMs: Int { Int(durationMsRaw) }
    var inputTokens: Int { Int(inputTokensRaw) }
    var cachedInputTokens: Int { Int(cachedInputTokensRaw) }
    var outputTokens: Int { Int(outputTokensRaw) }
    var webSearchCalls: Int { Int(webSearchCallsRaw) }
    var createdAt: Date { Date(timeIntervalSince1970: createdAtRaw / 1_000) }

    private enum CodingKeys: String, CodingKey {
        case component, mode, model, errorCode, costUSD
        case inputTokensRaw = "inputTokens"
        case cachedInputTokensRaw = "cachedInputTokens"
        case outputTokensRaw = "outputTokens"
        case durationMsRaw = "durationMs"
        case webSearchCallsRaw = "webSearchCalls"
        case createdAtRaw = "createdAt"
    }
}

protocol GroupDeepDiveGenerating {
    func generateGroupDeepDive(
        groupId: String,
        adminToken: String,
        interest: String
    ) async throws -> Trip.Suggestions.Category
}

extension GroupTripService: GroupDeepDiveGenerating {}
extension GroupTripService: GroupNearYouGenerating {}

protocol GroupTripObserving {
    func observeGroup(groupId: String, memberToken: String) -> AnyPublisher<GroupDTO, ClientError>
}

extension GroupTripService: GroupTripObserving {}

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
    private let durationDaysRaw: Double
    var durationDays: Int { Int(durationDaysRaw) }
    let startMonth: String
    let status: GroupStatus
    let viewerIsAdmin: Bool
    let canAutoGenerate: Bool
    let members: [MemberDTO]
    let itinerary: Trip.Itinerary?
    let suggestions: Trip.Suggestions?
    let knowBeforeYouGo: Trip.KnowBeforeYouGo?
    let worthItItems: [Trip.WorthItItem]?
    let whereToStay: [Trip.StayArea]?
    let interestPrompts: [String]
    let deepDives: [Trip.Suggestions.Category]?
    let accommodation: CoarseAccommodation?
    let nearYou: Trip.NearYou?
    let nearYouSetBy: String?
    private let nearYouGenerationCountRaw: Double
    var nearYouGenerationCount: Int { Int(nearYouGenerationCountRaw) }
    let nearYouOperationState: GroupComponentStateDTO
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
        case durationDaysRaw = "durationDays"
        case viewerIsAdmin, canAutoGenerate, members, itinerary, suggestions
        case knowBeforeYouGo, worthItItems, whereToStay, interestPrompts, deepDives
        case accommodation, nearYou, nearYouSetBy, nearYouOperationState
        case nearYouGenerationCountRaw = "nearYouGenerationCount"
        case componentStates, canRetry, imageUrl, errorCode
        case completedCountRaw = "completedCount"
        case memberCountRaw = "memberCount"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        groupId = try container.decode(String.self, forKey: .groupId)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        destination = try container.decode(String.self, forKey: .destination)
        durationDaysRaw = (try? container.decode(Double.self, forKey: .durationDaysRaw)) ?? 0
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
        worthItItems = try? container.decodeIfPresent(
            [Trip.WorthItItem].self, forKey: .worthItItems
        )
        whereToStay = try? container.decodeIfPresent(
            [Trip.StayArea].self, forKey: .whereToStay
        )
        interestPrompts = (try? container.decodeIfPresent(
            [String].self, forKey: .interestPrompts
        )) ?? []
        deepDives = try? container.decodeIfPresent(
            [Trip.Suggestions.Category].self, forKey: .deepDives
        )
        accommodation = try? container.decodeIfPresent(
            CoarseAccommodation.self, forKey: .accommodation
        )
        nearYou = try? container.decodeIfPresent(Trip.NearYou.self, forKey: .nearYou)
        nearYouSetBy = try container.decodeIfPresent(String.self, forKey: .nearYouSetBy)
        nearYouGenerationCountRaw = (try? container.decodeIfPresent(
            Double.self, forKey: .nearYouGenerationCountRaw
        )) ?? (nearYou == nil ? 0 : 1)
        nearYouOperationState = (try? container.decodeIfPresent(
            GroupComponentStateDTO.self, forKey: .nearYouOperationState
        )) ?? .init(state: nearYou == nil ? .absent : .ready, code: nil)
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
struct GroupComponentStateDTO: Decodable, Equatable, Hashable {
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
    let startMonth: String
    private let durationDaysRaw: Double
    private let createdAtRaw: Double
    let status: GroupStatus
    let members: [JoinMemberDTO]

    var durationDays: Int { Int(durationDaysRaw) }
    var createdAt: Date { Date(timeIntervalSince1970: createdAtRaw / 1_000) }

    private enum CodingKeys: String, CodingKey {
        case groupId, code, name, destination, startMonth, status, members
        case durationDaysRaw = "durationDays"
        case createdAtRaw = "createdAt"
    }
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
