import CoreModels
import Foundation

class OpenAIService {
    func processCompletions(data: String) async throws -> String {
        // 1. Build the URLRequest
        guard var request = URLRequest.GPTCompletionsPOST else {
            throw OpenAIServiceError.failedBuildingURLRequest
        }

        // 2. Construct the request body
        let body = buildCompletionsBody(withPromt: data)
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            throw OpenAIServiceError.serializingBody(error)
        }

        // 3. Execute the network call using async/await
        let (data, response) = try await URLSession.shared.data(for: request)

        // 4. Validate the HTTP response
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIServiceError.invalidResponse
        }

        // 5. Parse the response
        var parsedJSON: [String: Any]?
        do {
            parsedJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            print("Raw JSON Response: \(String(describing: parsedJSON))") // Debugging
        } catch {
            throw OpenAIServiceError.parsingResponseError(error)
        }

        // 6. Extract the content from the JSON
        return try validate(completionsResponse: parsedJSON)
    }

    func processAssistants(data: String) async throws -> Trip.Itinerary {
        // 1. Create a thread with the user data and run the thread
        let runResponse = try await createAndRunThread(assistantId: Constants.assistantID, userContent: data)
        /// validate run is in progress

        guard !runResponse.id.isEmpty, !runResponse.thread_id.isEmpty else {
            throw OpenAIServiceError.invalidResponse
        }

        // 2. Poll the thread untill the assistant proccessed the user data
        return try await pollForCompletion(runId: runResponse.id, threadId: runResponse.thread_id)
    }

    /// Creates and runs a thread in a single async call:
    /// - Sends the user's initial message
    ///
    /// - Parameters:
    ///   - assistantId: The ID of the assistant.
    ///   - title: Title for the new thread.
    ///   - userContent: The user’s initial message.
    /// - Returns: The assistant’s reply (as a String).
    /// - Throws: Networking or decoding errors.
    func createAndRunThread(
        assistantId: String,
        userContent: String
    ) async throws -> OpenAI.CreateThreadRunResponse {
        // 1. Prepare the URL
        guard var request = URLRequest.assistantsPOST else {
            throw OpenAIServiceError.failedBuildingURLRequest
        }

        // 3. Create body
        let body = OpenAI.CreateThreadRunRequest(assistant_id: assistantId, userMessage: userContent)

        // 4. Encode and assign to request
        let encodedBody = try JSONEncoder().encode(body)
        request.httpBody = encodedBody

        // 5. Make the request (async/await)
        let (data, response) = try await URLSession.shared.data(for: request)

        if let bodyString = String(data: data, encoding: .utf8) {
            print("\n+++++ Response body: \(bodyString)\n\n")
        }
        // 6. Validate response
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw OpenAIServiceError.invalidResponse
        }

        // 7. Decode JSON and return Response
        do {
            return try JSONDecoder().decode(OpenAI.CreateThreadRunResponse.self, from: data)
        } catch {
            throw OpenAIServiceError.parsingResponseError(error)
        }
    }
}

