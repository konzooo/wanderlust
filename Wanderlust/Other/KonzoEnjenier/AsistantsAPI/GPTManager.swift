//
//  GPTManager.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 08.01.25.
//


import SwiftUI
import Foundation

// MARK: - AssistantRunResponse Model
struct AssistantRunResponse: Decodable {
    struct Message: Decodable {
        let content: String?
    }
    let messages: [Message]
}

// MARK: - GPTManager (Combined Service and ViewModel)
class GPTManager: ObservableObject {
    // MARK: - Published Properties (State)
    @Published var userInput: String = ""
    @Published var gptResponse: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - API Configuration
    private let apiKey = "REDACTED_OPENAI_KEY_2"
    private let assistantID = "asst_V9luBiG8WYLGWy4Ey5NkNFcs" // Replace with your actual Assistant ID
    private let threadsEndpoint = "https://api.openai.com/v1/threads"

    // MARK: - Send Message to GPT
    func sendMessageToGPT() {
        isLoading = true
        errorMessage = nil
        
        createThread { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let threadID):
                    self?.runAssistant(threadID: threadID, userMessage: self?.userInput ?? "")
                case .failure(let error):
                    self?.isLoading = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Create Thread
    func createThread(completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: threadsEndpoint) else {
            print("❌ Invalid URL")
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }

        print("🚀 Creating Thread at: \(url)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta") // Required Beta Header
        
        let body: [String: Any] = [
            "messages": [
                ["role": "user", "content": "Start a conversation"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        print("📤 Request Body: \(body)")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            guard let data = data else {
                print("❌ No data received")
                completion(.failure(NSError(domain: "No data", code: -2, userInfo: nil)))
                return
            }

            // Print raw response
            print("📥 Raw Response: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Parsed JSON: \(json)")
                    if let threadID = json["id"] as? String {
                        print("✅ Thread Created with ID: \(threadID)")
                        completion(.success(threadID))
                    } else {
                        print("❌ 'id' not found in response JSON")
                        completion(.failure(NSError(domain: "Thread ID not found", code: -3, userInfo: nil)))
                    }
                } else {
                    print("❌ JSON Parsing failed")
                    completion(.failure(NSError(domain: "JSON Parsing failed", code: -4, userInfo: nil)))
                }
            } catch {
                print("❌ JSON Decoding Error: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Run Assistant
    private func runAssistant(threadID: String, userMessage: String) {
        guard let url = URL(string: "\(threadsEndpoint)/\(threadID)/runs") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta") // Required Beta Header

        let body: [String: Any] = [
            "assistant_id": assistantID,
            "instructions": "Provide a detailed response based on user input."
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        print("🚀 Running Assistant on Thread ID: \(threadID)")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("❌ Network error: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received"
                    print("❌ No data received")
                    return
                }

                // Print the raw response for debugging
                print("📥 Raw Run Response: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    print("✅ Parsed Run JSON: \(String(describing: json))")
                    
                    if let runID = json?["id"] as? String {
                        print("✅ Run Created with ID: \(runID)")
                        self.fetchRunStatus(threadID: threadID, runID: runID)
                    } else {
                        self.errorMessage = "Failed to parse Run ID"
                        print("❌ Run ID not found in JSON")
                    }
                } catch {
                    self.errorMessage = "Failed to decode response: \(error.localizedDescription)"
                    print("❌ JSON Decoding Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    private func fetchRunStatus(threadID: String, runID: String) {
        guard let url = URL(string: "\(threadsEndpoint)/\(threadID)/runs/\(runID)") else {
            errorMessage = "Invalid URL for Run Status"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta") // Required Beta Header

        print("🚀 Fetching Run Status for Run ID: \(runID)")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("❌ Network error: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    self.errorMessage = "No data received while fetching run status"
                    print("❌ No data received while fetching run status")
                    return
                }

                // Print the raw response for debugging
                print("📥 Raw Run Status Response: \(String(data: data, encoding: .utf8) ?? "Invalid Data")")

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        print("✅ Parsed Run Status JSON: \(json)")

                        if let status = json["status"] as? String {
                            switch status {
                            case "completed":
                                if let messages = json["messages"] as? [[String: Any]],
                                   let messageContent = messages.first?["content"] as? String {
                                    self.gptResponse = messageContent
                                    print("✅ Assistant Reply: \(messageContent)")
                                } else {
                                    self.errorMessage = "No valid messages found in response"
                                    print("❌ No valid messages found in response")
                                }
                            case "in_progress":
                                print("⏳ Run still in progress, retrying...")
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    self.fetchRunStatus(threadID: threadID, runID: runID)
                                }
                            default:
                                self.errorMessage = "Unexpected status: \(status)"
                                print("❌ Unexpected status: \(status)")
                            }
                        } else {
                            self.errorMessage = "Missing status field in run status response"
                            print("❌ Missing status field in JSON")
                        }
                    } else {
                        self.errorMessage = "Failed to parse JSON response"
                        print("❌ Failed to parse JSON response")
                    }
                } catch {
                    self.errorMessage = "Failed to decode run status: \(error.localizedDescription)"
                    print("❌ JSON Decoding Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
    }
