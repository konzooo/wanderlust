//
//  HomeStore.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 1/6/25.
//

import CoreArchitecture
import DesignSystem
import Foundation
import Networking

class HomeStore: ObservableStore {
    init () {}
    @Published var state: State = State()

    func send(_ action: Action) {
        switch action {
        case .ctaTapped:
            break

        case .feedbackCardTapped:
            break
            
        case let .processFeedbackResult(result):
            state.feedbackResult = result
            state.presentFeedbackToast = true
        }
    }
}

extension HomeStore {
    struct State: Equatable {
        var feedbackResult: FeedbackResult? = nil
        var presentFeedbackToast: Bool = false
    }

    enum Action: Equatable {
        case ctaTapped
        case feedbackCardTapped
        case processFeedbackResult(FeedbackResult)
    }
}
