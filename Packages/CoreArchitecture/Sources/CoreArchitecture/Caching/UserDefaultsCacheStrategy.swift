//
//  UserDefaultsStrategy.swift
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

/// Cache Strategy that stores it's data in `UserDefaults`.
///
/// For the sake of this project I will user UserDefaults given that is a simple solution
/// and a low number of entities. But idealy this should be replaced by file-storage or database-storage
/// - It encodes the objects to Data (JSON) before storing them.
public final class UserDefaultsCacheStrategy: CacheStrategy, @unchecked Sendable {

    /// Default to `.standard`, but can be injected if needed.
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Encodes an object to JSON and stores the data in `UserDefaults`.
    /// Fails silently, but in a production env we might add more robust error handling/logging.
    public func store<T: Codable>(_ object: T, forKey key: String) throws {
        do {
            let data = try JSONEncoder().encode(object)
            userDefaults.set(data, forKey: key)
        } catch {
            throw CacheStrategyError.failedEncoding(error)
        }
    }

    /// Retrieves data for the given key from `UserDefaults`, decodes it from JSON,
    /// and returns the resulting object if successful. Otherwise, returns nil.
    public func retrieve<T: Codable>(forKey key: String) throws -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }

        do {
            let decodedObject = try JSONDecoder().decode(T.self, from: data)
            return decodedObject
        } catch {
            throw CacheStrategyError.failedDecoding(error)
        }
    }
}

