//
//  Destiations.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/4/25.
//

import Foundation

/// Represents all possible navigation destinations in the app.
enum Destination: Hashable {
    /// The home screen (root).
    case home
    /// The basic info screen, with its state.
    case basicInfo(BasicInfoStore.State)
    /// The questionnaire screen, with its state.
    case questionnaire(QuestionnaireStore.State)
    /// The itinerary result screen, with its state.
    case itineraryResult(TripOutputStore.State)
    /// The saved trips screen.
    case savedTrips
    /// The group trip creation screen.
    case groupCreate
    /// The group trip members screen, with its state.
    case groupMembers(GroupTripMembersStore.State)
    /// The group questionnaire (swipe) screen for a given group.
    case groupSwipe(groupId: String)
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
    /// An unknown or deprecated destination, for future-proofing and deep linking.
    case unknown(String? = nil)
    /// The internal debug menu (QA toggles, design-in-progress previews). DEBUG builds only.
    case debugMenu
}
