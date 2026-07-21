//
//  URLRequest+OpenAI.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 2/23/25.
//
import Foundation

extension URLRequest {
    static var GPTCompletionsPOST: Self? {
        guard let url = URL(string: OpenAIService.Constants.URL.openAICompletionsURL.rawValue) else {
            print("failed to create completions url")
            return nil
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(OpenAIService.Constants.APIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    static var assistantsPOST: Self? {
        guard let url = URL(string: OpenAIService.Constants.URL.createAndRunThread.rawValue) else {
            print("failed to create Assistants url")
            return nil
        }

        return assistantsRequest(url: url, httpMethod: "POST")
    }

    static func messageThreadPOST(_ threadID: String) -> Self? {
        let originalUrl = OpenAIService.Constants.URL.messagesThread.rawValue
        let replacedUrl = originalUrl.replacingOccurrences(of: "<thread_id>", with: threadID)

        guard let url = URL(string: replacedUrl) else {
            print("failed to create messages-run url")
            return nil
        }

        return assistantsRequest(url: url, httpMethod: "POST")
    }

    static func assistantMessagesGET(_ threadID: String) -> Self? {
        let originalUrl = OpenAIService.Constants.URL.messagesThread.rawValue
        let replacedUrl = originalUrl.replacingOccurrences(of: "<thread_id>", with: threadID)

        guard let url = URL(string: replacedUrl) else {
            print("failed to create messages url")
            return nil
        }

        return assistantsRequest(url: url, httpMethod: "GET")
    }

    static func assistantRunGET(runID: String, threadID: String) -> Self? {
        let originalUrl = OpenAIService.Constants.URL.runThread.rawValue
        var replacedUrl = originalUrl.replacingOccurrences(of: "<run_id>", with: runID)
        replacedUrl = replacedUrl.replacingOccurrences(of: "<thread_id>", with: threadID)

        guard let url = URL(string: replacedUrl) else {
            print("failed to create Run url")
            return nil
        }

        return assistantsRequest(url: url, httpMethod: "GET")
    }

    private static func assistantsRequest(url: URL, httpMethod: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod
        request.addValue("Bearer \(OpenAIService.Constants.APIKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")
        return request
    }
}
