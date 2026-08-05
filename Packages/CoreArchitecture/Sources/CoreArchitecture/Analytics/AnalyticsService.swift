//
//  every.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

/// Internal provider boundary. Product code depends on ``AnalyticsTracking``.
protocol AnalyticsService: AnyObject {
    func configure()
    func log(_ event: AnalyticsEvent)
}

/// Small injectable surface used by screens and stores.
@MainActor
public protocol AnalyticsTracking: AnyObject {
    func log(_ event: AnalyticsEvent)
}

final class NoOpAnalyticsService: AnalyticsService {
    func configure() {}
    func log(_ event: AnalyticsEvent) {}
}

/// In-memory provider used by unit tests and local schema verification.
public final class RecordingAnalyticsService: AnalyticsTracking {
    public private(set) var events: [AnalyticsEvent] = []

    public init() {}

    public func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

    public func reset() {
        events.removeAll()
    }
}