extension OpenAIService {
    fileprivate func buildCompletionsBody(withPromt prompt: String) -> [String: Any] {
        [
            "model": "gpt-3.5-turbo", // Use gpt-4 if you have access
            "messages": [
                ["role": "system", "content": Constants.openAIInitialConfiguration],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150,
            "temperature": 0.7
        ]
    }

    private func validate(completionsResponse: [String: Any]?) throws -> String {
        if let choices = completionsResponse?["choices"] as? [[String: Any]],
           let firstChoice = choices.first,
           let message = firstChoice["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content
        } else {
            throw OpenAIServiceError.emptyResponse
        }
    }
}

enum OpenAIServiceError: Error {
    case failedBuildingURLRequest
    case serializingBody(Error)
    case networking(Error)
    case invalidResponse
    case parsingResponseError(Error)
    case emptyResponse
}

extension OpenAIService {
    enum Constants {
        static let APIKey = "REMOVED_OPENAI_KEY"
        static let assistantID = "asst_TcB4WiN4enei0jZRqShdJZW6"
//        static let assistantID = "asst_6eZs6kr3eOhrhl03aBfRu5Pu"
        static let openAIInitialConfiguration = """
    You are a helpful travel assistant and you will get input about the user preference to customize your answers. The data points are answers from the user. The output should be a travel itinary. Input: You will receive the input on a)basic information and b)personal answers for the questions on personality and preferences.The output should be cool movie-like title of the trip + a travel itinerary separated by day. The input format:
    a)Basic information:Travel Destination, Group size/mode, No. Days, month of the year.
    b)Questions: all questions contain two extremes. [answer options can be: "Left", "Right" or "Both"]
    Questions:
    1. Trusted favorites or dive into the unknown?
    2. Ancient Ruins or futuristic cityscapes?
    3. Dancing till sunrise or chill evenings?
    4. On a budget or happy to spend?
    5. Experience the culture of the city or the beauty of the landscapes?
    6. Iconic Landmarks or off the beaten path?
    7. Disconnect & unwind or excitement & adventure?
    8. Local street food or fine dining?
    """
    }
}

extension OpenAIService.Constants {
    enum URL: String {
        case openAICompletionsURL = "https://api.openai.com/v1/chat/completions"
        case assistants = "https://api.openai.com/v1/assistants"
        case createThread = "https://api.openai.com/v1/threads"
        case runThread = "https://api.openai.com/v1/threads/<thread_id>/runs/<run_id>"
        case createAndRunThread = "https://api.openai.com/v1/threads/runs"
        case messagesThread = "https://api.openai.com/v1/threads/<thread_id>/messages"
        case threadRun = "https://api.openai.com/v1/threads/runs/<run_id>"
    }
}

// MARK: - Polling Assistants Thread
extension OpenAIService {
    func pollForCompletion(runId: String, threadId: String) async throws -> Trip.Itinerary {
        let maxAttempts = 30
        let delaySeconds = 2.0

        for _ in 0..<maxAttempts {
            // 1) Check run status or fetch messages
            let runOrThreadResponse = try await getRunStatusOrThreadMessages(runId: runId, threadId: threadId)

            // If using run status:
            let status = runOrThreadResponse["status"] as? String

            if let status {
                if status == "completed" {
                    // Completed, so now we can parse the messages
                    return try await fetchFinalAssistantReply(threadId: threadId)
                } else if status == "failed" {
                    throw OpenAIServiceError.invalidResponse
                }
                // If status == "queued" or "running", keep polling
            }
            // 2) Wait a bit, then poll again
            try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        }

        throw OpenAIServiceError.invalidResponse
    }

    func getRunStatusOrThreadMessages(runId: String, threadId: String) async throws -> [String: Any] {
        // Example: GET /v1/threads/runs/{run_id}
        // or you can do GET /v1/threads/{thread_id}/messages
        guard let request = URLRequest.assistantRunGET(runID: runId, threadID: threadId) else {
            throw OpenAIServiceError.failedBuildingURLRequest
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw OpenAIServiceError.invalidResponse
        }
        return dict
    }

    /// If the run completed, you can fetch messages from the thread:
    func fetchFinalAssistantReply(threadId: String) async throws -> Trip.Itinerary {
        guard let request = URLRequest.assistantMessagesGET(threadId) else { throw OpenAIServiceError.failedBuildingURLRequest }

        let (data, _) = try await URLSession.shared.data(for: request)

        debugPrintAssistantTextValue(from: data)
        
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard let dict = json as? [String: Any] else {
            throw OpenAIServiceError.invalidResponse
        }
        print(dict)

        guard let dataArray = dict["data"] as? [[String: Any]] else {
            throw OpenAIServiceError.emptyResponse
        }

        // Find the last assistant message
        if let assistantMsg = dataArray.last(where: { $0["role"] as? String == "assistant" }),
           let content = assistantMsg["content"] as? String {
            print(content)
        }

        do {
            let apiResponse = try JSONDecoder().decode(OpenAI.ThreadMessagesResponse.self, from: data)
            for message in apiResponse.data {
                if message.role == .assistant, let itinerary = message.content {
                    return itinerary
                }
            }
        } catch {
            print("Decoding failed:", error)
        }

        throw OpenAIServiceError.emptyResponse
    }
}

func debugPrintAssistantTextValue(from data: Data) {
    do {
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        guard
            let dict = json as? [String: Any],
            let messages = dict["data"] as? [[String: Any]],
            let assistantMessage = messages.first(where: { $0["role"] as? String == "assistant" }),
            let content = assistantMessage["content"] as? [[String: Any]],
            let text = content.first?["text"] as? [String: Any],
            let rawValue = text["value"] as? String
        else {
            print("⚠️ Assistant reply not found or malformed")
            return
        }

        print("📦 Raw assistant content text.value:\n\(rawValue)")
    } catch {
        print("❌ Failed to parse assistant response:", error)
    }
}
