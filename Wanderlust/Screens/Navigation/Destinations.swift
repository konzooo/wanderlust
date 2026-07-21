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
    /// The feedback screen.
    case feedback
    /// An unknown or deprecated destination, for future-proofing and deep linking.
    case unknown(String? = nil)
}
