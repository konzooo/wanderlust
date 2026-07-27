//
//  DrawerRow.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 4/7/25.
//

import Foundation

public enum DrawerRow: Int, CaseIterable {
    // Display order follows this declaration order (the drawer renders
    // `allCases` filtered of `.none`).
    case home = 0
    case newTrip
    case groupTrip
    case savedTrips
    case feedback
    case none

    var title: String {
        switch self {
        case .home:
            "Home"
        case .newTrip:
            "Start a new trip"
        case .groupTrip:
            "Start or join group trip"
        case .savedTrips:
            "Trips"
        case .feedback:
            "Give us feedback"
        case .none:
            "<invalid>"
        }
    }

    /// SF Symbol name for the row.
    var iconName: String {
        switch self {
        case .home:
            "house"
        case .newTrip:
            "plus.circle"
        case .groupTrip:
            "person.3"
        case .savedTrips:
            "suitcase.fill"
        case .feedback:
            "bubble.left"
        case .none:
            ""
        }
    }
}
