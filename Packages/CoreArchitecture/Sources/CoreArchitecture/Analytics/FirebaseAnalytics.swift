//
//  FirebaseAnalyticsService.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

import Foundation
import FirebaseCore
import FirebaseAnalytics

/// Default Firebase implementation (Analytics + Crashlytics).
final class FirebaseAnalytics: AnalyticsService {

    init() {}

    func configure() {
        FirebaseApp.configure()
    }

    func log(_ event: AnalyticsEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    func setUserProperty(_ value: String?, for key: String) {
        Analytics.setUserProperty(value, forName: key)
    }

    func setUserID(_ id: String?) {
        Analytics.setUserID(id)
    }

    func setDefaultParameters(_ parameters: [String: Any]) {
        Analytics.setDefaultEventParameters(parameters)
    }

//    public func record(error: Error, additionalInfo: [String: Any]? = nil) {
//        Crashlyti.crashlytics().record(error: error, userInfo: additionalInfo)
//    }
}
