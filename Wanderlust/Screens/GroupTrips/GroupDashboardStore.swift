import Combine
import CoreArchitecture
import Foundation

/// Drives the live group dashboard. Subscribes to Convex `getGroup` so the
/// roster/status update in real time as members finish, and issues the admin
/// controls (add / remove / generate / retry).
@MainActor
final class GroupDashboardStore: ObservableStore {
    @Published var state: State
    private let service: GroupTripService
    private let credentials: GroupTripCredentials?
    private var cancellable: AnyCancellable?
    private var previousGroupStatus: GroupStatus?

    init(groupId: String, service: GroupTripService = .shared) {
        self.service = service
        self.credentials = GroupTripCredentialsStore.load(groupId: groupId)
        self.state = State(groupId: groupId)
        subscribe()
    }

    private func subscribe() {
        guard let credentials else {
            state.group = .error(GroupDashboardError.noCredentials)
            return
        }
        cancellable = service
            .observeGroup(groupId: credentials.groupId, memberToken: credentials.memberToken)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case let .failure(error) = completion {
                        self?.state.group = .error(error)
                    }
                },
                receiveValue: { [weak self] dto in
                    self?.logStatusChange(dto)
                    self?.state.group = .loaded(dto)
                }
            )
    }

    func send(_ action: Action) {
        guard let credentials, let adminToken = credentials.adminToken else { return }
        switch action {
        case .generate:
            logGenerationRequested(action: "generate")
            runAdmin { try await self.service.forceGenerate(groupId: credentials.groupId, adminToken: adminToken) }
        case .retry:
            logGenerationRequested(action: "retry")
            runAdmin { try await self.service.retryGeneration(groupId: credentials.groupId, adminToken: adminToken) }
        case let .removeMember(memberId):
            runAdmin { try await self.service.removeMember(groupId: credentials.groupId, adminToken: adminToken, memberId: memberId) }
        case let .addMember(name):
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            runAdmin { _ = try await self.service.seedMember(groupId: credentials.groupId, adminToken: adminToken, name: trimmed) }
        }
    }

    private func runAdmin(_ operation: @escaping () async throws -> Void) {
        state.actionError = nil
        Task { @MainActor in
            do {
                try await operation()
            } catch {
                state.actionError = "That didn't work. Check your connection and try again."
            }
        }
    }

    private func logGenerationRequested(action: String) {
        var properties: [String: AnalyticsValue] = [
            "action": .string(action)
        ]
        if case let .loaded(group) = state.group {
            properties["roster_count"] = .integer(group.memberCount)
            properties["completed_count"] = .integer(group.completedCount)
        }
        AnalyticsTracker.shared.log(
            .init(.groupGenerationRequested, properties: properties)
        )
    }

    private func logStatusChange(_ group: GroupDTO) {
        guard previousGroupStatus != group.status else { return }
        var properties: [String: AnalyticsValue] = [
            "previous_state": .string(previousGroupStatus?.rawValue ?? "unknown"),
            "state": .string(group.status.rawValue),
            "roster_count": .integer(group.memberCount),
            "completed_count": .integer(group.completedCount)
        ]
        if let errorCode = group.errorCode {
            properties["error_category"] = .string(
                AnalyticsSanitizer.errorCategory(
                    GroupAnalyticsError(code: errorCode)
                ).rawValue
            )
        }
        previousGroupStatus = group.status
        AnalyticsTracker.shared.log(
            .init(.groupGenerationStateObserved, properties: properties)
        )
    }
}

private struct GroupAnalyticsError: Error {
    let code: String
}

extension GroupDashboardStore {
    struct State: Equatable {
        let groupId: String
        var group: AsyncValue<GroupDTO> = .initial
        var actionError: String?
    }

    enum Action: Equatable {
        case generate
        case retry
        case removeMember(String)
        case addMember(String)
    }
}

enum GroupDashboardError: Error {
    case noCredentials
}
