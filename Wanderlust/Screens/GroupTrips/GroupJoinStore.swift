import Combine
import CoreArchitecture
import Foundation

/// Drives the join screen: resolves an invite code to its roster (live), lets
/// the joiner claim an existing name or add themselves, then binds their new
/// capability token and hands off to the swipe flow.
@MainActor
final class GroupJoinStore: ObservableStore {
    @Published var state: State
    private let service: GroupTripService
    private var cancellable: AnyCancellable?
    private var analyticsSource = "manual_code"

    init(code: String, service: GroupTripService = .shared) {
        self.service = service
        self.state = State(code: code)
        subscribe(code: code)
    }

    func setAnalyticsSource(_ source: String) {
        analyticsSource = source == "deep_link" ? "deep_link" : "manual_code"
    }

    private func subscribe(code: String) {
        cancellable = service.observeJoin(code: code)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        self?.state.resolved = .error(GroupJoinError.lookupFailed)
                    }
                },
                receiveValue: { [weak self] dto in
                    guard let dto else {
                        self?.state.resolved = .error(GroupJoinError.notFound)
                        return
                    }
                    self?.state.resolved = .loaded(dto)
                }
            )
    }

    func send(_ action: Action) {
        switch action {
        case let .selectExisting(memberId):
            state.selection = .existing(memberId)
        case .startAddYourself:
            state.selection = .new
        case let .updateNewName(name):
            state.newName = name
        case .join:
            join()
        }
    }

    private func join() {
        guard case let .loaded(dto) = state.resolved, !state.isJoining else { return }
        state.isJoining = true
        state.errorMessage = nil
        let method = state.selection.analyticsName
        AnalyticsTracker.shared.log(
            .init(.groupJoinStarted, properties: [
                "source": .string(analyticsSource),
                "method": .string(method)
            ])
        )

        Task { @MainActor in
            do {
                let result: GroupTripService.ClaimResult
                switch state.selection {
                case let .existing(memberId):
                    result = try await service.claimSlot(groupId: dto.groupId, memberId: memberId)
                case .new:
                    let name = state.newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { state.isJoining = false; return }
                    result = try await service.addSelf(groupId: dto.groupId, name: name)
                case .none:
                    state.isJoining = false
                    return
                }

                GroupTripCredentialsStore.save(
                    GroupTripCredentials(
                        groupId: dto.groupId,
                        code: dto.code,
                        memberId: result.memberId,
                        memberToken: result.memberToken,
                        adminToken: nil
                    )
                )
                GroupTripCredentialsStore.upsertSummary(
                    GroupTripSummary(
                        groupId: dto.groupId,
                        name: dto.name,
                        destination: dto.destination,
                        code: dto.code
                    )
                )
                state.isJoining = false
                state.joinedGroupId = dto.groupId
                AnalyticsTracker.shared.log(
                    .outcome(
                        .groupJoinSucceeded,
                        outcome: "success",
                        properties: [
                            "source": .string(analyticsSource),
                            "method": .string(method)
                        ]
                    )
                )
            } catch {
                state.isJoining = false
                state.errorMessage = friendlyMessage(for: error)
                AnalyticsTracker.shared.log(
                    .outcome(
                        .groupJoinFailed,
                        outcome: "failure",
                        error: error,
                        properties: [
                            "source": .string(analyticsSource),
                            "method": .string(method)
                        ]
                    )
                )
            }
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let text = "\(error)"
        if text.contains("already taken") {
            return "Someone just took that name. Pick another or add yourself."
        }
        if text.contains("closed") {
            return "This trip has already started and can't be joined."
        }
        return "Couldn't join. Check your connection and try again."
    }
}

extension GroupJoinStore {
    struct State: Equatable {
        let code: String
        var resolved: AsyncValue<JoinDTO> = .initial
        var selection: Selection = .none
        var newName: String = ""
        var isJoining: Bool = false
        var errorMessage: String?
        /// Set on success; the screen observes this to navigate into swiping.
        var joinedGroupId: String?

        var canJoin: Bool {
            guard case let .loaded(dto) = resolved, dto.status == .collecting else { return false }
            switch selection {
            case .existing:
                return true
            case .new:
                return !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .none:
                return false
            }
        }
    }

    enum Selection: Equatable {
        case none
        case existing(String)
        case new

        var analyticsName: String {
            switch self {
            case .existing: "existing_slot"
            case .new: "new_member"
            case .none: "none"
            }
        }
    }

    enum Action: Equatable {
        case selectExisting(String)
        case startAddYourself
        case updateNewName(String)
        case join
    }
}

enum GroupJoinError: Error {
    case notFound
    case lookupFailed
}
