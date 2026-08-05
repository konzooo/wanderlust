//
//  ComponentState.swift
//  CoreModels
//
//  How one generated part of a trip is stored on disk.
//

import Foundation

/// The persisted state of a single generated component.
///
/// This exists because "no data" was previously indistinguishable from three
/// very different situations. A saved trip whose suggestions call had not
/// finished was written as `Suggestions()` — an empty value that looks exactly
/// like a genuine empty result, so the app could neither retry it nor tell the
/// traveller anything true about it. Those cases are now distinct values:
///
/// - ``absent``: never requested, or still running. Nothing was lost.
/// - ``failed(code:)``: requested and it failed. Offer a retry, and say why.
/// - ``ready(_:)``: the backend returned this. An empty-but-successful result
///   is `.ready(T())` and is deliberately **not** the same value as `.absent`.
///
/// The rule that makes the distinction worth anything: never write a
/// placeholder to stand in for an unfinished call.
public enum ComponentState<Value: Codable & Hashable & Sendable>: Codable, Hashable, Sendable {
    /// Never requested, or requested and still in flight. No result was lost.
    case absent
    /// Requested and failed. `code` is the backend's stable error code.
    case failed(code: String)
    /// The component's result, including a legitimately empty one.
    case ready(Value)

    /// The result, if there is one. `nil` covers both "not asked" and "failed" —
    /// use ``isAbsent`` / ``failureCode`` when the difference matters.
    public var value: Value? {
        guard case let .ready(value) = self else { return nil }
        return value
    }

    public var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    public var isAbsent: Bool {
        if case .absent = self { return true }
        return false
    }

    /// The failure code, if this component failed. Drives retry affordances.
    public var failureCode: String? {
        guard case let .failed(code) = self else { return nil }
        return code
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case state, code, value
    }

    private enum Kind: String, Codable {
        case absent, failed, ready
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .state) {
        case .absent:
            self = .absent
        case .failed:
            // A failure whose code didn't survive is still a failure — degrading
            // to `.absent` here would silently claim nothing was ever tried.
            self = .failed(code: try container.decodeIfPresent(String.self, forKey: .code) ?? "unknown")
        case .ready:
            self = .ready(try container.decode(Value.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .absent:
            try container.encode(Kind.absent, forKey: .state)
        case .failed(let code):
            try container.encode(Kind.failed, forKey: .state)
            try container.encode(code, forKey: .code)
        case .ready(let value):
            try container.encode(Kind.ready, forKey: .state)
            try container.encode(value, forKey: .value)
        }
    }
}

public extension ComponentState {
    /// Combines a freshly generated state with whatever is already stored.
    ///
    /// This is the whole of the merge-on-complete save policy for one
    /// component: a trip is allowed to be saved as soon as its baseline is
    /// ready, components still generating write as `.absent`, and when one of
    /// them later completes the file is re-saved. That only works if `.absent`
    /// can never erase a real stored result — which is what this enforces.
    func merged(over stored: ComponentState<Value>) -> ComponentState<Value> {
        isAbsent ? stored : self
    }
}
