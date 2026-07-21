//
//  UserDefaultsStrategyTests.swift
//
//  Created by Rodrigo Mato Castellano
//

import XCTest
@testable import CoreArchitecture

final class UserDefaultsStrategyTests: XCTestCase {

    /// Custom object for testing.
    struct TestObject: Codable, Equatable {
        let id: Int
        let name: String
    }

    /// Custom UserDefaults suit for each test, so tests don't interfere with each other or real user defaults.
    private var userDefaults: UserDefaults!
    private var strategy: UserDefaultsCacheStrategy!

    override func setUp() {
        super.setUp()

        // Create a unique suite name for each test run
        let suiteName = "UserDefaultsStrategyTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!

        // Clear out any existing data
        userDefaults.removePersistentDomain(forName: suiteName)

        // Create the strategy with this custom user defaults
        strategy = UserDefaultsCacheStrategy(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults = nil
        strategy = nil
        super.tearDown()
    }

    func test_storeAndRetrieve_success() throws {
        // Given
        let testObj = TestObject(id: 123, name: "test")
        let testKey = "testKey"

        // When
        try strategy.store(testObj, forKey: testKey)
        let retrieved: TestObject? = try strategy.retrieve(forKey: testKey)

        // Then
        XCTAssertEqual(retrieved, testObj)
    }

    func test_retrieveMissingKey_returnsNil() throws {
        // Given
        let missingKey = "nonExistentKey"

        let retrieved: TestObject? = try strategy.retrieve(forKey: missingKey)
        XCTAssertNil(retrieved)
    }

    func test_retrieveDecodingError_throwsFailedDecoding() throws {
        // Given
        let key = "decodingErrorKey"
        userDefaults.set("random data".data(using: .utf8), forKey: key)

        // When
        do {
            let _: TestObject? = try strategy.retrieve(forKey: key)
            XCTFail("Expected to throw an error, but got a successful decode.")
        } catch let error as CacheStrategyError {
            // Then
            switch error {
            case .failedDecoding(let underlying):
                XCTAssertTrue(underlying is DecodingError)
            default:
                XCTFail("Expected .failedDecoding, but got \(error)")
            }
        } catch {
            XCTFail("Expected .failedDecoding, but got \(error)")
        }
    }
}
