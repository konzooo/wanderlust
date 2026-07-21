//
//  UserDefaultsMetricsStorage.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/23/25.
//

import Foundation

/// UserDefaults-based implementation of MetricsStorage
public class UserDefaultsMetricsStorage: MetricsStorage {
    private let userDefaults: UserDefaults
    private let calendar: Calendar

    public init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
    }

    public func getValue(for key: MetricKey) -> Int {
        checkAndResetIfNeeded(for: key)
        return userDefaults.integer(forKey: key.userDefaultsKey)
    }

    public func setValue(_ value: Int, for key: MetricKey) {
        userDefaults.set(value, forKey: key.userDefaultsKey)
    }

    public func increment(for key: MetricKey) -> Int {
        checkAndResetIfNeeded(for: key)
        let currentValue = getValue(for: key)
        let newValue = currentValue + 1
        setValue(newValue, for: key)
        return newValue
    }

    public func reset(for key: MetricKey) {
        setValue(0, for: key)
        userDefaults.set(Date(), forKey: key.lastResetKey)
    }

    public func isThresholdReached(for key: MetricKey) -> Bool {
        return getValue(for: key) >= key.threshold
    }

    // MARK: - Private Methods

    private func checkAndResetIfNeeded(for key: MetricKey) {
        guard let lastResetDate = userDefaults.object(forKey: key.lastResetKey) as? Date else {
            reset(for: key)
            return
        }

        if !calendar.isDateInToday(lastResetDate) {
            reset(for: key)
        }
    }
}
