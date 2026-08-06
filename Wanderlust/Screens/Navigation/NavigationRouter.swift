import CoreModels
import SwiftUI
import DesignSystem

/// Centralized navigation router for the app. Only mutate the navigation path via these methods.
class NavigationRouter: ObservableObject {
    /// The navigation path for the app. Only mutate via router methods.
    @Published var path: [Destination] = []
    private(set) var groupJoinAnalyticsSource = "manual_code"

    /// Navigate to the home screen (root).
    func goToHome() {
        path.removeAll()
    }

    /// Navigate to the basic info screen.
    func goToBasicInfo(_ state: BasicInfoStore.State = .init(), resetStack: Bool = false) {
        guard path.last != .basicInfo(state) else {
            return
        }
        
        if resetStack {
            path.removeAll()
        }
        
        path.append(.basicInfo(state))
    }
    
    /// Navigate to the saved trips screen.
    func goToSavedTrips(resetStack: Bool = false) {
        guard path.last != .savedTrips else {
            return
        }
        
        if resetStack {
            path.removeAll()
        }
        
        path.append(.savedTrips)
    }

    /// Navigate to the questionnaire screen.
    func goToQuestionnaire(_ state: QuestionnaireStore.State = .init(), resetStack: Bool = false) {
        guard path.last != .questionnaire(state) else {
            return
        }
        
        if resetStack {
            path.removeAll()
            path.append(.basicInfo(.init()))
        }

        path.append(.questionnaire(state))
    }

    /// Navigate to the itinerary result screen. Requires a destination — either
    /// to generate against, or because content is already loaded for it.
    func goToItineraryResult(
        _ state: TripOutputStore.State = .init(details: .mock, mode: .newTrip),
        resetStack: Bool = false
    ) {
        precondition(!state.details.destination.name.isEmpty, "Destination must not be empty")
        if resetStack {
            path.removeAll()
            path.append(.savedTrips)
        }

        path.append(.itineraryResult(state))
    }

    /// Navigate to the group trip creation screen.
    func goToGroupCreate(resetStack: Bool = false) {
        guard path.last != .groupCreate else {
            return
        }

        if resetStack {
            path.removeAll()
        }

        path.append(.groupCreate)
    }

    /// Navigate to the group trip members screen.
    func goToGroupMembers(_ state: GroupTripMembersStore.State, resetStack: Bool = false) {
        if resetStack {
            path.removeAll()
        }

        path.append(.groupMembers(state))
    }

    /// Navigate to the group questionnaire (swipe) screen.
    func goToGroupSwipe(
        _ groupId: String,
        profileSelection: ProfileTripSelection = .useDefault,
        resetStack: Bool = false
    ) {
        if resetStack {
            path.removeAll()
        }
        path.append(.groupSwipe(groupId: groupId, profileSelection: profileSelection))
    }

    /// Navigate to the live group dashboard.
    func goToGroupDashboard(_ groupId: String, resetStack: Bool = false) {
        if resetStack {
            path.removeAll()
        }
        guard path.last != .groupDashboard(groupId: groupId) else { return }
        path.append(.groupDashboard(groupId: groupId))
    }

    /// Navigate to the read-only group trip output, built from a loaded group.
    func goToGroupOutput(_ group: GroupDTO) {
        guard let itinerary = group.itinerary else { return }
        let month = Month(rawValue: group.startMonth) ?? .january
        // No `generationRequest`: a group trip is generated server-side and
        // arrives complete, so this screen has nothing to ask the backend for.
        var state = TripOutputStore.State(
            details: Trip.Details(
                destination: Place(name: group.destination),
                members: Trip.Details.Members(groupType: .group),
                duration: 0,
                month: month
            ),
            mode: .groupTrip
        )
        state.groupId = group.groupId
        state.itineraryResponse = .loaded(itinerary)
        if let suggestions = group.suggestions {
            state.suggestionsResponse = .loaded(suggestions)
        }
        if let briefing = group.knowBeforeYouGo {
            state.knowBeforeYouGoResponse = .loaded(briefing)
        }
        if let imageUrl = group.imageUrl, let url = URL(string: imageUrl) {
            state.imageUrlResponse = .loaded(url)
        }
        path.append(.groupOutput(state))
    }

