//
//  OpenbAIAPI.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 2/23/25.
//

import Foundation

extension OpenAI {
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

    struct ThreadMessagesResponse: Codable {
        let data: [Message]
    }
}
