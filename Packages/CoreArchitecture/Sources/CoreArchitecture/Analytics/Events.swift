//
//  Events.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/3/25.
//


public extension AnalyticsEvent {
    public enum Key: String {
        case screenName = "screen_name"
        case buttonName = "button_name"
        case destination
    }

    public enum Screen: String {
        case home = "home"
        case basicInfo = "basic_info"
        case questionaire = "questionaire"
        case itineraryResult = "itinerary_result"
        case feedback = "feedback"
    }


    public static func screenViewed(_ screen: Screen) -> Self {
        .init("screen_viewed", parameters: [
            Key.screenName.rawValue: screen.rawValue
        ])
    }

    public static func buttonTapped(_ buttonName: String, screen: Screen) -> Self {
        .init("button_tapped", parameters: [
            Key.buttonName.rawValue: buttonName,
            Key.screenName.rawValue: screen.rawValue
        ])
    }

    public static func confirmBasicInfo(properties: [String: String]) -> Self {
        .init("confired_basic_info", parameters: [
            Key.screenName.rawValue: Screen.basicInfo,
            "basic_info": properties
        ])
    }

    public static func questionnaireFinished(properties: [String: String]) -> Self {
        .init("questionnaire_finished", parameters: [
            Key.screenName.rawValue: Screen.questionaire,
            "questionnaire_responses": properties
        ])
    }
}

