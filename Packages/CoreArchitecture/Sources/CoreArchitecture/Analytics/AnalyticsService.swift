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
    func setUserProperties(_ properties: [String: AnalyticsValue])
}

/// Small injectable surface used by screens and stores.
@MainActor
public protocol AnalyticsTracking: AnyObject {
    func log(_ event: AnalyticsEvent)
    func setUserProperties(_ properties: [String: AnalyticsValue])
}

final class NoOpAnalyticsService: AnalyticsService {
    func configure() {}
    func log(_ event: AnalyticsEvent) {}
    func setUserProperties(_ properties: [String: AnalyticsValue]) {}
}

/// In-memory provider used by unit tests and local schema verification.
public final class RecordingAnalyticsService: AnalyticsTracking {
    public private(set) var events: [AnalyticsEvent] = []
    public private(set) var userProperties: [String: AnalyticsValue] = [:]

    public init() {}

    public func log(_ event: AnalyticsEvent) {
        events.append(event)
    }

    public func setUserProperties(_ properties: [String: AnalyticsValue]) {
        userProperties.merge(properties) { _, new in new }
    }

    public func reset() {
        events.removeAll()
        userProperties.removeAll()
    }
}
