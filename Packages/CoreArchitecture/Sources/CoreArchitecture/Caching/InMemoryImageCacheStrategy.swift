//
//  InMemoryImageCacheStrategy.swift
//
//  Created by Rodrigo Mato Castellano on 3/7/25.
//
import Foundation

public actor InMemoryImageCacheStrategy: ImageCacheStrategy {
    public static let shared: InMemoryImageCacheStrategy = .init()

    private var dynamicMemoryCache: [String: Data]

    public init(dynamicMemoryCache: [String: Data] = [:]) {
        self.dynamicMemoryCache = dynamicMemoryCache
    }

    public func store(_ data: Data, forKey key: String) {
        dynamicMemoryCache[key] = data
    }

    public func retrieveData(forKey key: String) -> Data? {
        dynamicMemoryCache[key]
    }
}
