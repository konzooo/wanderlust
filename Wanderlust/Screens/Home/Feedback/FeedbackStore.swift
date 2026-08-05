//
//  FeedbackStore.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/29/25.
//

import CoreArchitecture
import Combine
import Networking

class FeedbackStore: ObservableStore {
    @Published var state: State
    @Published var submissionResult: FeedbackResult?

    private let feedbackService: FeedbackService

    init(initialState: State = State(), feedbackService: FeedbackService = FeedbackService()) {
        self.state = initialState
        self.feedbackService = feedbackService
    }

    func send(_ action: Action) {
        switch action {
        case .onAppear:
            break

        case .submit:
            sendFeedback()
            break
        }
    }

}

extension FeedbackStore {
    struct State: Equatable {
        var likesDislikes: String = ""
        var suggestions: String = ""

        var isSubmitButtonDisabled: Bool {
            likesDislikes.isEmpty && suggestions.isEmpty
        }
    }

    enum Action: Equatable {
        case onAppear
        case submit
    }
}

extension FeedbackStore {
    private func sendFeedback() {
        let likesLength = state.likesDislikes.count
        let suggestionsLength = state.suggestions.count
        let eventProperties: [String: AnalyticsValue] = [
            "has_likes_dislikes": .boolean(likesLength > 0),
            "has_suggestions": .boolean(suggestionsLength > 0),
            "likes_dislikes_length_bucket": .string(
                AnalyticsSanitizer.textLengthBucket(likesLength)
            ),
            "suggestions_length_bucket": .string(
                AnalyticsSanitizer.textLengthBucket(suggestionsLength)
            )
        ]
        Task { @MainActor in
            do {
                let feedback = FeedbackRequest(
                    userID: KeychainDeviceIDProvider().deviceID(), // TODO: add as Dependency
                    feedback: state.likesDislikes,
                    suggestion: state.suggestions
                )
                _ = try await feedbackService.sendFeedback(feedback)
                submissionResult = .success
                AnalyticsTracker.shared.log(
                    .outcome(
                        .feedbackSubmitted,
                        outcome: "success",
                        properties: eventProperties
                    )
                )
            } catch {
                submissionResult = .error
                AnalyticsTracker.shared.log(
                    .outcome(
                        .feedbackSubmitted,
                        outcome: "failure",
                        error: error,
                        properties: eventProperties
                    )
                )
                print("Failed to send feedback: \(error)")
            }
        }
    }
}
