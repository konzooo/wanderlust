//
//  AnalyticsManager.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

/// Use this singleton throughout the app rather than referencing a concrete backend.
@MainActor
public final class AnalyticsTracker {

    public static let shared = AnalyticsTracker()
    private var service: AnalyticsService

    public func initialize() {
        service.configure()

//        service.setDefaultParameters([])

        service.setUserID(KeychainDeviceIDProvider().deviceID()) // TODO: use as dependency
    }

    /// Swap in an alternative backend 
    func use(_ newService: AnalyticsService) {
        service = newService
        service.configure()
    }

    // MARK: Delegated API

    public func log(_ event: AnalyticsEvent) {
        service.log(event)
    }

    public func setUserProperty(_ value: String?, for key: String) {
        service.setUserProperty(value, for: key)
    }

    public func setUserID(_ id: String?) {
        service.setUserID(id)
    }

//    public func record(error: Error, additionalInfo: [String: Any]? = nil) {
//        service.record(error: error, additionalInfo: additionalInfo)
//    }

    // MARK: - Private

    private init(service: AnalyticsService = FirebaseAnalytics()) {
        self.service = service
    }

    func setDefaultParameters(_ parameters: [String: Any]) {
        service.setDefaultParameters(parameters)
    }
}
