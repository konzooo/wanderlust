import CoreArchitecture
import Foundation

class GroupTripMembersStore: ObservableStore {
    @Published var state: State
    private let service: GroupTripService

    init(initialState: State, service: GroupTripService = .shared) {
        self.state = initialState
        self.service = service
    }

    func send(_ action: Action) {
        switch action {
        case .addMember:
            let name = state.newMemberName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !state.isAddingMember else { return }
            state.isAddingMember = true
            state.errorMessage = nil

            if state.hasAddedSelf {
                addOther(name: name)
            } else {
                addSelf(name: name)
            }
        }
    }

    /// The admin's first entry is their own name: creates their admin slot,
    /// mints their member token, and persists credentials so they can swipe.
    private func addSelf(name: String) {
        Task { @MainActor in
            do {
                let result = try await service.addAdminSelf(
                    groupId: state.groupId,
                    adminToken: state.adminToken,
                    name: name
                )
                GroupTripCredentialsStore.save(
                    GroupTripCredentials(
                        groupId: state.groupId,
                        code: state.code,
                        memberId: result.memberId,
                        memberToken: result.memberToken,
                        adminToken: state.adminToken
                    )
                )
                GroupTripCredentialsStore.upsertSummary(
                    GroupTripSummary(
                        groupId: state.groupId,
                        name: state.groupName,
                        destination: state.destination,
                        code: state.code
                    )
                )
                state.members.append(GroupTripMemberRow(memberId: result.memberId, name: name, isAdmin: true))
                state.newMemberName = ""
                state.isAddingMember = false
            } catch {
                state.isAddingMember = false
                state.errorMessage = "Couldn't add your name. Check your connection and try again."
            }
        }
    }

    private func addOther(name: String) {
        Task { @MainActor in
            do {
                let seeded = try await service.seedMember(
                    groupId: state.groupId,
                    adminToken: state.adminToken,
                    name: name
                )
                state.members.append(GroupTripMemberRow(memberId: seeded.memberId, name: name, isAdmin: false))
                state.newMemberName = ""
                state.isAddingMember = false
            } catch {
                state.isAddingMember = false
                state.errorMessage = "Couldn't add \(name). Check your connection and try again."
            }
        }
    }
}

/// One roster slot. Every member shows as pending until the live dashboard
/// subscription takes over.
struct GroupTripMemberRow: Hashable, Equatable, Identifiable {
    let memberId: String
    let name: String
    let isAdmin: Bool

    var id: String { memberId }
}

extension GroupTripMembersStore {
    struct State: Hashable, Equatable, KeyPathMutable {
        let groupId: String
        let code: String
        let groupName: String
        let destination: String
        let adminToken: String
        let selectedProfileID: UUID?
        var members: [GroupTripMemberRow] = []
        var newMemberName: String = ""
        var isAddingMember: Bool = false
        var errorMessage: String?

        /// True once the admin has entered their own name (an admin slot exists).
        var hasAddedSelf: Bool { members.contains { $0.isAdmin } }

        var shareLink: String {
            "https://wanderlust.get-catalyst.app/join/\(code)"
        }
    }

    enum Action: Equatable {
        case addMember
    }
}
