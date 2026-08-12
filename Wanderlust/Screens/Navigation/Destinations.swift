//
//  Destiations.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/4/25.
//

import Foundation

enum ProfileTripSelection: Hashable {
    case useDefault
    case none
    case profile(UUID)
}

/// Represents all possible navigation destinations in the app.
enum Destination: Hashable {
    /// The basic info screen, with its state.
    case basicInfo(BasicInfoStore.State)
    /// The questionnaire reads its session from TripOrganizer.
    case questionnaire
    /// The itinerary result screen, with its state.
    case itineraryResult(TripOutputStore.State)
    /// The group trip creation screen.
    case groupCreate(GroupTripCreateStore.Segment)
    /// The group trip members screen, with its state.
    case groupMembers(GroupTripMembersStore.State)
    /// The group questionnaire (swipe) screen for a given group.
    case groupSwipe(groupId: String, profileSelection: ProfileTripSelection = .useDefault)
    /// The live group dashboard for a given group.
    case groupDashboard(groupId: String)
    /// The read-only group trip output, with its pre-loaded state.
    case groupOutput(TripOutputStore.State)
    /// The join-a-group-trip screen for a given invite code.
    case groupJoin(code: String)
    /// A trip shared via a share link, resolved by its share code.
    case sharedTrip(code: String)
    /// The feedback screen.
    case feedback
    /// App settings, reached from the Profile tab.
    case settings
    /// An unknown or deprecated destination, for future-proofing and deep linking.
    case unknown(String? = nil)
    /// The internal debug menu (QA toggles, design-in-progress previews). DEBUG builds only.
    case debugMenu

    var hidesTabBar: Bool {
        switch self {
        case .basicInfo, .questionnaire, .itineraryResult, .groupCreate,
             .groupMembers, .groupSwipe, .groupJoin, .groupOutput, .sharedTrip:
            true
        case .groupDashboard, .feedback, .settings, .unknown, .debugMenu:
            false
        }
    }
}
