//
//  KeychainDeviceIDProvider.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato Castellano on 6/1/25.
//

import Foundation
import Security

public struct KeychainDeviceIDProvider: DeviceIDProvider {
    private static let key = "com.yourcompany.installID"

    public init() {}
    
    public func deviceID() -> String {
        if let cached = readKeychain(Self.key) { return cached }

        let new = UUID().uuidString
        saveKeychain(Self.key, new)
        return new
    }

    // MARK: – Minimal Keychain helpers

    private func readKeychain(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let s = String(data: data, encoding: .utf8) else { return nil }
        return s
    }

    private func saveKeychain(_ key: String, _ value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        if SecItemAdd(query as CFDictionary, nil) == errSecDuplicateItem {
            SecItemUpdate(query as CFDictionary,
                          [kSecValueData as String: data] as CFDictionary)
        }
    }
}
