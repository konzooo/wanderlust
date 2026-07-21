//
//  OpenAI+DTOs.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//

import CoreModels
import Foundation

struct CreateThreadRunRequest: Codable {
    let assistant_id: String
    let thread: Thread
    let stream: Bool

    init(assistant_id: String, userMessage: String) {
        self.assistant_id = assistant_id
        self.thread = .init(messages: [["role": "user", "content": userMessage]])
        self.stream = false
    }
}

struct CreateThreadRunResponse: Codable {
    let id: String
    let thread_id: String
    let object: String?
    let created: Int?
    let status: Status

    enum Status: String, Codable {
        case created
        case queued
        case in_progress
        case completed
        case failed
    }
}

struct ThreadMessagesResponse<Content: Codable>: Codable {
    let data: [Message<Content>]
}

enum AssistantServiceError: Error {
    case failedBuildingURLRequest
    case serializingBody(Error)
    case networking(Error)
    case invalidResponse
    case parsingResponseError(Error)
    case emptyResponse
}

struct Thread: Codable {
    let messages: [[String: String]]
}

struct Message<Content: Codable>: Codable {
    let id: String?
    let role: Role?
    let createdAt: Int?
    let content: Content?
    let assistantId: String?
    let runId: String?
    let threadId: String?

    enum CodingKeys: String, CodingKey {
        case role
        case assistantId = "assistant_id"
        case createdAt = "created_at"
        case id
        case content
        case threadId = "thread_id"
        case runId = "run_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.role        = try container.decodeIfPresent(Role.self, forKey: .role)
        self.assistantId = try container.decodeIfPresent(String.self, forKey: .assistantId)
        self.createdAt   = try container.decodeIfPresent(Int.self, forKey: .createdAt)
        self.id          = try container.decodeIfPresent(String.self, forKey: .id)
        self.runId       = try container.decodeIfPresent(String.self, forKey: .runId)
        self.threadId    = try container.decodeIfPresent(String.self, forKey: .threadId)

        let contentArray = try container.decodeIfPresent([MessageContentBlock].self, forKey: .content)

        if
            let jsonString = contentArray?.first?.text?.value,
            let jsonData = jsonString.data(using: .utf8),
            jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
        {
            do {
                self.content = try JSONDecoder().decode(Content.self, from: jsonData)
            } catch {
                print("❌ Failed to decode TravelItinerary from assistant reply:", error)
                self.content = nil
            }
        } else {
            self.content = nil
        }
    }
}

// Define inline decoding for Assistants v2 text block
struct MessageContentBlock: Codable {
    struct TextValue: Codable {
        let value: String
    }
    let type: String?
    let text: TextValue?
}


enum Role: String, Codable {
    case assistant
    case user
}
