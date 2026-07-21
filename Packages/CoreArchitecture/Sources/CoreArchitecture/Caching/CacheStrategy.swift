//
//  CacheStrategy.swift
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

/// Protocol defining methods for caching and retrieving codable objects.
/// Adopting the Strategy pattern, we can switch out the storage mechanism
/// (UserDefaults, disk-based, database, etc.) without changing the repository’s usage.
public protocol CacheStrategy: Sendable {
    /// Saves (encodes) a Codable object for a given key.
    func store<T: Codable>(_ object: T, forKey key: String) throws

    /// Retrieves (decodes) a Codable object for a given key, or nil if not found.
    func retrieve<T: Codable>(forKey key: String) throws -> T?
}

public enum CacheStrategyError: Error {
    case failedDecoding(Error)
    case failedEncoding(Error)
}
