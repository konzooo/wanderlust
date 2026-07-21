//
//  QuestionnaireViewModel.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/20/25.
//

import CoreArchitecture
import DesignSystem
import Foundation
import SwiftUI

class QuestionnaireStore: ObservableStore {
    @Published var state: State = State()
    private let metricsTracker = MetricsTracker(storage: UserDefaultsMetricsStorage())

    func send(_ action: Action) {
        switch action {
        case .start:
            // Check if threshold has been reached
            if metricsTracker.thresholdReached(for: .dailyItineraries) {
                state.presentDailyLimitSheet = true
            }
            break

        case let .cardSwipped(card, direction):
            guard let stepAnswer = QuestionaireStep.Option(direction) else {
                print("Error: \(direction.rawValue()) is not a valid direction")
                return
            }
            TripOrganizer.shared.set(response: stepAnswer, for: card.step)
            TripOrganizer.shared.questionaireList.prettyPrint()
            
            // Increment Progress Counter
            state.cardsCompleted += 1

        case .restart:
            withAnimation {
                state.presentDailyLimitSheet = false
            }

        case .finished:
            // Increment the daily itineraries metric
            metricsTracker.increment(for: .dailyItineraries)
            
        case .undo:
            TripOrganizer.shared.undoLastStep()
            withAnimation {
                if state.cardsCompleted > 0 {
                    state.cardsCompleted -= 1
                }
            }
        }
    }
}

extension QuestionnaireStore {
    struct State: Hashable, Equatable, KeyPathMutable {
        var cards: [Card] = TripOrganizer.shared.questionaireList.map { Card(step: $0) }
        var presentDailyLimitSheet: Bool = false
        var cardsCompleted: Int = 0  // Track how many cards have been swiped
        
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

extension QuestionaireStep.Option {
    init?(_ direction: any Direction) {
        switch direction.rawValue() {
        case "left":
            self = .left
        case "right":
            self = .right
        case "top":
            self = .both
        default:
            return nil
        }
    }
}
