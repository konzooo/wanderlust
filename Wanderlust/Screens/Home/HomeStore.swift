import CoreArchitecture
import Foundation

@MainActor
final class HomeStore: ObservableStore {
    @Published var state: State

    init(initialState: State = .init()) {
        state = initialState
    }

    func send(_ action: Action) {
        switch action {
        case let .setDestination(value):
            state.destinationQuery = value
        }
    }
}

extension HomeStore {
    struct State: Equatable {
        var destinationQuery = ""

        var trimmedDestination: String {
            destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    enum Action: Equatable {
        case setDestination(String)
    }
}
