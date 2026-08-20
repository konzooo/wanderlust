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

/// Strongly typed names for the version-two product analytics contract.
public enum AnalyticsEventName: String, CaseIterable, Sendable {
    case screenViewed = "screen_viewed"
    case tripPlanningStarted = "trip_planning_started"
    case tripDetailsSubmitted = "trip_details_submitted"
    case questionnaireStarted = "questionnaire_started"
    case questionnaireLimitReached = "questionnaire_limit_reached"
    case questionnaireAnswered = "questionnaire_answered"
    case questionnaireCompleted = "questionnaire_completed"
    case tripGenerationStarted = "trip_generation_started"
    case tripGenerationSucceeded = "trip_generation_succeeded"
    case tripGenerationFailed = "trip_generation_failed"
    /// How many Near You proposals survived MapKit verification. Counts only —
    /// never a place name, so this stays a health signal and not a record of
    /// where anyone stayed.
    case nearYouVerified = "near_you_verified"
    case tripResultViewed = "trip_result_viewed"
    case tripCreated = "trip_created"
    case tripSectionViewed = "trip_section_viewed"
    case worthItDecided = "worth_it_decided"
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
    /// A client observation, not an authoritative backend transition. The name
    /// prevents this event being mistaken for a once-only lifecycle event.
    case groupGenerationStateObserved = "group_generation_state_observed"
    case groupResultViewed = "group_result_viewed"
    case travellerProfileSaved = "traveller_profile_saved"
    case travellerProfileDeleted = "traveller_profile_deleted"
    case travellerProfileSelected = "traveller_profile_selected"
    case profileFlowStarted = "profile_flow_started"
    case profileStepViewed = "profile_step_viewed"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case feedbackSubmitted = "feedback_submitted"
}

/// A validated event with primitive, flat properties only.
public struct AnalyticsEvent: Equatable, Sendable {
    public static let schemaVersion = 2

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
        "suggestion_text", "generated_content", "title", "content",
        "destination"
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

