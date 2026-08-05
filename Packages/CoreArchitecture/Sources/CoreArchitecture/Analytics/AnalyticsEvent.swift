//
//  AnalyticsEvent.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

import Foundation

/// Primitive values accepted by the analytics contract.
public enum AnalyticsValue: Equatable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)

    var amplitudeValue: Any {
        switch self {
        case let .string(value): value
        case let .integer(value): value
        case let .double(value): value
        case let .boolean(value): value
        }
    }
}

/// Strongly typed names for the version-one product analytics contract.
public enum AnalyticsEventName: String, CaseIterable, Sendable {
    case screenViewed = "screen_viewed"
    case tripPlanningStarted = "trip_planning_started"
    case tripDetailsSubmitted = "trip_details_submitted"
    case questionnaireStarted = "questionnaire_started"
    case questionnaireLimitReached = "questionnaire_limit_reached"
    case questionnaireCompleted = "questionnaire_completed"
    case tripGenerationStarted = "trip_generation_started"
    case tripGenerationSucceeded = "trip_generation_succeeded"
    case tripGenerationFailed = "trip_generation_failed"
    case tripResultViewed = "trip_result_viewed"
    case tripSaved = "trip_saved"
    case tripDeleted = "trip_deleted"
    case favoriteChanged = "favorite_changed"
    case tripShareRequested = "trip_share_requested"
    case tripShareSucceeded = "trip_share_succeeded"
    case tripShareFailed = "trip_share_failed"
    case savedTripsViewed = "saved_trips_viewed"
    case savedTripOpened = "saved_trip_opened"
    case sharedTripOpened = "shared_trip_opened"
    case groupTripCreationStarted = "group_trip_creation_started"
    case groupTripCreated = "group_trip_created"
    case groupTripCreationFailed = "group_trip_creation_failed"
    case groupMemberAdded = "group_member_added"
    case groupInviteShared = "group_invite_shared"
    case groupJoinStarted = "group_join_started"
    case groupJoinSucceeded = "group_join_succeeded"
    case groupJoinFailed = "group_join_failed"
    case groupPreferencesSubmitted = "group_preferences_submitted"
    case groupGenerationRequested = "group_generation_requested"
    case groupGenerationStateChanged = "group_generation_state_changed"
    case groupResultViewed = "group_result_viewed"
    case travellerProfileSaved = "traveller_profile_saved"
    case travellerProfileDeleted = "traveller_profile_deleted"
    case travellerProfileSelected = "traveller_profile_selected"
    case feedbackSubmitted = "feedback_submitted"
}

/// A validated event with primitive, flat properties only.
public struct AnalyticsEvent: Equatable, Sendable {
    public static let schemaVersion = 1

    public let name: AnalyticsEventName
    public let properties: [String: AnalyticsValue]

    public init(
        _ name: AnalyticsEventName,
        properties: [String: AnalyticsValue] = [:]
    ) {
        self.name = name
        self.properties = Self.sanitize(properties)
    }

    private static let forbiddenKeys: Set<String> = [
        "user_id", "device_id", "group_id", "member_id", "profile_id",
        "share_code", "invite_code", "code", "token", "url",
        "raw_error", "error_message", "name", "group_name", "member_name",
        "profile_name", "notes", "customizations", "feedback_text",
        "suggestion_text", "generated_content", "title", "content"
    ]
    private static let forbiddenKeyFragments = [
        "token", "code", "url", "raw_error", "error_message", "free_text"
    ]

    private static func sanitize(
        _ properties: [String: AnalyticsValue]
    ) -> [String: AnalyticsValue] {
        properties.reduce(into: [:]) { result, pair in
            let key = pair.key.lowercased()
            guard !forbiddenKeys.contains(key),
                  !forbiddenKeyFragments.contains(where: key.contains),
                  !(key.hasSuffix("_id") && key != "questionnaire_id"),
                  !(key.hasSuffix("_name") && key != "screen_name")
            else { return }

            switch pair.value {
            case let .string(value):
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.count <= 120 else { return }
                result[key] = .string(trimmed)
            case .integer, .double, .boolean:
                result[key] = pair.value
            }
        }
    }

    /// Used by the tracker and tests to fail closed when required contract
    /// fields are missing. Optional fields remain event-specific.
    public var isContractValid: Bool {
        Self.requiredProperties(for: name).isSubset(of: Set(properties.keys))
    }

