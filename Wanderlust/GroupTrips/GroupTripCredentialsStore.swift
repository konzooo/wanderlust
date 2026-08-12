import CoreModels
import Foundation
import Security

/// A device's capability tokens for one group — the only thing that lets this
/// device call authorized Convex functions for that group. `adminToken` is
/// present only on the device that created the group.
struct GroupTripCredentials: Equatable {
    let groupId: String
    let code: String
    let memberId: String
    let memberToken: String
    let adminToken: String?
}

/// Persists each group's capability tokens in the Keychain (mirrors the
/// minimal helpers in `KeychainDeviceIDProvider`), plus a lightweight registry
/// of joined group IDs in UserDefaults — just enough to know which groups to
/// ask Convex about for "My Group Trips". Never stores or reads a device ID.
/// Lightweight, locally-cached summary of a group this device belongs to —
/// enough to render the "My Group Trips" list without a round-trip. Live status
/// comes from the dashboard subscription when the group is opened.
struct GroupTripSummary: Codable, Equatable, Identifiable {
    let groupId: String
    let name: String
    let destination: String
    let code: String
    let createdAt: Date?
    let startMonth: Month?
    let durationDays: Int?

    init(
        groupId: String,
        name: String,
        destination: String,
        code: String,
        createdAt: Date? = nil,
        startMonth: Month? = nil,
        durationDays: Int? = nil
    ) {
        self.groupId = groupId
        self.name = name
        self.destination = destination
        self.code = code
        self.createdAt = createdAt
        self.startMonth = startMonth
        self.durationDays = durationDays
    }

    var id: String { groupId }
}

enum GroupTripCredentialsStore {
    private static let registryKey = "com.wanderlust.grouptrip.joinedGroupIDs"
    private static let summariesKey = "com.wanderlust.grouptrip.summaries"

    static func save(_ credentials: GroupTripCredentials) {
        saveKeychain(memberTokenKey(credentials.groupId), credentials.memberToken)
        saveKeychain(memberIdKey(credentials.groupId), credentials.memberId)
        saveKeychain(codeKey(credentials.groupId), credentials.code)
        if let adminToken = credentials.adminToken {
            saveKeychain(adminTokenKey(credentials.groupId), adminToken)
        }
        addToRegistry(credentials.groupId)
    }

    static func load(groupId: String) -> GroupTripCredentials? {
        guard let memberToken = readKeychain(memberTokenKey(groupId)),
              let memberId = readKeychain(memberIdKey(groupId)),
              let code = readKeychain(codeKey(groupId)) else { return nil }
        return GroupTripCredentials(
            groupId: groupId,
            code: code,
            memberId: memberId,
            memberToken: memberToken,
            adminToken: readKeychain(adminTokenKey(groupId))
        )
    }

    static var joinedGroupIDs: [String] {
        UserDefaults.standard.stringArray(forKey: registryKey) ?? []
    }

    private static func addToRegistry(_ groupId: String) {
        var ids = joinedGroupIDs
        guard !ids.contains(groupId) else { return }
        ids.append(groupId)
        UserDefaults.standard.set(ids, forKey: registryKey)
    }

    // MARK: - Group summaries (for "My Group Trips")

    static func upsertSummary(_ summary: GroupTripSummary) {
        var all = summaries.filter { $0.groupId != summary.groupId }
        all.insert(summary, at: 0)
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: summariesKey)
        }
        TripLibraryNotifier.postSoon()
    }

    static var summaries: [GroupTripSummary] {
        guard let data = UserDefaults.standard.data(forKey: summariesKey),
              let decoded = try? JSONDecoder().decode([GroupTripSummary].self, from: data) else {
            return []
        }
        return decoded
    }

    static func clear(groupId: String) {
        for key in [memberTokenKey(groupId), memberIdKey(groupId), codeKey(groupId), adminTokenKey(groupId)] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]
            SecItemDelete(query as CFDictionary)
        }
        UserDefaults.standard.set(joinedGroupIDs.filter { $0 != groupId }, forKey: registryKey)
        if let data = try? JSONEncoder().encode(summaries.filter { $0.groupId != groupId }) {
            UserDefaults.standard.set(data, forKey: summariesKey)
        }
        GroupTripPersonalStore().clear(groupId: groupId)
        TripLibraryNotifier.postSoon()
    }

    private static func memberTokenKey(_ groupId: String) -> String {
        "com.wanderlust.grouptrip.\(groupId).memberToken"
    }

    private static func memberIdKey(_ groupId: String) -> String {
        "com.wanderlust.grouptrip.\(groupId).memberId"
    }

    private static func codeKey(_ groupId: String) -> String {
        "com.wanderlust.grouptrip.\(groupId).code"
    }

    private static func adminTokenKey(_ groupId: String) -> String {
        "com.wanderlust.grouptrip.\(groupId).adminToken"
    }

    // MARK: – Minimal Keychain helpers (mirrors KeychainDeviceIDProvider)

    private static func readKeychain(_ key: String) -> String? {
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

    private static func saveKeychain(_ key: String, _ value: String) {
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

extension Notification.Name {
    static let tripLibraryDidChange = Notification.Name("wanderlust.tripLibraryDidChange")
}

enum TripLibraryNotifier {
    static func postSoon() {
        Task { @MainActor in
            NotificationCenter.default.post(name: .tripLibraryDidChange, object: nil)
        }
    }
}
