//
//  AnalyticsManager.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

import Foundation

/// Use this singleton throughout the app rather than referencing a concrete backend.
@MainActor
public final class AnalyticsTracker: AnalyticsTracking {

    public static let shared = AnalyticsTracker()
    private var service: AnalyticsService = NoOpAnalyticsService()
    private var testingClient: AnalyticsTracking?
    private var distributionChannel = "debug"
    private var configured = false

    public func initialize(configuration: AnalyticsConfiguration = .appDefault()) {
        guard !configured else { return }
        configured = true
        distributionChannel = configuration.distributionChannel
        service = configuration.networkEnabled
            ? AmplitudeAnalyticsService(configuration: configuration)
            : NoOpAnalyticsService()
        service.configure()
    }

    public func log(_ event: AnalyticsEvent) {
        guard event.isContractValid else {
            assertionFailure(
                "Analytics event \(event.name.rawValue) violates its property contract"
            )
            return
        }
        var properties = event.properties
        properties["schema_version"] = .integer(AnalyticsEvent.schemaVersion)
        properties["distribution_channel"] = .string(distributionChannel)
        let enrichedEvent = AnalyticsEvent(event.name, properties: properties)
        if let testingClient {
            testingClient.log(enrichedEvent)
        } else {
            service.log(enrichedEvent)
        }
    }

    /// Updates anonymous install-level state. No account identifier or raw
    /// content is attached; these properties make profile/trip cohorts usable.
    public func setUserProperties(_ properties: [String: AnalyticsValue]) {
        let sanitized = properties.filter { Self.userPropertyContract[$0.key] != nil }
            .filter { Self.userPropertyContract[$0.key] == Self.kind(of: $0.value) }
        guard !sanitized.isEmpty else { return }
        if let testingClient {
            testingClient.setUserProperties(sanitized)
        } else {
            service.setUserProperties(sanitized)
        }
    }

    /// Installs an in-memory or custom client for deterministic app/store tests.
    /// Passing `nil` restores the normal provider selection path.
    public func useForTesting(_ client: AnalyticsTracking?) {
        testingClient = client
        distributionChannel = client == nil ? "debug" : "test"
        if client == nil {
            configured = false
            service = NoOpAnalyticsService()
        }
    }

    private init() {}

    private enum ValueKind: Equatable { case integer, boolean }
    private static let userPropertyContract: [String: ValueKind] = [
        "has_profile": .boolean,
        "profile_count": .integer,
        "attach_profile_by_default": .boolean,
        "saved_solo_trip_count": .integer,
        "group_trip_count": .integer,
        "received_trip_count": .integer
    ]

    private static func kind(of value: AnalyticsValue) -> ValueKind? {
        switch value {
        case .integer: .integer
        case .boolean: .boolean
        case .string, .double: nil
        }
    }
}
