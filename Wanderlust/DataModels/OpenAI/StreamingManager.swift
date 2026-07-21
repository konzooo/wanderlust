//
//  StreamingManager.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 2/24/25.
//

import Foundation

/// Usage
///
/// // Callbacks
/// streamer.onMessage = { partialText in
///     print("Received partial text: \(partialText)")
/// }
///
/// streamer.onError = { error in
///     print("Error streaming: \(error)")
/// }
///
/// streamer.onComplete = {
///     print("Stream completed.")
/// }
///
/// // Start the stream
/// streamer.startStreamingThreadRun(content: content)
///
final class ThreadRunStreamingManager: NSObject {

    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?

    // We keep an incremental buffer to handle partial SSE lines
    private var partialDataBuffer = Data()

    // A simple callback that we’ll call whenever we parse a new message chunk
    var onMessage: ((String) -> Void)?

    // A callback if we encounter an error
    var onError: ((Error) -> Void)?

    // A callback when streaming finishes
    var onComplete: (() -> Void)?

    func startStreamingThreadRun(content: String) {
        // 1) Build the URL
        guard let url = URL(string: "https://api.openai.com/v1/threads/runs") else {
            print("Invalid URL")
            return
        }

        // 2) Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Your actual API key, Beta header, etc.
        request.setValue("Bearer \(OpenAIService.Constants.APIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // If required for the Beta
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")

        // 3) The JSON body with `stream = true`
        let body: [String: Any] = [
            "assistant_id": "asst_FituBLdHrZnwIZ2WCUM1ZjW2",
            "thread": [
                "messages": [
                    ["role": "user", "content": content]
                ]
            ],
            "stream": true
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            print("Failed to encode JSON body: \(error)")
            return
        }

        // 4) Create a custom URLSession with self as the delegate
        let config = URLSessionConfiguration.default
        // In some cases you may want config.timeoutIntervalForRequest = ...

        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        // 5) Create the data task
        self.dataTask = urlSession?.dataTask(with: request)

        // 6) Start the task
        self.dataTask?.resume()
    }

    func stopStreaming() {
        dataTask?.cancel()
        urlSession?.invalidateAndCancel()
        dataTask = nil
        urlSession = nil
    }
}

// MARK: - URLSessionDataDelegate
extension ThreadRunStreamingManager: URLSessionDataDelegate {
    // Called when the server sends *partial* data chunks
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Append to our buffer
        partialDataBuffer.append(data)

        // Process the buffer line-by-line for SSE
        while true {
            // Convert to string, see if we have a full line
            if let range = partialDataBuffer.range(of: "\n".data(using: .utf8)!) {

                // Extract one line
                let lineData = partialDataBuffer.subdata(in: 0..<range.lowerBound)

                // Remove that line + the newline from the buffer
                partialDataBuffer.removeSubrange(0..<range.upperBound)

                if let line = String(data: lineData, encoding: .utf8) {
                    // Handle the SSE line (e.g., "data: {...}")
                    handleSSELine(line)
                }
            } else {
                // No more full lines in the buffer
                break
            }
        }
    }

    // Called on completion or error
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let err = error, (err as NSError).code != NSURLErrorCancelled {
            // Some real error (like a network error)
            onError?(err)
        } else {
            // Task finished (server closed the stream or we cancelled)
            onComplete?()
        }

        // Clean up
        urlSession?.invalidateAndCancel()
        dataTask = nil
        urlSession = nil
    }

    /// Parse each SSE line. Typically the format is `data: {...}` or `event: foo`.
    /// For standard OpenAI streaming, lines often look like:
    ///
    /// data: {"id":"...","object":"...","choices":[{"delta":{"content":"..."}}]}
    ///
    private func handleSSELine(_ line: String) {
        // SSE lines can have `event:` or `data:`. Some might be empty "heartbeat".
        // For example, if line starts with "data: "
        print("\n SEE Line: \n\(line)\n")
        guard line.hasPrefix("data: ") else {
            // Could be empty or "event: ...", handle if needed
            return
        }

        // Remove the "data: " prefix
        let jsonString = String(line.dropFirst("data: ".count))

        // OpenAI sometimes sends [DONE] to indicate the end
        if jsonString == "[DONE]" {
            onComplete?()
            stopStreaming()
            return
        }

        // Otherwise, parse the JSON
        guard let jsonData = jsonString.data(using: .utf8) else { return }
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: [])
            // Cast to dictionary if you want to parse fields, e.g. the "content"
            if let dict = jsonObject as? [String: Any] {
                // e.g. extract partial content from "choices[0].delta.content"
                if
                    let choices = dict["choices"] as? [[String: Any]],
                    let delta  = choices.first?["delta"] as? [String: Any],
                    let content = delta["content"] as? String
                {
                    onMessage?(content)
                }
            }
        } catch {
            print("Failed to parse SSE JSON: \(error)\nLine was: \(jsonString)")
        }
    }
}
