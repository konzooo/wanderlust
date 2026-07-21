//
//  Models.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 2/27/25.
//

import CoreModels
import Foundation

enum OpenAI {
    struct Thread: Codable {
        let messages: [[String: String]]
    }

    struct Message: Codable {
        let id: String?
        let role: Role?
        let createdAt: Int?
        let content: Trip.Itinerary?
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

            // Define inline decoding for Assistants v2 text block
            struct ContentBlock: Codable {
                struct TextValue: Codable {
                    let value: String
                }
                let type: String?
                let text: TextValue?
            }

            let contentArray = try container.decodeIfPresent([ContentBlock].self, forKey: .content)

            if
                let jsonString = contentArray?.first?.text?.value,
                let jsonData = jsonString.data(using: .utf8),
                jsonString.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("{")
            {
                do {
                    self.content = try JSONDecoder().decode(Trip.Itinerary.self, from: jsonData)
                } catch {
                    print("❌ Failed to decode TravelItinerary from assistant reply:", error)
                    self.content = nil
                }
            } else {
                self.content = nil
            }
        }
    }



    enum Role: String, Codable {
        case assistant
        case user
    }

    //    struct Choice: Codable {
    //        let index: Int
    //        let finish_reason: String?
    //        let message: Message
    //    }
}

struct OpenAIThreadMessage: Codable {
    let id: String
    let object: String
    let createdAt: Int
    let threadId: String
    let role: String
    let content: [MessageContent]
    let fileIds: [String]
    let assistantId: String?
    let runId: String?
    let metadata: [String: String]?
    
    struct MessageContent: Codable {
        let type: String
        let text: TextContent?
        
        struct TextContent: Codable {
            let value: String
            let annotations: [String]
        }
    }
}

struct OpenAIThreadMessagesResponse: Codable {
    let object: String
    let data: [OpenAIThreadMessage]
    let firstId: String?
    let lastId: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case object, data, firstId, lastId, hasMore
    }
}

struct OpenAIThreadMessageWithContent: Codable {
    let role: MessageRole
    let content: Trip.Itinerary?
    
    enum MessageRole: String, Codable {
        case user
        case assistant
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(MessageRole.self, forKey: .role)
        
        // Try to decode content as Trip.Itinerary
        if let contentString = try? container.decode(String.self, forKey: .content),
           let jsonData = contentString.data(using: .utf8) {
            self.content = try JSONDecoder().decode(Trip.Itinerary.self, from: jsonData)
        } else {
            self.content = nil
        }
    }
}
