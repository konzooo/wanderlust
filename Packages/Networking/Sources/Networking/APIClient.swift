//
//  APIClient.swift
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

/// API-level errors that might occur during HTTP operations.
public enum APIError: Error {
    /// Thrown when the response's HTTP status code is not in the acceptable range.
    case invalidStatusCode(Int)

    /// Thrown for generic or underlying errors.
    case genericError(Error)

    /// Thrown when the response body is missing, malformed, or empty
    case invalidResponse
}

/// Concrete NetworkClient that uses `URLSession` for network requests.
public final class APIClient: NetworkClient {

    /// The URLSession used for all HTTP requests.
    private let session: URLSession

    /// Designated initializer, allowing injection of a custom URLSession
    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Performs GET request to the given URL and returns raw `Data`.
    /// - Parameters:
    ///   - url: The endpoint for the GET request.
    ///   - queryItems: Optional array of URLQueryItem to append to the URL.
    ///   - headers: Dictionary of custom header fields to include in the request.
    /// - Returns: The raw `Data` from the response.
    /// - Throws: An `APIError` if the response status code is invalid or if the request fails.
    public func get(url: URL, queryItems: [URLQueryItem]? = nil, headers: [String: String] = [:]) async throws -> Data {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        
        guard let finalURL = components?.url else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        
        // Assign headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)

            try validateStatusCode(from: response)

            return data
        } catch {
            throw APIError.genericError(error)
        }
    }

    /// Performs a POST request with optional request body and headers.
    /// - Parameters:
    ///   - url: url endpoint for the POST request.
    ///   - body: Optional data to send in the request body.
    ///   - headers: Dictionary of custom header fields to include in the request.
    /// - Returns: The raw `Data` from the response.
    /// - Throws: An `APIError` if the response status code is invalid or if the request fails
    public func post(url: URL, body: Data? = nil, headers: [String : String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Assign headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        // Assign the request body if available
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)

            try validateStatusCode(from: response)

            return data
        } catch {
            throw APIError.genericError(error)
        }
    }
}

private extension APIClient {
    /// Checks the HTTP status code to ensure it falls within the valid success range.
    /// - Parameter response: The URLResponse
    /// - Throws: `APIError.invalidStatusCode` if the status code is outside `200...299`.
    private func validateStatusCode(from response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        let statusCode = httpResponse.statusCode
        // Considering 200...299 as "successful"
        guard (200...299).contains(statusCode) else {
            throw APIError.invalidStatusCode(statusCode)
        }
    }
}
