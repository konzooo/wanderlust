import Foundation

/// A single group member's structured questionnaire answers.
///
/// Unlike the solo flow — where swipe answers live only as transient state on
/// `TripOrganizer.shared` and are flattened straight into a prompt string — a
/// group member's answers must be captured as a durable, `Codable` payload so
/// they can be uploaded to the backend and combined with the rest of the group
/// before generation.
public struct MemberPreferences: Equatable, Hashable, Codable, Sendable {
    /// The questionnaire revision these answers correspond to. The backend
    /// requires the answers to match exactly the question set for this version,
    /// so a member who swiped on an older/newer questionnaire is never silently
    /// counted as complete.
    public var questionnaireVersion: Int

    /// One entry per answered question. Order is not significant; the backend
    /// keys on ``PreferenceAnswer/questionID``.
    public var answers: [PreferenceAnswer]

    /// Optional persistent Traveller DNA captured as an immutable trip snapshot.
    /// Trip-specific `answers` always take precedence when the two disagree.
    public var profile: TravellerProfileSnapshot?

    public init(
        questionnaireVersion: Int,
        answers: [PreferenceAnswer],
        profile: TravellerProfileSnapshot? = nil
    ) {
        self.questionnaireVersion = questionnaireVersion
        self.answers = answers
        self.profile = profile
    }
}

/// A single answered question: which side of the card the member chose.
public struct PreferenceAnswer: Equatable, Hashable, Codable, Sendable {
    /// Stable identifier of the question (matches the questionnaire step id,
    /// e.g. "1"…"7").
    public let questionID: String
    public let choice: PreferenceChoice

    public init(questionID: String, choice: PreferenceChoice) {
        self.questionID = questionID
        self.choice = choice
    }
}

/// The three possible swipe outcomes, mirroring the questionnaire card engine
/// (`left` / `right` / `both`). Raw values are the wire format shared with the
/// backend validator, so they must stay lowercase and stable.
public enum PreferenceChoice: String, Equatable, Hashable, Codable, Sendable, CaseIterable {
    case left
    case right
    case both
}

public extension MemberPreferences {
    static var mock: Self {
        .init(
            questionnaireVersion: 1,
            answers: [
                .init(questionID: "1", choice: .left),
                .init(questionID: "2", choice: .both),
                .init(questionID: "3", choice: .right),
                .init(questionID: "4", choice: .left),
                .init(questionID: "5", choice: .both),
                .init(questionID: "6", choice: .right),
                .init(questionID: "7", choice: .left)
            ]
        )
    }
}
