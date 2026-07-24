//
//  DrawerRow.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 4/7/25.
//

import Foundation

public enum DrawerRow: Int, CaseIterable {
    case home = 0
    case savedTrips
    case newTrip
    case feedback
    case none

    var title: String {
        switch self {
        case .home:
            "Home"
        case .savedTrips:
            "Saved trips"
        case .newTrip:
            "Start a new trip"
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
        case .savedTrips:
            "bookmark"
        case .newTrip:
            "plus.circle"
        case .feedback:
            "bubble.left"
        case .none:
            ""
        }
    }
}
