//
//  ChatCompletionServiceTests.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//


//
//  ChatCompletionServiceTests.swift
//  NetworkingTests
//
//  Created by Unit-Tests on 16 Jun 2025.
//

import XCTest
@testable import Networking          // ← Replace with your module name

// -----------------------------------------------------------------------------
// JSON helpers (payloads the OpenAI API would return)
// -----------------------------------------------------------------------------
private func makeChatCompletionJSON(_ text: String) -> Data {
    """
    {
      "choices" : [
        { "message" : { "content" : "\(text)" } }
      ]
    }
    """.data(using: .utf8)!
}

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

final class ChatCompletionServiceTests: XCTestCase {

    private let apiKey   = "unit-test-key"
    private let endpoint = OpenAIEndpoint.chatCompletions
    private let system   = "You are TestBot"
    private let userMsg  = "Hello?"

    // 1️⃣ Happy-path – correct content returned & headers/body set
    func test_completion_returnsAssistantContent() async throws {

        // Arrange
        let expected = "Hi there!"
        let stub     = makeChatCompletionJSON(expected)
        let mockNet  = MockNetworkClient(stub: .success(stub))          // your mock
        let client   = OpenAIClient(network: mockNet, apiKey: apiKey)

        let service  = ChatCompletionService(client: client,
                                             systemPrompt: system)

        // Act
        let reply = try await service.completion(prompt: userMsg)

        // Assert – content
        XCTAssertEqual(reply, expected)

        // Assert – auth + content-type headers
        XCTAssertEqual(mockNet.capturedHeaders?["Authorization"],
                       "Bearer \(apiKey)")
        XCTAssertEqual(mockNet.capturedHeaders?["Content-Type"],
                       "application/json")

        // Assert – body contains model + both messages
        guard let bodyData = mockNet.capturedBody else {
            XCTFail("POST should include a JSON body"); return
        }
        let json = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        XCTAssertEqual(json?["model"] as? String, "gpt-4o-mini")             // default model

        if let messages = json?["messages"] as? [[String: String]] {
            XCTAssertEqual(messages.count, 2)
            XCTAssertTrue(messages.contains { $0["role"] == "system" && $0["content"] == system })
            XCTAssertTrue(messages.contains { $0["role"] == "user"   && $0["content"] == userMsg })
        } else {
            XCTFail("messages array missing in encoded body")
        }
    }

    // 2️⃣ Malformed JSON – decoding bubbles up
    func test_completion_decodingErrorPropagated() async {
        // Arrange – API returns junk
        let mockNet  = MockNetworkClient(stub: .success(Data("💣".utf8)))
        let client   = OpenAIClient(network: mockNet, apiKey: apiKey)
        let service  = ChatCompletionService(client: client,
                                             systemPrompt: system)

        // Act / Assert (portable across Xcode versions)
        do {
            _ = try await service.completion(prompt: userMsg)
            XCTFail("Expected decoding to fail")
        } catch {
            XCTAssertTrue(error is DecodingError,
                          "Expected DecodingError, got \(error)")
        }
    }
}
