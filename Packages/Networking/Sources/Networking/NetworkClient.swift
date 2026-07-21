//
//  NetworkClient.swift
//  CoreDependencies
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

/// NetworkClient abstraction encapsulating basic HTTP operations:
/// - `get(url:)` for sending GET requests
/// - `post(url:body:headers:)` for sending POST requests
///
/// Note: we can expand this to include PUT, DELETE, or any other HTTP methods as needed.
public protocol NetworkClient: Sendable {
    /// Performs an HTTP GET request for a given URL, returning the raw response `Data`.
    /// - Parameters:
    ///   - url: The URL to request.
    ///   - queryItems: Optional array of URLQueryItem to append to the URL.
    ///   - headers: A dictionary of custom HTTP header fields.
    /// - Returns: The raw `Data` from the response.
    /// - Throws: An error if the request fails
    func get(url: URL, queryItems: [URLQueryItem]?, headers: [String: String]) async throws -> Data

    /// Performs an HTTP POST request for a given URL, returning the raw response `Data`.
    /// - Parameters:
    ///   - url: The URL to request.
    ///   - body: A `Data` instance representing the request bodyy
    ///   - headers: A dictionary of custom HTTP header fields.
    /// - Returns: The raw `Data` from the response.
    /// - Throws: An error if the request fails
    func post(url: URL, body: Data?, headers: [String: String]) async throws -> Data
}
