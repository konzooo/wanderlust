import SwiftUI
import DesignSystem

/// Centralized navigation router for the app. Only mutate the navigation path via these methods.
class NavigationRouter: ObservableObject {
    /// The navigation path for the app. Only mutate via router methods.
    @Published var path: [Destination] = []

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

    /// Navigate to the itinerary result screen. Requires a non-empty trip summary.
    func goToItineraryResult(
        _ state: TripOutputStore.State = .init(tripSummary: "", details: .mock, mode: .newTrip),
        resetStack: Bool = false
    ) {
        precondition(!state.tripSummary.isEmpty, "Trip summary must not be empty")
        if resetStack {
            path.removeAll()
            path.append(.savedTrips)
        }

        path.append(.itineraryResult(state))
    }

    /// Navigate to the feedback screen.
    func goToFeedback() {
        guard path.last != .feedback else {
            return
        }
        path.append(.feedback)
    }

    /// Navigate to an unknown or deprecated destination (for deep linking or migration).
    func goToUnknown(_ message: String? = nil) {
        path.append(.unknown(message))
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
    func handleDeepLink(_ url: URL) {
        // Example: /feedback, /itinerary, etc.
        switch url.path {
        case "/feedback":
            goToFeedback()
        case "/itinerary":
            // You would parse query params and create a state here
            goToUnknown("Deep link to itinerary not yet implemented")
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
        case .newTrip:
            goToBasicInfo(resetStack: true)
        case .feedback:
            goToFeedback()
        case .none:
            break
        }
    }
}
