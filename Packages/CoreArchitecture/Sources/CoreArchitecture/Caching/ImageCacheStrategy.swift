//
//  ImageCacheStrategy.swift
//
//  Created by Rodrigo Mato Castellano on 3/7/25.
//

import Foundation

/// Stores the original downloaded image bytes rather than a `SwiftUI.Image`.
/// Keeping bytes makes a cache durable: renderers can decode them again after
/// the process has been terminated.
public protocol ImageCacheStrategy: Sendable {
    /// Saves image bytes for a stable logical key.
    func store(_ data: Data, forKey key: String) async

    /// Retrieves image bytes for a key, or `nil` on a cache miss.
    func retrieveData(forKey key: String) async -> Data?
}