    public static func requiredProperties(
        for name: AnalyticsEventName
    ) -> Set<String> {
        switch name {
        case .screenViewed:
            ["screen_name"]
        case .tripPlanningStarted:
            ["entry_point"]
        case .tripDetailsSubmitted:
            [
                "duration_days", "start_month", "party_type",
                "party_age_bucket", "party_gender", "has_custom_notes",
                "profile_usage"
            ]
        case .questionnaireStarted:
            ["trip_mode", "questionnaire_version", "question_count"]
        case .questionnaireLimitReached:
            ["trip_mode", "questionnaire_version"]
        case .questionnaireCompleted:
            [
                "trip_mode", "questionnaire_version", "question_count",
                "duration_ms", "undo_count"
            ]
        case .tripGenerationStarted:
            ["component", "attempt", "trip_mode"]
        case .tripGenerationSucceeded:
            ["component", "attempt", "trip_mode", "duration_ms"]
        case .tripGenerationFailed:
            ["component", "attempt", "trip_mode", "duration_ms", "error_category"]
        case .tripResultViewed, .groupResultViewed:
            ["trip_type"]
        case .tripSaved, .tripDeleted:
            ["outcome", "trip_type"]
        case .favoriteChanged:
            ["action", "favorite_count", "trip_type"]
        case .tripShareRequested:
            ["trip_type"]
        case .tripShareSucceeded, .tripShareFailed:
            ["outcome", "trip_type"]
        case .savedTripsViewed:
            ["personal_count", "group_count", "received_count"]
        case .savedTripOpened:
            ["trip_type"]
        case .sharedTripOpened:
            ["source", "outcome"]
        case .groupTripCreationStarted:
            ["duration_days", "start_month", "has_profile"]
        case .groupTripCreated, .groupTripCreationFailed:
            ["duration_days", "start_month", "has_profile", "outcome"]
        case .groupMemberAdded:
            ["role", "roster_count", "outcome"]
        case .groupInviteShared:
            ["method", "roster_count"]
        case .groupJoinStarted:
            ["source", "method"]
        case .groupJoinSucceeded, .groupJoinFailed:
            ["source", "method", "outcome"]
        case .groupPreferencesSubmitted:
            ["questionnaire_version", "question_count", "has_profile", "outcome"]
        case .groupGenerationRequested:
            ["action"]
        case .groupGenerationStateChanged:
            ["previous_state", "state", "roster_count", "completed_count"]
        case .travellerProfileSaved:
            [
                "operation", "profile_count", "skip_count",
                "must_have_count", "has_notes"
            ]
        case .travellerProfileDeleted:
            ["profile_count", "skip_count", "must_have_count", "has_notes"]
        case .travellerProfileSelected:
            ["selection", "profile_count"]
        case .feedbackSubmitted:
            [
                "outcome", "has_likes_dislikes", "has_suggestions",
                "likes_dislikes_length_bucket", "suggestions_length_bucket"
            ]
        }
    }
}

public enum AnalyticsErrorCategory: String, Sendable {
    case network
    case timeout
    case rateLimited = "rate_limited"
    case authentication
    case validation
    case notFound = "not_found"
    case conflict
    case decoding
    case storage
    case service
    case unknown
}

public enum AnalyticsSanitizer {
    /// Emits only plausible place names. Free-form text, URLs, and identifiers fail closed.
    public static func destination(_ rawValue: String) -> String? {
        let collapsed = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()

        guard (2...80).contains(collapsed.count) else { return nil }
        let allowedPunctuation = CharacterSet(charactersIn: " .,-'’")
        let allowed = CharacterSet.letters
            .union(.nonBaseCharacters)
            .union(allowedPunctuation)
        guard collapsed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return collapsed
    }

    public static func ageBucket(_ age: Int?) -> String {
        guard let age else { return "unknown" }
        return switch age {
        case ..<18: "under_18"
        case 18...24: "18_24"
        case 25...34: "25_34"
        case 35...44: "35_44"
        case 45...54: "45_54"
        case 55...64: "55_64"
        default: "65_plus"
        }
    }

    public static func textLengthBucket(_ length: Int) -> String {
        switch length {
        case 0: "empty"
        case 1...50: "1_50"
        case 51...200: "51_200"
        case 201...500: "201_500"
        default: "500_plus"
        }
    }

    public static func errorCategory(_ error: Error) -> AnalyticsErrorCategory {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut ? .timeout : .network
        }
        if error is DecodingError { return .decoding }

        let value = String(describing: error).lowercased()
        if value.contains("timeout") || value.contains("timed out") { return .timeout }
        if value.contains("429") || value.contains("rate") { return .rateLimited }
        if value.contains("401") || value.contains("403") || value.contains("auth") { return .authentication }
        if value.contains("not found") || value.contains("missing") { return .notFound }
        if value.contains("already") || value.contains("conflict") { return .conflict }
        if value.contains("decode") || value.contains("json") { return .decoding }
        if value.contains("network") || value.contains("connection") { return .network }
        if value.contains("valid") { return .validation }
        if value.contains("file") || value.contains("storage") { return .storage }
        return .unknown
    }
}
