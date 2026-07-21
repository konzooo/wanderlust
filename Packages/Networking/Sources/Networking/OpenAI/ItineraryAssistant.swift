//  AssistantService.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//

import CoreModels
import Foundation

///// Protocol defining the interface for the Assistant Service
public protocol AssistantServiceProtocol {
    associatedtype Content: Codable
    
    /// Sends a user message to the assistant and returns a fully-decoded TravelItinerary
    /// - Parameter userMessage: The message from the user
    /// - Returns: A TravelItinerary object containing the assistant's response
    func run(userMessage: String) async throws -> Content
    
    func set(openAIClient: OpenAIClient)
}

/// High-level workflow service that drives the Assistants v2 API to realize
/// an end-to-end conversation: create thread → run assistant → poll until
/// done → extract final itinerary (TravelItinerary)
public final class ItineraryAssistant<Content: Codable>: AssistantServiceProtocol {
    private var openAIClient: OpenAIClient
    private var assistantId: String
    
    public init(openAIClient: OpenAIClient, assistantId: String) {
        self.openAIClient = openAIClient
        self.assistantId = assistantId
    }
    
    public func run(userMessage: String) async throws -> Content {
        // 1. Create a thread with the user data and run the thread
        let runResponse: CreateThreadRunResponse = try await openAIClient.send(
            .createThreadAndRun,
            body: CreateThreadRunRequest(assistant_id: assistantId, userMessage: userMessage)
        )
        /// validate run is in progress
        
        guard !runResponse.id.isEmpty, !runResponse.thread_id.isEmpty else {
            throw AssistantServiceError.invalidResponse
        }
        
        // 2. Poll the thread untill the assistant proccessed the user data
        return try await pollThreadMessage(runId: runResponse.id, threadId: runResponse.thread_id)
    }
    
    public func set(openAIClient: OpenAIClient) {
        self.openAIClient = openAIClient
    }
}

private extension ItineraryAssistant {
    func pollThreadMessage(runId: String, threadId: String) async throws -> Content {
        let maxAttempts = 30
        let delaySeconds = 2.0

        for _ in 0..<maxAttempts {
            // 1) Check run status or fetch messages
            let runOrThreadResponse: [String: AnyDecodable] = try await openAIClient.send(.runThread(thread: threadId, run: runId))

            // If using run status:
            let status = runOrThreadResponse["status"]?.value as? String

            if let status {
                if status == "completed" {
                    // Completed, so now we can parse the messages
                    return try await fetchAssistantReply(threadId: threadId)
                } else if status == "failed" {
                    throw AssistantServiceError.invalidResponse
                }
                // If status == "queued" or "running", keep polling
            }
            
            // 2) Wait 1 second, then poll again
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        throw AssistantServiceError.invalidResponse
    }

    /// If the run completed, you can fetch messages from the thread:
    func fetchAssistantReply(threadId: String) async throws -> Content {
        let response: ThreadMessagesResponse<Content> = try await openAIClient.send(.threadMessages(thread: threadId))
        
        for message in response.data {
            if message.role == .assistant, let itinerary = message.content {
                return itinerary
            }
        }

        throw AssistantServiceError.emptyResponse
    }
}
