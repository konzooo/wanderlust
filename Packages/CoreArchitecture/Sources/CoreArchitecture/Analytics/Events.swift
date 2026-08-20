//
//  Events.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/3/25.
//


public extension AnalyticsEvent {
    enum Screen: String, Sendable {
        case home = "home"
        case basicInfo = "basic_info"
        case questionnaire = "questionnaire"
        case tripOutput = "trip_output"
        case feedback = "feedback"
        case savedTrips = "saved_trips"
        case profileTab = "profile_tab"
        case profileManagement = "profile_management"
        case profileEditor = "profile_editor"
        case groupCreate = "group_create"
        case groupMembers = "group_members"
        case groupJoin = "group_join"
        case groupQuestionnaire = "group_questionnaire"
        case groupDashboard = "group_dashboard"
        case sharedTrip = "shared_trip"
        // Onboarding. `welcome` carries the page as its entry point, so the
        // drop-off across the three pages falls out of `screen_viewed` without
        // a bespoke event.
        case welcome = "welcome"
        case groupIntro = "group_intro"
        case joinerIntro = "joiner_intro"
        case travellerDNAIntro = "traveller_dna_intro"
    }

    static func screenViewed(_ screen: Screen, entryPoint: String? = nil) -> Self {
        var properties: [String: AnalyticsValue] = [
            "screen_name": .string(screen.rawValue)
        ]
        if let entryPoint {
            properties["entry_point"] = .string(entryPoint)
        }
        return .init(.screenViewed, properties: properties)
    }

    static func tripPlanningStarted(entryPoint: String, tripMode: String = "solo") -> Self {
        .init(.tripPlanningStarted, properties: [
            "entry_point": .string(entryPoint),
            "trip_mode": .string(tripMode)
        ])
    }

    static func outcome(
        _ name: AnalyticsEventName,
        outcome: String,
        error: Error? = nil,
        properties: [String: AnalyticsValue] = [:]
    ) -> Self {
        var values = properties
        values["outcome"] = .string(outcome)
        if let error {
            values["error_category"] = .string(
                AnalyticsSanitizer.errorCategory(error).rawValue
            )
        }
        return .init(name, properties: values)
    }

}
