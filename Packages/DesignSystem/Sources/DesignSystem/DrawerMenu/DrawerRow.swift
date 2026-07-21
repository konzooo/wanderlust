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
            "Saved Trips"
        case .newTrip:
            "Start A New Trip"
        case .feedback:
            "Give Us Feedback"
        case .none:
            "<invalid>"
        }
    }
    
    var iconName: String {
        switch self {
        case .home:
            "drawer-home"
        case .savedTrips:
            "drawer-saved-trips"
        case .newTrip:
            "drawer-new-trip"
        case .feedback:
            "drawer-feedback"
        case .none:
            ""
        }
    }
}
