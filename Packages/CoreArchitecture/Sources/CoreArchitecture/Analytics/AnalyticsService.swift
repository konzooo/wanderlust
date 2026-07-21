//
//  every.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/2/25.
//

/// Thin protocol every analytics backend must conform to.
protocol AnalyticsService {
    func configure()
    func log(_ event: AnalyticsEvent)
    func setUserProperty(_ value: String?, for key: String)
    func setUserID(_ id: String?)
//    func record(error: Error, additionalInfo: [String: Any]?)
    func setDefaultParameters(_ parameters: [String: Any])
}

extension AnalyticsService {
    func record(error: Error, additionalInfo: [String: Any]? = nil) { /* no‑op by default */ }
}
