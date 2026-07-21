//
//  APIResponseState.swift
//
//  Created by Rodrigo Mato Castellano

import Foundation

/// Representation of a store combining an observable state with a single entry point
/// to dispatch actions representing business logic.
public protocol ObservableStore: ObservableObject {
    /// Store's state representation. Conforming types must ensure `State` is `Equatable`
    associatedtype State: Equatable

    /// Type representing user or system-initiated actions. Conforming types must
    /// ensure `Action` is `Equatable` (so actions can be compared or tested_)
    associatedtype Action: Equatable

    /// Current state of the store, which publishes changes, to any
    /// observing SwiftUI views or other subscribers, when modified.
    var state: State { get }

    /// The only way to interact with, or mutate, the store. Dispatching different `Action` values
    /// triggers updates to the `state` or side effects within the store.
    /// - `@MainActor` method given it's called from SwiftUI context and to simplify concurrency, if we have
    /// costly action then we should not execute them on main executor
    /// - Parameter action: The action which dispatches business logic
    func send(_ action: Action)

    /// Type representing the Store output actions. Conforming types must
    /// ensure `Output` is `Equatable` so actions can be compared or tested if needed.
//    associatedtype Output: Equatable

    /// Optional closure to emit Output event to the upper layer so that anyone can subscribe to
    /// output events (this could also be implemented with a combine publisher for multiple listeners)
//    var output: ((Output) -> Void)? { get }
}
