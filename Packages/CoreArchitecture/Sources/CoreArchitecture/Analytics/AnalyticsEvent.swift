//
//  AnalyticsEvent.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

/// Strongly‑typed analytics event.
public struct AnalyticsEvent {
    public let name: String
    public let parameters: [String: Any]?

    public init(_ name: String, parameters: [String: Any]? = nil) {
        self.name = name
        self.parameters = parameters
    }
}
