//
//  OpenAIClient.swift
//  Networking
//
//  Created by Rodrigo Mato on 16/6/25.
//

import Foundation

public typealias APIKeyProvider = () throws -> String

/// `OpenAIEndpoint` + request model into an authenticated HTTP call through the generic
///  `NetworkClient`, then decodes the JSON response.
///
/// Key responsibilities:
/// 1. **Authentication** – injects the `Authorization` header using the API key
///    supplied at init time.
/// 2. **(De)serialisation** – delegates request encoding to a `BodyEncoder`
///    (defaults to `JSONBodyEncoder`) and uses a `JSONDecoder` for responses.
/// 3. **Endpoint routing** – picks the correct HTTP verb based on the endpoint
///    metadata (`GET` vs `POST`).
///
/// **Thread‑Safety**: The type is stateless after construction (all dependencies
/// are value‑types or immutable) and therefore thread‑safe for concurrent use.
///
/// **Unit‑Testing**: Inject a mock implementation of `NetworkClient` that
/// returns canned `Data` to test higher‑level services without hitting the
/// network.
public final class OpenAIClient {
    // MARK: Dependencies
    private let network: NetworkClient
    private let encoder: BodyEncoder
    private let decoder: JSONDecoder
    
    // MARK: Configuration
    private let keyProvider: APIKeyProvider
    private let baseURL = URL(string: "https://api.openai.com/v1")!
    
    /// Designated initializer.
    /// - Parameters:
    ///   - network: Concrete implementation of `NetworkClient`. Defaults to
    ///               `APIClient()` which uses `URLSession`.
    ///   - encoder: Strategy used to encode the request body. Defaults to
    ///              `JSONBodyEncoder()`.
    ///   - decoder: Strategy used to decode the JSON response. Defaults to a
    ///              plain `JSONDecoder()`.
    ///   - apiKey:  Secret key used for the `Authorization` header.
    public init(
        network: NetworkClient = APIClient(),
        encoder: BodyEncoder = JSONBodyEncoder(),
        decoder: JSONDecoder = .init(),
        keyProvider: @escaping APIKeyProvider
    ) {
        self.network = network
        self.encoder = encoder
        self.decoder = decoder
        self.keyProvider = keyProvider
    }

//    request.httpMethod = httpMethod
//    request.addValue("Bearer \(OpenAIService.Constants.APIKey)", forHTTPHeaderField: "Authorization")
//    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
//    request.setValue("assistants=v2", forHTTPHeaderField: "OpenAI-Beta")


    /// Sends a request to the given **OpenAI** endpoint and decodes the result.
    ///
    /// - Parameters:
    ///   - endpoint: The target `OpenAIEndpoint` value that describes the path
    ///               and HTTP method.
    ///   - body:     Optional request body conforming to `Encodable`. Pass `nil`
    ///               for `GET` requests or endpoints that don't require a body.
    /// - Returns: A value of type `R`, decoded from the JSON response.
    /// - Throws:  `APIError` values thrown by `NetworkClient`, any error thrown
    ///            by the `BodyEncoder`, or `DecodingError` from the decoder.
    public func send<B: Encodable, R: Decodable>(
        _ endpoint: OpenAIEndpoint,
        body: B? = nil
    ) async throws -> R {
        let url = baseURL.appendingPathComponent(endpoint.path)
        var headers: [String: String] = [
            "Authorization": "Bearer \(try keyProvider())",
            "OpenAI-Beta": "assistants=v2"
        ]

        // Encode optional body
        let bodyData: Data?
        if let body {
            let (data, contentType) = try encoder.encode(body)
            bodyData = data
            headers["Content-Type"] = contentType
            
            // Debug logging
            print("🔍 Request Details:")
            print("URL: \(url)")
            print("Headers: \(headers)")
            if let bodyString = String(data: data, encoding: .utf8) {
                print("Body: \(bodyString)")
            }
            
        } else {
            bodyData = nil
        }

        // Fire the request
        let raw: Data = switch endpoint.method {
        case .post: try await network.post(url: url, body: bodyData, headers: headers)
        case .get:  try await network.get (url: url, queryItems: nil, headers: headers)
        }

        // Debug logging for response
        print("📥 Response Details:")
        if let responseString = String(data: raw, encoding: .utf8) {
            print("Response: \(responseString)")
        }
        return try decoder.decode(R.self, from: raw)
    }

    // -> Convenience overload for GETs with *no* request body
    /// Sends a request to `endpoint` that does **not** require
    /// an HTTP body (all GETs, some POSTs).
    ///
    /// Swift can now infer the return type `R` without guessing
    /// what the generic body type `B` should be, eliminating the
    /// " *generic parameter 'B' could not be inferred* " error.
    public func send<R: Decodable>(
        _ endpoint: OpenAIEndpoint
    ) async throws -> R {
        try await send(endpoint, body: Optional<EmptyBody>.none)
    }

    /// Trivial marker used when no request body is needed.
    private struct EmptyBody: Encodable {}}
