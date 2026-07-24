//
//  QuestionnaireViewModel.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/20/25.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import Foundation
import SwiftUI

class QuestionnaireStore: ObservableStore {
    @Published var state: State
    let mode: Mode
    private let metricsTracker = MetricsTracker(storage: UserDefaultsMetricsStorage())
    private var session = QuestionnaireSession()

    init(mode: Mode = .solo) {
        self.mode = mode
        self.state = State(mode: mode)
    }

    func send(_ action: Action) {
        switch action {
        case .start:
            // The daily-itineraries limit only applies to solo trips — a group
            // member swiping for someone else's trip never consumes it.
            guard case .solo = mode else { return }
            if metricsTracker.thresholdReached(for: .dailyItineraries) {
                state.presentDailyLimitSheet = true
            }

        case let .cardSwipped(card, direction):
            guard let choice = PreferenceChoice(direction) else {
                print("Error: \(direction.rawValue()) is not a valid direction")
                return
            }
            switch mode {
            case .solo:
                TripOrganizer.shared.set(response: QuestionaireStep.Option(choice), for: card.step)
                TripOrganizer.shared.questionaireList.prettyPrint()
            case .group:
                session.record(questionID: card.step.id, choice: choice)
            }

            // Increment Progress Counter
            state.cardsCompleted += 1

        case .restart:
            withAnimation {
                state.presentDailyLimitSheet = false
            }

        case .finished:
            // Increment the daily itineraries metric — solo only, see `.start`.
            if case .solo = mode {
                metricsTracker.increment(for: .dailyItineraries)
            }

        case .undo:
            switch mode {
            case .solo:
                TripOrganizer.shared.undoLastStep()
            case .group:
                session.undoLast()
            }
            withAnimation {
                if state.cardsCompleted > 0 {
                    state.cardsCompleted -= 1
                }
            }
        }
    }

    /// The collected answers for a group run, ready to submit. `nil` in solo mode.
    func groupPreferences() -> MemberPreferences? {
        guard case let .group(_, _, questionnaireVersion) = mode else { return nil }
        return session.preferences(questionnaireVersion: questionnaireVersion)
    }
}

extension QuestionnaireStore {
    /// Which trip this run of the questionnaire belongs to. Solo behaves
    /// exactly as before (mutates `TripOrganizer.shared`, applies the daily
    /// limit). Group collects answers into a self-contained `QuestionnaireSession`
    /// for upload, and never touches the solo scratchpad or its limit.
    enum Mode: Equatable {
        case solo
        case group(groupID: String, memberID: String, questionnaireVersion: Int = 1)
    }

    struct State: Hashable, Equatable, KeyPathMutable {
        var cards: [Card]
        var presentDailyLimitSheet: Bool = false
        var cardsCompleted: Int = 0  // Track how many cards have been swiped

        init(mode: Mode = .solo) {
            switch mode {
            case .solo:
                cards = TripOrganizer.shared.questionaireList.map { Card(step: $0) }
            case .group:
                cards = TripOrganizer.defaultQuestionaire.map { Card(step: $0) }
            }
        }

        // Questionnair progress fraction (starting at 1/TOTAL_CARDS)
        var currentProgress: CGFloat {
            let cardsCompleted = cardsCompleted
            // Start at 1/TOTAL_CARDS progress, increment by 1/TOTAL_CARDS for each completed card
            return min(1.0, CGFloat(cardsCompleted + 1) / CGFloat(cards.count))
        }
    }

    enum Action: Equatable {
        case start
        case cardSwipped(Card, any Direction)
        case undo
        case restart
        case finished

        static func == (lhs: Action, rhs: Action) -> Bool {
            switch (lhs, rhs) {
            case let (.cardSwipped(cardL, dirL),
                      .cardSwipped(cardR, dirR)):
                // Cards must match…
                guard cardL == cardR else { return false }
                // …and the two existential directions are equal when they're the *same* enum
                // and carry the same raw‑value String.
                return type(of: dirL) == type(of: dirR) &&
                       dirL.rawValue() == dirR.rawValue()

            case (.finished, .finished):
                return true

            default:
                return false
            }
        }

    }
}
