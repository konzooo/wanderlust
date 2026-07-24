import CoreModels
import Foundation

/// Persists a completed-but-not-yet-confirmed group questionnaire submission
/// to disk, keyed by member ID, so a failed `submitPreferences` upload never
/// loses the member's swipes — the retry path reloads the draft instead of
/// asking them to swipe again.
enum GroupQuestionnaireDraftStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("GroupQuestionnaireDrafts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(memberID: String) -> URL {
        directory.appendingPathComponent("\(memberID).json")
    }

    static func save(_ preferences: MemberPreferences, memberID: String) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        try? data.write(to: fileURL(memberID: memberID), options: .atomic)
    }

    static func load(memberID: String) -> MemberPreferences? {
        guard let data = try? Data(contentsOf: fileURL(memberID: memberID)) else { return nil }
        return try? JSONDecoder().decode(MemberPreferences.self, from: data)
    }

    static func clear(memberID: String) {
        try? FileManager.default.removeItem(at: fileURL(memberID: memberID))
    }
}
