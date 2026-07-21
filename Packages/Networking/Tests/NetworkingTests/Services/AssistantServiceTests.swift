//
//  AssistantServiceTests.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//

import Foundation
@testable import Networking
import XCTest

final class AssistantServiceTests: XCTestCase {

    // MARK: 1️⃣ Happy-path – itinerary delivered
    func test_run_returnsItinerary() async throws {
        // Arrange
        let expectedItinerary = "DAY 1: Tokyo 🗼"
        let runID    = "run_123"
        let threadID = "thread_456"

        let network = SequenceNetworkClient([
            .success(makeCreateThreadRunJSON(runID: runID, threadID: threadID)), // 1️⃣ POST /threads/runs
            .success(makeRunStatusJSON("completed")),                             // 2️⃣ GET  /runs/{id}
            .success(makeThreadMessagesJSON(content: expectedItinerary))          // 3️⃣ GET  /messages
        ])

        let client   = OpenAIClient(network: network, apiKey: "fake")
        let service  = AssistantService(client: client,
                                        assistantID: "asst_dummy",
                                        pollInterval: .seconds(0))   // no delay

        // Act
        let itinerary = try await service.run(userMessage: "Plan a Tokyo trip")

        // Assert
        XCTAssertEqual(itinerary, expectedItinerary)
        XCTAssertEqual(network.calls.count, 3, "Expected exactly three HTTP calls")
        XCTAssertEqual(network.calls.first?.method, "POST")
    }

    // MARK: 2️⃣ Timeout – exceeds maxAttempts with status “running”
    func test_run_timesOutAndThrows() async {
        // Arrange – status never becomes “completed”
        let runID    = "run_123"
        let threadID = "thread_456"

        let network = SequenceNetworkClient([
            .success(makeCreateThreadRunJSON(runID: runID, threadID: threadID)), // POST
            .success(makeRunStatusJSON("running")),                              // GET #1
            .success(makeRunStatusJSON("running"))                               // GET #2  (maxAttempts = 2)
        ])

        let client  = OpenAIClient(network: network, apiKey: "fake")
        let service = AssistantService(client: client,
                                       assistantID: "asst_dummy",
                                       pollInterval: .seconds(0),
                                       maxAttempts: 2)

        // Act / Assert
        do {
            _ = try await service.run(userMessage: "Plan")
            XCTFail("Expected APIError on timeout")     // should never reach
        } catch {
            XCTAssertTrue(error is APIError, "Expected APIError on timeout")
        }
    }

    // MARK: 3️⃣ Immediate failure – status “failed”
    func test_run_statusFailedThrows() async {
        // Arrange – assistant fails
        let runID    = "run_X"
        let threadID = "thread_Y"

        let network = SequenceNetworkClient([
            .success(makeCreateThreadRunJSON(runID: runID, threadID: threadID)), // POST
            .success(makeRunStatusJSON("failed"))                                // GET  (first poll)
        ])

        let client  = OpenAIClient(network: network, apiKey: "fake")
        let service = AssistantService(client: client,
                                       assistantID: "asst_dummy",
                                       pollInterval: .seconds(0))

        // Act / Assert
        do {
            _ = try await service.run(userMessage: "Plan")
            XCTFail("Expected APIError on timeout")     // should never reach
        } catch {
            XCTAssertTrue(error is APIError, "Expected APIError on timeout")
        }
    }
}
