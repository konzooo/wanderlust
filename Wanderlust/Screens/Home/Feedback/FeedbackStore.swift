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
        Task {
            do {
                let feedback = FeedbackRequest(
                    userID: KeychainDeviceIDProvider().deviceID(), // TODO: add as Dependency
                    feedback: state.likesDislikes,
                    suggestion: state.suggestions
                )
                _ = try await feedbackService.sendFeedback(feedback)
                submissionResult = .success
            } catch {
                submissionResult = .error
                print("Failed to send feedback: \(error)")
            }
        }
    }
}
