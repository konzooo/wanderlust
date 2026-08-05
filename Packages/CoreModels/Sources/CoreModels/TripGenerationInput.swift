//
//  TripGenerationInput.swift
//  CoreModels
//
//  The typed contract the app sends to the backend to generate a solo trip.
//

import Foundation

/// Everything the backend needs to generate for one solo traveller or party.
///
/// This replaced a prose "trip summary" the app used to assemble and hand to the
/// model. That string was half data and half prompt, which meant the app owned a
/// piece of prompt engineering it could never keep in step with the backend's
/// group equivalent — and the two had already diverged. Now the app sends data;
/// the backend owns every word the model reads.
///
/// Mirrors `soloTripInput` in `ConvexBackend/convex/lib/validators.ts`. Keep the
/// property names identical: they are the wire format.
public struct TripGenerationInput: Equatable, Hashable, Codable, Sendable {
    public let destination: String
    /// `Trip.Details.GroupType` rawValue.
    public let groupType: String
    public let durationDays: Int
    /// `Month` rawValue — mixed case, normalised server-side for display.
    public let startMonth: String
    public let avgAge: Int?
    /// `Trip.Details.Gender` rawValue.
    public let gender: String?
    /// The traveller's own free-text notes. Treated as data, never instructions.
    public let customizations: String?
    /// One entry per answered question; unanswered slots are simply absent and
    /// render as N/A server-side rather than silently disappearing.
    public let answers: [PreferenceAnswer]
    public let profile: TravellerProfileSnapshot?

    public init(
        destination: String,
        groupType: String,
        durationDays: Int,
        startMonth: String,
        avgAge: Int? = nil,
        gender: String? = nil,
        customizations: String? = nil,
        answers: [PreferenceAnswer],
        profile: TravellerProfileSnapshot? = nil
    ) {
        self.destination = destination
        self.groupType = groupType
        self.durationDays = durationDays
        self.startMonth = startMonth
        self.avgAge = avgAge
        self.gender = gender
        self.customizations = customizations
        self.answers = answers
        self.profile = profile
    }
}

public extension TripGenerationInput {
    /// Builds the input from a trip's details plus this trip's swipe answers.
    init(
        details: Trip.Details,
        answers: [PreferenceAnswer],
        profile: TravellerProfileSnapshot? = nil
    ) {
        self.init(
            destination: details.destination.name,
            groupType: details.members.groupType.rawValue,
            durationDays: details.duration,
            startMonth: details.month.rawValue,
            avgAge: details.members.avgAge,
            gender: details.members.gender?.rawValue,
            customizations: details.members.customizations,
            answers: answers,
            profile: profile
        )
    }

    static var mock: Self {
        .init(details: .mock, answers: MemberPreferences.mock.answers)
    }
}

/// Identifies one trip for the backend's per-trip generation caps (today: at
/// most three interest deep dives). Opaque and client-minted — it is a cap
/// scope, never a user identifier, and it never leaves the traveller's own
/// requests.
public enum TripKey {
    public static func mint() -> String { UUID().uuidString }
}