    /// Navigate to the join-a-group-trip screen for an invite code.
    func goToGroupJoin(
        code: String,
        resetStack: Bool = false,
        analyticsSource: String = "manual_code"
    ) {
        groupJoinAnalyticsSource = analyticsSource
        if resetStack {
            path.removeAll()
        }
        path.append(.groupJoin(code: code))
    }

    /// Navigate to a trip shared via a share link.
    func goToSharedTrip(code: String, resetStack: Bool = false) {
        if resetStack {
            path.removeAll()
        }
        guard path.last != .sharedTrip(code: code) else { return }
        path.append(.sharedTrip(code: code))
    }

    /// Navigate to the feedback screen.
    func goToFeedback() {
        guard path.last != .feedback else {
            return
        }
        path.append(.feedback)
    }

    func goToProfiles() {
        guard path.last != .profiles else { return }
        path.append(.profiles)
    }

    /// Navigate to an unknown or deprecated destination (for deep linking or migration).
    func goToUnknown(_ message: String? = nil) {
        path.append(.unknown(message))
    }

    /// Navigate to the internal debug menu.
    func goToDebugMenu() {
        guard path.last != .debugMenu else { return }
        path.append(.debugMenu)
    }

    /// Pop the last screen from the navigation stack.
    func pop() {
        _ = path.popLast()
    }

    /// Pop to the root screen.
    func popToRoot() {
        path.removeAll()
    }

    /// Handle a deep link URL and navigate accordingly. Extend this for your deep link structure.
    ///
    /// Group invite links are `https://<domain>/join/<code>`. We validate the
    /// path shape and extract the 5-digit code, then route straight into the
    /// join screen. Anything else falls through to the existing handlers.
    func handleDeepLink(_ url: URL) {
        // Handle both the Universal Link form (https://<domain>/join/<code>) and
        // the dev custom-scheme form (wanderlust://join/<code>) by flattening the
        // host + path into segments and looking for "join" followed by a code.
        let segments = ([url.host] + url.pathComponents)
            .compactMap { $0 }
            .filter { $0 != "/" }
        if let joinIndex = segments.firstIndex(of: "join"), joinIndex + 1 < segments.count {
            let code = segments[joinIndex + 1].filter(\.isNumber)
            if !code.isEmpty {
                goToGroupJoin(
                    code: code,
                    resetStack: true,
                    analyticsSource: "deep_link"
                )
                return
            }
        }

        // Shared trip links are `/t/<32-hex>`. Unlike invite codes these are
        // NOT digits-only, so they need their own filter — `\.isNumber` would
        // mangle a hex code.
        if let tIndex = segments.firstIndex(of: "t"), tIndex + 1 < segments.count {
            let code = segments[tIndex + 1].filter { $0.isHexDigit }.lowercased()
            if code.count == 32 {
                goToSharedTrip(code: code, resetStack: true)
                return
            }
        }

        switch url.path {
        case "/feedback":
            goToFeedback()
        default:
            goToUnknown("Unknown deep link: \(url.absoluteString)")
        }
    }
}

extension NavigationRouter: DrawerNavigating {
    /// Process a DrawerRow selection and perform the appropriate navigation.
    func processDrawerSelection(_ row: DrawerRow) {
        switch row {
        case .home:
            goToHome()
        case .savedTrips:
            goToSavedTrips()
        case .profiles:
            goToProfiles()
        case .newTrip:
            goToBasicInfo(resetStack: true)
        case .groupTrip:
            goToGroupCreate(resetStack: true)
        case .feedback:
            goToFeedback()
        case .none:
            break
        }
    }
}