    /// Fails closed for missing, unknown, or incorrectly typed fields. This is
    /// deliberately stricter than the provider SDK so arbitrary strings cannot
    /// silently become part of the analytics schema.
    public var isContractValid: Bool {
        let keys = Set(properties.keys)
        let required = Self.requiredProperties(for: name)
        guard required.isSubset(of: keys),
              keys.isSubset(of: Self.allowedProperties(for: name))
        else { return false }
        return properties.allSatisfy { Self.isValidValue($0.value, for: $0.key) }
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
        case .questionnaireAnswered:
            [
                "trip_mode", "questionnaire_version", "question_key",
                "step_index", "choice"
            ]
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
        case .nearYouVerified:
            ["proposed", "resolved", "survived"]
        case .tripResultViewed, .groupResultViewed:
            ["trip_type"]
        case .tripCreated:
            ["trip_mode", "profile_attached", "profile_attachment_source"]
        case .tripSectionViewed:
            ["trip_mode", "trip_context", "section"]
        case .worthItDecided:
            ["trip_mode", "trip_context", "decision", "item_position"]
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
        case .groupGenerationStateObserved:
            ["previous_state", "state", "roster_count", "completed_count"]
        case .travellerProfileSaved:
            [
                "entry_point", "operation", "profile_count", "skip_count",
                "must_have_count", "has_notes", "dna_advice_detail",
                "dna_physical_energy", "dna_experience_breadth",
                "dna_day_rhythm", "dna_structure"
            ]
        case .travellerProfileDeleted:
            [
                "profile_count", "skip_count", "must_have_count", "has_notes",
                "dna_advice_detail", "dna_physical_energy",
                "dna_experience_breadth", "dna_day_rhythm", "dna_structure"
            ]
        case .travellerProfileSelected:
            ["selection", "profile_count", "entry_point"]
        case .profileFlowStarted:
            ["entry_point", "operation"]
        case .profileStepViewed:
            ["entry_point", "operation", "step_name", "step_index"]
        case .onboardingCompleted, .onboardingSkipped:
            ["flow", "page"]
        case .feedbackSubmitted:
            [
                "outcome", "has_likes_dislikes", "has_suggestions",
                "likes_dislikes_length_bucket", "suggestions_length_bucket"
            ]
        }
    }

    /// The exact optional-field contract for every event. Questionnaire/DNA
    /// fields are enumerated here as well; there are no arbitrary key escapes.
    public static func allowedProperties(
        for name: AnalyticsEventName
    ) -> Set<String> {
        let required = requiredProperties(for: name)
        let commonOutcome: Set<String> = ["error_category"]
        let questionnaireAnswers = Set((1...7).map { String(format: "q%02d_choice", $0) })
        let profileSummary: Set<String> = [
            "profile_attached", "profile_attachment_source", "profile_count",
            "profile_skip_count", "profile_must_have_count", "profile_has_notes",
            "dna_advice_detail", "dna_physical_energy", "dna_experience_breadth",
            "dna_day_rhythm", "dna_structure"
        ]

        let optional: Set<String> = switch name {
        case .screenViewed:
            ["entry_point"]
        case .tripPlanningStarted:
            ["trip_mode"]
        case .tripDetailsSubmitted:
            ["profile_count", "profile_attachment_source"]
        case .questionnaireStarted, .questionnaireLimitReached, .questionnaireAnswered:
            []
        case .questionnaireCompleted, .groupPreferencesSubmitted:
            questionnaireAnswers.union(profileSummary).union(commonOutcome)
        case .tripGenerationStarted:
            ["trip_type", "duration_days"]
        case .tripGenerationSucceeded, .tripGenerationFailed:
            ["trip_type", "duration_days", "error_category"]
        case .nearYouVerified:
            []
        case .tripResultViewed, .groupResultViewed:
            ["duration_days"]
        case .tripCreated:
            ["duration_days", "profile_count"]
        case .tripSectionViewed:
            ["subsection", "duration_days"]
        case .worthItDecided:
            ["duration_days"]
        case .tripSaved, .tripDeleted, .tripShareSucceeded, .tripShareFailed:
            ["duration_days", "error_category"]
        case .favoriteChanged:
            ["duration_days"]
        case .tripShareRequested:
            ["duration_days"]
        case .savedTripsViewed:
            []
        case .savedTripOpened:
            []
        case .sharedTripOpened:
            commonOutcome
        case .groupTripCreationStarted:
            ["profile_attachment_source"]
        case .groupTripCreated, .groupTripCreationFailed:
            ["profile_attachment_source", "error_category"]
        case .groupMemberAdded:
            commonOutcome
        case .groupInviteShared:
            []
        case .groupJoinStarted:
            []
        case .groupJoinSucceeded, .groupJoinFailed:
            commonOutcome
        case .groupGenerationRequested:
            ["roster_count", "completed_count"]
        case .groupGenerationStateObserved:
            commonOutcome
        case .travellerProfileSaved, .travellerProfileDeleted:
            [
                "entry_point", "has_age", "has_passport", "dna_advice_detail",
                "dna_physical_energy", "dna_experience_breadth", "dna_day_rhythm",
                "dna_structure"
            ]
        case .travellerProfileSelected:
            []
        case .profileFlowStarted:
            []
        case .profileStepViewed:
            []
        case .onboardingCompleted, .onboardingSkipped:
            []
        case .feedbackSubmitted:
            commonOutcome
        }
        return required.union(optional)
    }

    private static let integerKeys: Set<String> = [
        "attempt", "completed_count", "duration_days", "duration_ms",
        "favorite_count", "group_count", "item_position", "must_have_count",
        "personal_count", "profile_count", "profile_must_have_count",
        "profile_skip_count", "proposed", "question_count", "questionnaire_version",
        "received_count", "resolved", "roster_count", "skip_count", "step_index",
        "survived", "undo_count", "dna_advice_detail", "dna_physical_energy",
        "dna_experience_breadth", "dna_day_rhythm", "dna_structure"
    ]
    private static let booleanKeys: Set<String> = [
        "has_age", "has_custom_notes", "has_likes_dislikes", "has_notes",
        "has_passport", "has_profile", "has_suggestions", "profile_attached",
        "profile_has_notes"
    ]

    private static func isValidValue(_ value: AnalyticsValue, for key: String) -> Bool {
        if integerKeys.contains(key) {
            guard case let .integer(number) = value, number >= 0 else { return false }
            if key.hasPrefix("dna_") { return (1...5).contains(number) }
            return true
        }
        if booleanKeys.contains(key) {
            guard case .boolean = value else { return false }
            return true
        }
        guard case let .string(string) = value else { return false }
        if key == "choice" || key.hasPrefix("q") && key.hasSuffix("_choice") {
            return ["left", "right", "both"].contains(string)
        }
        if key == "question_key" {
            return Set((1...7).map { String(format: "q%02d", $0) }).contains(string)
        }
        if key == "trip_mode" { return ["solo", "group"].contains(string) }
        if key == "operation" { return ["create", "edit"].contains(string) }
        if key == "selection" { return ["profile", "none"].contains(string) }
        if key == "decision" { return ["keep", "skip", "undo"].contains(string) }
        if key == "component" {
            return [
                "itinerary", "suggestions", "know_before_you_go", "worth_it",
                "where_to_stay", "deep_dive", "near_you", "image",
                "suggestions_top_up"
            ].contains(string)
        }
        if key == "profile_attachment_source" {
            return ["none", "default", "manual"].contains(string)
        }
        return true
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

/// Errors with a stable domain taxonomy can opt out of fragile description
/// parsing. Product modules should conform their typed errors to this protocol.
public protocol AnalyticsErrorCategorizing: Error {
    var analyticsErrorCategory: AnalyticsErrorCategory { get }
}

public enum AnalyticsSanitizer {
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
        if let categorized = error as? any AnalyticsErrorCategorizing {
            return categorized.analyticsErrorCategory
        }
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
