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
                "Analytics event \(event.name.rawValue) is missing required properties"
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
}
