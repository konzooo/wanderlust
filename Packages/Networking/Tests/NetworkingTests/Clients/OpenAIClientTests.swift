//
//  DummyBody.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//


//
//  OpenAIClient_WithMockNetworkClient_Tests.swift
//  NetworkingTests
//
//  Created by Unit-Tests on 16 Jun 2025.
//

import XCTest
@testable import Networking          // ← replace with the module name that
                                    //    contains OpenAIClient & OpenAIEndpoint

// -----------------------------------------------------------------------------
// Helper DTOs used only by the tests
// -----------------------------------------------------------------------------

/// Trivial body so we can test JSON encoding for a POST.
private struct DummyBody: Encodable { let foo = "bar" }

/// Minimal response that we can round-trip through the JSONEncoder/Decoder.
private struct DummyResponse: Codable, Equatable { let answer: String }

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

final class OpenAIClientTests: XCTestCase {

    // Shared constants
    private let apiKey   = "unit-test-key"
    private let endpoint = OpenAIEndpoint.chatCompletions   // "/chat/completions"

    // MARK: 1️⃣ GET flow – no body
    func test_send_GET_NoBody_UsesHeadersAndReturnsDecodedValue() async throws {
        // Arrange
        let payload   = DummyResponse(answer: "ok")
        let stubData  = try JSONEncoder().encode(payload)
        let mock      = MockNetworkClient(stub: .success(stubData))

        let client = OpenAIClient(network: mock, apiKey: apiKey)

        // Act
        let result: DummyResponse = try await client.send(endpoint)   // the no-body overload

        // Assert
        XCTAssertEqual(result, payload)

        // Headers were captured by the mock when `get` executed
        XCTAssertEqual(mock.capturedHeaders?["Authorization"],
                       "Bearer \(apiKey)")

        // Because this was a GET, the mock never stored a body
        XCTAssertNil(mock.capturedBody, "GET requests must not contain a body")
    }

    // MARK: 2️⃣ POST flow – JSON body encoding
    func test_send_POST_WithBody_EncodesBodyAndSetsContentType() async throws {
        // Arrange
        let payload   = DummyResponse(answer: "accepted")
        let stubData  = try JSONEncoder().encode(payload)
        let mock      = MockNetworkClient(stub: .success(stubData))

        let client = OpenAIClient(network: mock, apiKey: apiKey)
        let body   = DummyBody()

        // Act
        let result: DummyResponse = try await client.send(endpoint, body: body)

        // Assert – correct decoding
        XCTAssertEqual(result, payload)

        // Assert – JSON body was encoded and passed to the mock
        guard let bodyData = mock.capturedBody else {
            XCTFail("POST request should carry a body"); return
        }
        let bodyJSON = try JSONSerialization.jsonObject(with: bodyData) as? [String:String]
        XCTAssertEqual(bodyJSON?["foo"], "bar")

        // Assert – Content-Type header was added
        XCTAssertEqual(mock.capturedHeaders?["Content-Type"], "application/json")
    }

    // MARK: 3️⃣ Decoding failure propagates
    func test_send_InvalidJSON_ThrowsDecodingError() async {
        // Arrange – return *malformed* JSON
        let mock = MockNetworkClient(stub: .success(Data("💣".utf8)))
        let client = OpenAIClient(network: mock, apiKey: apiKey)

        // Act / Assert
        do {
            _ = try await client.send(endpoint) as DummyResponse
            XCTFail("Expected JSON decoding to fail")           // should never reach here
        } catch {
            XCTAssertTrue(error is DecodingError,
                          "Expected JSON decoding to fail, got \(error)")
        }
    }
}
