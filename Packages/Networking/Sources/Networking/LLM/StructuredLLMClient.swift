import Foundation

public typealias StructuredLLMAPIKeyProvider = @Sendable () throws -> String

/// The small boundary the app uses for any LLM provider that supports JSON output.
/// Provider-specific response envelopes are removed before data crosses this boundary.
public protocol StructuredLLMClient: Sendable {
    func generate(
        systemPrompt: String,
        userPrompt: String,
        outputSchema: JSONValue,
        maxOutputTokens: Int
    ) async throws -> Data
}
