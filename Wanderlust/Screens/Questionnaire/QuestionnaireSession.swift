import CoreModels
import DesignSystem
import Foundation

/// Mode-agnostic accumulator for one run of the questionnaire card stack.
///
/// This exists so a group member's answers can be collected independently of
/// `TripOrganizer.shared` (the solo scratchpad) — swiping for a group never
/// reads from or writes into the global singleton.
struct QuestionnaireSession: Equatable {
    private(set) var answers: [String: PreferenceChoice] = [:]
    /// Order questions were first answered in — doubles as undo history.
    private(set) var order: [String] = []

    var cardsCompleted: Int { order.count }

    mutating func record(questionID: String, choice: PreferenceChoice) {
        if answers[questionID] == nil {
            order.append(questionID)
        }
        answers[questionID] = choice
    }

    mutating func undoLast() {
        guard let lastID = order.popLast() else { return }
        answers.removeValue(forKey: lastID)
    }

    func preferences(questionnaireVersion: Int) -> MemberPreferences {
        MemberPreferences(
            questionnaireVersion: questionnaireVersion,
            answers: order.map { PreferenceAnswer(questionID: $0, choice: answers[$0]!) }
        )
    }
}

extension PreferenceChoice {
    /// Maps a card-stack swipe direction to the wire-format choice. Mirrors
    /// `QuestionaireStep.Option.init(_:)` below — the two enums are isomorphic.
    init?(_ direction: any Direction) {
        switch direction.rawValue() {
        case "left": self = .left
        case "right": self = .right
        case "top": self = .both
        default: return nil
        }
    }
}

extension QuestionaireStep.Option {
    init(_ choice: PreferenceChoice) {
        switch choice {
        case .left: self = .left
        case .right: self = .right
        case .both: self = .both
        }
    }
}
