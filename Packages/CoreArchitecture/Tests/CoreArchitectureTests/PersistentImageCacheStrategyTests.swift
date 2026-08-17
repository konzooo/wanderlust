import Foundation
import XCTest
@testable import CoreArchitecture

final class PersistentImageCacheStrategyTests: XCTestCase {
    func testStoredBytesSurviveAcrossCacheInstances() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistentImageCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let expected = Data([0x01, 0x02, 0x03, 0x04])
        let writer = PersistentImageCacheStrategy(directoryURL: directory)
        await writer.store(expected, forKey: "Barcelona, Spain")

        let reader = PersistentImageCacheStrategy(directoryURL: directory)
        let restored = await reader.retrieveData(forKey: "Barcelona, Spain")

        XCTAssertEqual(restored, expected)
    }

    func testDifferentKeysDoNotCollide() async {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistentImageCacheTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = PersistentImageCacheStrategy(directoryURL: directory)
        await cache.store(Data([0x01]), forKey: "Athens")
        await cache.store(Data([0x02]), forKey: "Lisbon")

        let athens = await cache.retrieveData(forKey: "Athens")
        let lisbon = await cache.retrieveData(forKey: "Lisbon")
        XCTAssertEqual(athens, Data([0x01]))
        XCTAssertEqual(lisbon, Data([0x02]))
    }
}
