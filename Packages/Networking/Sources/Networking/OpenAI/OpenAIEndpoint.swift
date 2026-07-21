//
//  OpenAIEndpoint.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//

// MARK: - OpenAI Endpoint Catalogue
public enum OpenAIEndpoint {
    case chatCompletions
    case assistants
    case createThread
    case createThreadAndRun
    case runThread(thread: String, run: String)
    case threadMessages(thread: String)
    case threadRun(run: String)

    var path: String {
        switch self {
        case .chatCompletions: return "chat/completions"
        case .assistants: return "assistants"
        case .createThread: return "threads"
        case .createThreadAndRun: return "threads/runs"
        case let .runThread(thread, run): return "threads/\(thread)/runs/\(run)"
        case let .threadMessages(thread): return "threads/\(thread)/messages"
        case let .threadRun(run): return "threads/runs/\(run)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .chatCompletions, .assistants, .createThread, .createThreadAndRun, .threadRun:
            return .post
        case .runThread, .threadMessages:
            return .get
        }
    }
}
