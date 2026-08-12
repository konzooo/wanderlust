import SwiftUI

private struct AppDestinationsModifier: ViewModifier {
    @EnvironmentObject private var feedbackStore: FeedbackStore

    func body(content: Content) -> some View {
        content.navigationDestination(for: Destination.self) { destination in
            destinationView(destination)
                .toolbar(destination.hidesTabBar ? .hidden : .visible, for: .tabBar)
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: Destination) -> some View {
        switch destination {
        case let .basicInfo(state):
            BasicInfoScreen(state: state)
        case .questionnaire:
            QuestionnaireScreen()
        case let .groupCreate(segment):
            GroupTripCreateScreen(
                store: GroupTripCreateStore(initialState: .init(segment: segment))
            )
        case let .groupMembers(state):
            GroupTripMembersScreen(store: GroupTripMembersStore(initialState: state))
        case let .groupSwipe(groupId, profileSelection):
            GroupSwipeScreen(groupId: groupId, initialProfileSelection: profileSelection)
        case let .groupDashboard(groupId):
            GroupDashboardScreen(groupId: groupId)
        case let .groupOutput(state):
            TripOutputScreen(initialState: state)
        case let .groupJoin(code):
            GroupJoinScreen(code: code)
        case let .sharedTrip(code):
            SharedTripScreen(code: code)
        case let .itineraryResult(state):
            TripOutputScreen(initialState: state)
        case .feedback:
            FeedbackScreen(store: feedbackStore)
        case .settings:
            SettingsScreen()
        case .debugMenu:
            DebugMenuScreen()
        case let .unknown(message):
            UnknownDestinationScreen(message: message)
        }
    }
}

extension View {
    func withAppDestinations() -> some View {
        modifier(AppDestinationsModifier())
    }
}
