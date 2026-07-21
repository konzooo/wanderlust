//
//  ImageCacheStrategy.swift
//
//  Created by Rodrigo Mato Castellano on 3/7/25.
//

import SwiftUI

/// Protocol defining methods for caching and retrieving Image objects.
/// Adopting the Strategy pattern, we can switch out the storage mechanism
/// (in-memory, disk-based, database, third-party etc.) without changing the repository’s usage.
public protocol ImageCacheStrategy: ObservableObject {
    /// Saves an Image object for a given key.
    func store(_ image: Image, forKey key: String)

    /// Retrieves (decodes) an Image object for a given key, or nil if not found.
    func retrieve(forKey key: String) -> Image?
}
