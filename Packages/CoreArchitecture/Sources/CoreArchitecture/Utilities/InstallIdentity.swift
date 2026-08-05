//
//  InstallIdentity.swift
//  CoreArchitecture
//
//  The token this install presents to the backend so the server can meter
//  generation. It replaced the bundled OpenAI key: the device no longer holds a
//  credential worth stealing, only a random string that identifies "this
//  install" for rate-limiting purposes.
//

import Foundation
import Security

/// A random per-install token, minted on first use and kept in the Keychain.
///
/// This is **identity, not authorization**. The backend hashes it and counts
/// against it; it grants no access to anything, and a caller who mints their own
/// gains nothing except their own fresh quota — which is why the server also
/// carries a global daily budget underneath the per-install one.
///
/// Deliberately *not* the vendor identifier or `identifierForVendor`: those are
/// device identifiers with privacy weight and reset semantics we don't control.
/// A value we mint ourselves is both more stable and less sensitive.
public enum InstallIdentity {
    private static let account = "com.wanderlust.installToken"
    private static let lock = NSLock()

    /// Returns the stored token, minting and persisting one on first call.
    ///
    /// If the Keychain is unavailable the call still returns a usable token for
    /// this process rather than failing generation outright — the cost is that
    /// the install looks new to the server, which is the mild failure mode.
    public static func token() -> String {
        lock.lock()
        defer { lock.unlock() }

        if let existing = read(), !existing.isEmpty { return existing }
        let minted = mint()
        write(minted)
        return minted
    }

    /// 244 bits of entropy, matching the group capability tokens' shape.
    private static func mint() -> String {
        "\(UUID().uuidString)\(UUID().uuidString)"
            .replacingOccurrences(of: "-", with: "")
            .lowercased()
    }

    // MARK: – Keychain

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else { return nil }
        return token
    }

    private static func write(_ token: String) {
        let data = Data(token.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            // Readable after the first unlock so a relaunch never re-mints, and
            // never synced off this device — a new device is a new install.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        if SecItemAdd(query as CFDictionary, nil) == errSecDuplicateItem {
            SecItemUpdate(
                [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: account
                ] as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
        }
    }
}
