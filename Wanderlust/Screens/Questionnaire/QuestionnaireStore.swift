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

@MainActor
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
            guard state.startedAt == nil else { return }
            state.startedAt = Date()
            AnalyticsTracker.shared.log(
                .init(.questionnaireStarted, properties: [
                    "trip_mode": .string(mode.analyticsName),
                    "questionnaire_version": .integer(mode.questionnaireVersion),
                    "question_count": .integer(state.cards.count)
                ])
            )
            // The daily-itineraries limit only applies to solo trips — a group
            // member swiping for someone else's trip never consumes it.
            guard case .solo = mode else { return }
            if metricsTracker.thresholdReached(for: .dailyItineraries) {
                state.presentDailyLimitSheet = true
                AnalyticsTracker.shared.log(
                    .init(.questionnaireLimitReached, properties: [
                        "trip_mode": .string(mode.analyticsName),
                        "questionnaire_version": .integer(mode.questionnaireVersion)
                    ])
                )
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
            state.undoCount += 1
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
    func groupPreferences(profile: TravellerProfileSnapshot? = nil) -> MemberPreferences? {
        guard case let .group(_, _, questionnaireVersion) = mode else { return nil }
        var preferences = session.preferences(questionnaireVersion: questionnaireVersion)
        preferences.profile = profile
        return preferences
    }

    func completionEvent(profile: TravellerProfileSnapshot?) -> AnalyticsEvent? {
        guard !state.didLogCompletion else { return nil }
        state.didLogCompletion = true

        var properties: [String: AnalyticsValue] = [
            "trip_mode": .string(mode.analyticsName),
            "questionnaire_version": .integer(mode.questionnaireVersion),
            "question_count": .integer(state.cards.count),
            "duration_ms": .integer(
                Int(Date().timeIntervalSince(state.startedAt ?? Date()) * 1_000)
            ),
            "undo_count": .integer(state.undoCount)
        ]

        let answers: [(String, String)]
        switch mode {
        case .solo:
            answers = TripOrganizer.shared.questionaireList.compactMap { step in
                step.response.map { (step.id, $0.rawValue) }
            }
        case .group:
            answers = session.answers.map { ($0.key, $0.value.rawValue) }
        }
        for (id, choice) in answers {
            let paddedID = id.count == 1 ? "0\(id)" : id
            properties["q\(paddedID)_choice"] = .string(choice)
        }

        if let profile {
            for dimension in TravellerDNADimension.allCases {
                if let score = profile.score(for: dimension) {
                    properties["dna_\(dimension.rawValue)"] = .integer(score)
                }
            }
            properties["profile_skip_count"] = .integer(profile.usuallySkip.count)
            properties["profile_must_have_count"] = .integer(profile.mustHaves.count)
            properties["profile_has_notes"] = .boolean(
                !(profile.additionalNotes?
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            )
        }
        return .init(.questionnaireCompleted, properties: properties)
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

        var analyticsName: String {
            switch self {
            case .solo: "solo"
            case .group: "group"
            }
        }

        var questionnaireVersion: Int {
            switch self {
            case .solo: 1
            case let .group(_, _, version): version
            }
        }
    }

    struct State: Hashable, Equatable, KeyPathMutable {
        var cards: [Card]
        var presentDailyLimitSheet: Bool = false
        var cardsCompleted: Int = 0  // Track how many cards have been swiped
        var startedAt: Date?
        var undoCount = 0
        var didLogCompletion = false

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
