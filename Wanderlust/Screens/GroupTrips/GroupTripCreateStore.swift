import CoreArchitecture
import CoreModels
import Foundation

@MainActor
class GroupTripCreateStore: ObservableStore {
    @Published var state: State
    private let service: GroupTripService

    init(initialState: State = .init(), service: GroupTripService = .shared) {
        state = initialState
        self.service = service
    }

    func send(_ action: Action) {
        switch action {
        case .createGroup:
            guard state.readyToCreate, !state.isCreating else { return }
            state.isCreating = true
            state.errorMessage = nil
            let properties: [String: AnalyticsValue] = [
                "duration_days": .integer(state.durationDays),
                "start_month": .string(state.month.rawValue.lowercased()),
                "has_profile": .boolean(state.selectedProfileID != nil),
                "profile_attachment_source": .string(
                    TravellerProfileLibrary.shared.analyticsAttachmentSource(
                        for: state.selectedProfileID
                    )
                )
            ]
            AnalyticsTracker.shared.log(
                .init(.groupTripCreationStarted, properties: properties)
            )

            Task { @MainActor in
                do {
                    // Credentials + summary are saved on the members screen once
                    // the admin enters their own name (addAdminSelf).
                    let created = try await service.createGroup(
                        name: state.groupName,
                        destination: state.destination,
                        durationDays: state.durationDays,
                        startMonth: state.month.rawValue
                    )
                    state.isCreating = false
                    state.createdGroup = created
                    AnalyticsTracker.shared.log(
                        .outcome(
                            .groupTripCreated,
                            outcome: "success",
                            properties: properties
                        )
                    )
                } catch {
                    state.isCreating = false
                    state.errorMessage = "Couldn't create the group. Check your connection and try again."
                    AnalyticsTracker.shared.log(
                        .outcome(
                            .groupTripCreationFailed,
                            outcome: "failure",
                            error: error,
                            properties: properties
                        )
                    )
                }
            }
        }
    }
}

extension GroupTripCreateStore {
    enum Segment: String, CaseIterable, Hashable {
        case create = "Create Trip"
        case join = "Join Trip"
    }

    struct State: Equatable {
        var segment: Segment = .create
        var groupName: String = ""
        var destination: String = ""
        var duration: Float = 3
        var month: Month = Self.currentMonth
        var isCreating: Bool = false
        var errorMessage: String?
        /// The invite code typed under the "Join Trip" segment.
        var joinCode: String = ""
        /// Set once creation succeeds; the screen observes this to navigate forward.
        var createdGroup: GroupTripService.CreatedGroup?
        var selectedProfileID: UUID?

        var readyToCreate: Bool {
            !groupName.isEmpty && !destination.isEmpty && duration > 0
        }

        /// Normalized invite code (digits only, up to 5). Ready when non-empty.
        var normalizedJoinCode: String {
            String(joinCode.filter(\.isNumber).prefix(5))
        }

        var readyToJoin: Bool { normalizedJoinCode.count == 5 }

        var durationDays: Int {
            Int(round(duration))
        }

        var durationText: String {
            let daysString = durationDays == 1 ? "day" : "days"
            return "\(durationDays) \(daysString)"
        }

        static var currentMonth: Month {
            let currentMonthIndex = Calendar.current.component(.month, from: Date()) - 1
            let monthIndex = max(0, min(currentMonthIndex, Month.all.count - 1))
            return Month.all[monthIndex]
        }
    }

    enum Action: Equatable {
        case createGroup
    }
}
