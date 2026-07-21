//
//  SecretVault.swift
//  CoreArchitecture
//
//  Created by Rodrigo Mato on 27/8/25.
//

import CryptoKit
import Security
import Foundation

enum VaultError: Error { case keychain, notFound }

enum SecretVault {
    // Keep the legacy tag so existing installs can continue to access their stored value.
    private static let keyTag = "com.travelbuddy.openai.devicekey"
    private static let wrappedURL: URL = {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("openai.wrapped")
    }()

    // Ensure device-bound symmetric key exists in Keychain
    private static func ensureDeviceKey() throws -> SymmetricKey {
        if let k = try? loadDeviceKey() { return k }
        let k = SymmetricKey(size: .bits256)
        try saveDeviceKey(k)
        return k
    }
    private static func saveDeviceKey(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let q: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecAttrKeyClass as String: kSecAttrKeyClassSymmetric,
            kSecValueData as String: data
        ]
        SecItemDelete(q as CFDictionary)
        let s = SecItemAdd(q as CFDictionary, nil)
        guard s == errSecSuccess else { throw VaultError.keychain }
    }
    private static func loadDeviceKey() throws -> SymmetricKey {
        let q: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: CFTypeRef?
        let s = SecItemCopyMatching(q as CFDictionary, &out)
        guard s == errSecSuccess, let data = out as? Data else { throw VaultError.notFound }
        return SymmetricKey(data: data)
    }

    // Wrap plaintext API key and persist wrapped blob (nonce+ct+tag)
    static func wrapAndPersist(_ plaintext: Data) throws {
        // Ensure Application Support directory exists before writing
        let directoryURL = wrappedURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let key = try ensureDeviceKey()
        let sealed = try AES.GCM.seal(plaintext, using: key)
        try sealed.combined!.write(to: wrappedURL, options: .completeFileProtection)
    }

    // Load wrapped blob and unwrap to plaintext
    static func loadAndUnwrap() throws -> Data {
        let key = try ensureDeviceKey()
        let combined = try Data(contentsOf: wrappedURL)
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    static func isInstalled() -> Bool { FileManager.default.fileExists(atPath: wrappedURL.path) }
}
