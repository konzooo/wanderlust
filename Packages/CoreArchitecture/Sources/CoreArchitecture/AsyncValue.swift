//
//  APIResponseState.swift
//
//  Created by Rodrigo Mato Castellano

import Foundation

/// State of a network request at any given time.
public enum AsyncValue<Value: Equatable & Sendable>: Sendable {

    /// Represents the initial state, before any request is made.
    case initial

    /// Indicates that a request is in progress.
    case loading

    /// Signals that an error occurred while handling the request.
    /// Carries the associated `Error` provididng more details.
    case error(_: Error)

    /// Indicates the request completed successfully, holding the
    /// associated `NetworkData` payload.
    case loaded(_ data: Value)

    /// Returns `true` if the current state is `.loading`.
    public var isLoading: Bool {
        guard case .loading = self else { return false }
        return true
    }
    
    /// Returns `true` if the current state is `.loaded`.
    public var isLoaded: Bool {
        guard case .loaded = self else { return false }
        return true
    }

    /// Returns the payload if the current state is `.loaded`; otherwise `nil`.
    public var data: Value? {
        guard case let .loaded(data) = self else { return nil }
        return data
    }

    /// Returns the associated `Error` if the current state is `.error`; otherwise `nil`.
    public var error: Error? {
        guard case let .error(error) = self else { return nil }
        return error
    }
}

extension AsyncValue: Equatable {
    public static func == (lhs: AsyncValue<Value>, rhs: AsyncValue<Value>) -> Bool {
        switch (lhs, rhs) {
        case (.initial, .initial):
            return true
        case (.loading, .loading):
            return true
        case let (.loaded(first), .loaded(second)):
            return first == second
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

extension AsyncValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .initial:
            hasher.combine(0)
        case .loading:
            hasher.combine(1)
        case .loaded:
            hasher.combine(2)
        case .error:
            hasher.combine(3)
        }
    }
}
