//
//  SequenceNetworkClient.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//

import Networking
import Foundation

// -----------------------------------------------------------------------------
// SequencedNetworkClient – hands back canned responses in the order received
// -----------------------------------------------------------------------------
final class SequenceNetworkClient: NetworkClient, @unchecked Sendable {

    /// Queue of results to hand back (`Result<Data, Error>` for each call)
    var queue: [Result<Data, Error>]

    /// Records each request so the tests can assert on it if desired
    private(set) var calls: [(method: String, url: URL)] = []

    init(_ sequence: [Result<Data, Error>]) {
        self.queue = sequence
    }

    func get(url: URL, queryItems: [URLQueryItem]?, headers: [String : String]) async throws -> Data {
        calls.append(("GET", url))
        guard !queue.isEmpty else { throw APIError.invalidResponse }
        return try queue.removeFirst().get()
    }

    func post(url: URL, body: Data?, headers: [String : String]) async throws -> Data {
        calls.append(("POST", url))
        guard !queue.isEmpty else { throw APIError.invalidResponse }
        return try queue.removeFirst().get()
    }
}

// -----------------------------------------------------------------------------
// Helper: returns JSON `Data` for the three OpenAI responses we care about
// -----------------------------------------------------------------------------
func makeCreateThreadRunJSON(runID: String, threadID: String) -> Data {
    """
    { "id": "\(runID)", "thread_id": "\(threadID)" }
    """.data(using: .utf8)!
}

func makeRunStatusJSON(_ status: String = "completed") -> Data {
    """
    { "status": "\(status)" }
    """.data(using: .utf8)!
}

func makeThreadMessagesJSON(content: String) -> Data {
    """
    { "data": [ { "role": "assistant", "content": "\(content)" } ] }
    """.data(using: .utf8)!
}
