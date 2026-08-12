import CoreModels
import Combine
import Foundation

/// Centralized navigation router. Only mutate tab paths through these methods.
@MainActor
final class NavigationRouter: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var homePath: [Destination] = []
    @Published var tripsPath: [Destination] = []
    @Published var profilePath: [Destination] = []

    private(set) var groupJoinAnalyticsSource = "manual_code"

    subscript(tab: AppTab) -> [Destination] {
        get {
            switch tab {
            case .home: homePath
            case .trips: tripsPath
            case .profile: profilePath
            }
        }
        set {
            switch tab {
            case .home: homePath = newValue
            case .trips: tripsPath = newValue
            case .profile: profilePath = newValue
            }
        }
    }

    /// Used only by the native TabView binding.
    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    func goToTabRoot(_ tab: AppTab) {
        self[tab] = []
        selectedTab = tab
    }

    func goToBasicInfo(
        _ state: BasicInfoStore.State = .init(),
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(to: .basicInfo(state), on: tab, resetStack: resetStack)
    }

    func goToQuestionnaire(on tab: AppTab? = nil) {
        go(to: .questionnaire, on: tab)
    }

    func goToItineraryResult(
        _ state: TripOutputStore.State = .init(details: .mock, mode: .newTrip),
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        precondition(!state.details.destination.name.isEmpty, "Destination must not be empty")
        go(to: .itineraryResult(state), on: tab, resetStack: resetStack, dedupe: false)
    }

    func goToGroupCreate(
        segment: GroupTripCreateStore.Segment = .create,
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(to: .groupCreate(segment), on: tab, resetStack: resetStack)
    }

    func goToGroupMembers(
        _ state: GroupTripMembersStore.State,
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(to: .groupMembers(state), on: tab, resetStack: resetStack, dedupe: false)
    }

    func goToGroupSwipe(
        _ groupId: String,
        profileSelection: ProfileTripSelection = .useDefault,
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(
            to: .groupSwipe(groupId: groupId, profileSelection: profileSelection),
            on: tab,
            resetStack: resetStack
        )
    }

    func goToGroupDashboard(
        _ groupId: String,
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(to: .groupDashboard(groupId: groupId), on: tab, resetStack: resetStack)
    }

    func goToGroupOutput(_ group: GroupDTO, on tab: AppTab? = nil) {
        guard let itinerary = group.itinerary else { return }
        let month = Month(wireValue: group.startMonth) ?? .january
        var state = TripOutputStore.State(
            details: Trip.Details(
                destination: Place(name: group.destination),
                members: Trip.Details.Members(groupType: .group),
                duration: group.durationDays,
                month: month
            ),
            mode: .groupTrip
        )
        state.groupId = group.groupId
        state.groupViewerIsAdmin = group.viewerIsAdmin
        state.itineraryResponse = .loaded(itinerary)
        if let suggestions = group.suggestions { state.suggestionsResponse = .loaded(suggestions) }
        if let briefing = group.knowBeforeYouGo { state.knowBeforeYouGoResponse = .loaded(briefing) }
        if let items = group.worthItItems { state.worthItResponse = .loaded(items) }
        if let areas = group.whereToStay { state.whereToStayResponse = .loaded(areas) }
        state.interestPrompts = group.interestPrompts
        state.deepDives = group.deepDives
        state.accommodation = group.accommodation
        state.groupNearYouSetBy = group.nearYouSetBy
        state.groupNearYouGenerationCount = group.nearYouGenerationCount
        switch group.nearYouOperationState.state {
        case .generating:
            state.nearYouResponse = .loading
        case .failed:
            state.nearYouResponse = .error(
                TripGenerationError.backend(
                    code: group.nearYouOperationState.code ?? "group_near_you_failed"
                )
            )
        case .ready:
            if let nearYou = group.nearYou { state.nearYouResponse = .loaded(nearYou) }
        case .absent:
            break
        }
        if let imageURL = group.imageUrl, let url = URL(string: imageURL) {
            state.imageUrlResponse = .loaded(url)
        }
        go(to: .groupOutput(state), on: tab, dedupe: false)
    }

    func goToGroupJoin(
        code: String,
        on tab: AppTab? = nil,
        resetStack: Bool = false,
        analyticsSource: String = "manual_code"
    ) {
        groupJoinAnalyticsSource = analyticsSource
        go(to: .groupJoin(code: code), on: tab, resetStack: resetStack, dedupe: false)
    }

    func goToSharedTrip(
        code: String,
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(to: .sharedTrip(code: code), on: tab, resetStack: resetStack)
    }

    func goToFeedback(on tab: AppTab? = nil, resetStack: Bool = false) {
        go(to: .feedback, on: tab, resetStack: resetStack)
    }

    func goToSettings(on tab: AppTab? = nil, resetStack: Bool = false) {
        go(to: .settings, on: tab, resetStack: resetStack)
    }

    func goToUnknown(
        _ message: String? = nil,
        on tab: AppTab? = nil,
        resetStack: Bool = false
    ) {
        go(to: .unknown(message), on: tab, resetStack: resetStack, dedupe: false)
    }

    func goToDebugMenu(on tab: AppTab? = nil, resetStack: Bool = false) {
        go(to: .debugMenu, on: tab, resetStack: resetStack)
    }

    func pop(on tab: AppTab? = nil) {
        let target = tab ?? selectedTab
        _ = self[target].popLast()
    }

    func popToRoot(on tab: AppTab? = nil) {
        self[tab ?? selectedTab] = []
    }

    func handleDeepLink(_ url: URL) {
        let segments = ([url.host] + url.pathComponents)
            .compactMap { $0 }
            .filter { $0 != "/" }

        if let joinIndex = segments.firstIndex(of: "join"), joinIndex + 1 < segments.count {
            let code = segments[joinIndex + 1]
            if code.count == 5, code.allSatisfy(\.isNumber) {
                goToGroupJoin(
                    code: code,
                    on: .trips,
                    resetStack: true,
                    analyticsSource: "deep_link"
                )
                selectedTab = .trips
                return
            }
        }

        if let tripIndex = segments.firstIndex(of: "t"), tripIndex + 1 < segments.count {
            let code = segments[tripIndex + 1].lowercased()
            if code.count == 32, code.allSatisfy(\.isHexDigit) {
                goToSharedTrip(code: code, on: .trips, resetStack: true)
                selectedTab = .trips
                return
            }
        }

#if DEBUG
        if segments.contains("debug") {
            goToDebugMenu(on: .profile, resetStack: true)
            selectedTab = .profile
            return
        }
#endif

        if segments.contains("feedback") {
            goToFeedback(on: .profile, resetStack: true)
            selectedTab = .profile
            return
        }

        goToUnknown(
            "Unknown deep link: \(url.absoluteString)",
            on: .home,
            resetStack: true
        )
        selectedTab = .home
    }

    private func go(
        to destination: Destination,
        on tab: AppTab? = nil,
        resetStack: Bool = false,
        dedupe: Bool = true
    ) {
        let target = tab ?? selectedTab
        if resetStack {
            self[target] = [destination]
        } else if !dedupe || self[target].last != destination {
            self[target].append(destination)
        }
    }
}

extension Month {
    init?(wireValue: String) {
        guard let value = Month.all.first(where: {
            $0.rawValue.caseInsensitiveCompare(wireValue) == .orderedSame
        }) else { return nil }
        self = value
    }
}
