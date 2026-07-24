import Foundation

/// OpenAI Responses API adapter. The app only depends on `StructuredLLMClient`.
public struct OpenAIResponsesClient: StructuredLLMClient {
    public struct Configuration: Equatable, Sendable {
        public var model: String
        public var baseURL: URL

        public init(
            model: String = "gpt-4o-mini",
            baseURL: URL = URL(string: "https://api.openai.com/v1")!
        ) {
            self.model = model
            self.baseURL = baseURL
        }
    }

    private let network: any NetworkClient
    private let configuration: Configuration
    private let keyProvider: StructuredLLMAPIKeyProvider

    public init(
        network: any NetworkClient = APIClient(),
        configuration: Configuration = .init(),
        keyProvider: @escaping StructuredLLMAPIKeyProvider
    ) {
        self.network = network
        self.configuration = configuration
        self.keyProvider = keyProvider
    }

    public func generate(
        systemPrompt: String,
        userPrompt: String,
        outputSchema: JSONValue,
        maxOutputTokens: Int
    ) async throws -> Data {
        let request = ResponseRequest(
            model: configuration.model,
            instructions: systemPrompt,
            input: userPrompt,
            maxOutputTokens: maxOutputTokens,
            store: false,
            text: .init(
                format: .init(
                    type: "json_schema",
                    name: "wanderlust_trip_output",
                    schema: outputSchema,
                    strict: true
                )
            )
        )

        let body = try JSONEncoder().encode(request)
        let responseData = try await network.post(
            url: configuration.baseURL.appendingPathComponent("responses"),
            body: body,
            headers: [
                "Authorization": "Bearer \(try keyProvider())",
                "Content-Type": "application/json"
            ]
        )

        let response = try JSONDecoder().decode(ResponseEnvelope.self, from: responseData)
        if response.status == "incomplete" {
            throw OpenAIResponsesClientError.outputIncomplete(response.incompleteDetails?.reason)
        }

        let content = response.output.flatMap(\.content)
        if let refusal = content.compactMap(\.refusal).first {
            throw OpenAIResponsesClientError.refused(refusal)
        }
        guard let text = content.first(where: { $0.type == "output_text" })?.text else {
            throw OpenAIResponsesClientError.missingTextContent
        }

        let structuredData = Data(text.utf8)
        guard (try? JSONSerialization.jsonObject(with: structuredData)) != nil else {
            throw OpenAIResponsesClientError.invalidStructuredOutput
        }
        return structuredData
    }
}

public enum OpenAIResponsesClientError: Error, Equatable, LocalizedError {
    case refused(String)
    case outputIncomplete(String?)
    case missingTextContent
    case invalidStructuredOutput

    public var errorDescription: String? {
        switch self {
        case .refused:
            return "OpenAI refused the request."
        case .outputIncomplete(let reason):
            return "OpenAI returned an incomplete response\(reason.map { ": \($0)" } ?? ".")"
        case .missingTextContent:
            return "OpenAI returned no text content."
        case .invalidStructuredOutput:
            return "OpenAI returned text that was not valid JSON."
        }
    }
}

private extension OpenAIResponsesClient {
    struct ResponseRequest: Encodable {
        let model: String
        let instructions: String
        let input: String
        let maxOutputTokens: Int
        let store: Bool
        let text: TextConfiguration

        enum CodingKeys: String, CodingKey {
            case model
            case instructions
            case input
            case maxOutputTokens = "max_output_tokens"
            case store
            case text
        }
    }

    struct TextConfiguration: Encodable {
        let format: ResponseFormat
    }

    struct ResponseFormat: Encodable {
        let type: String
        let name: String
        let schema: JSONValue
        let strict: Bool
    }

    struct ResponseEnvelope: Decodable {
        let status: String?
        let incompleteDetails: IncompleteDetails?
        let output: [OutputItem]

        enum CodingKeys: String, CodingKey {
            case status
            case incompleteDetails = "incomplete_details"
            case output
        }
    }

    struct IncompleteDetails: Decodable {
        let reason: String?
    }

    struct OutputItem: Decodable {
        let content: [OutputContent]

        enum CodingKeys: String, CodingKey {
            case content
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decodeIfPresent([OutputContent].self, forKey: .content) ?? []
        }
    }

    struct OutputContent: Decodable {
        let type: String
        let text: String?
        let refusal: String?
    }
}
