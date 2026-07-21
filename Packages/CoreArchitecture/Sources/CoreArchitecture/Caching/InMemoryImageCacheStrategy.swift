//
//  InMemoryImageCacheStrategy.swift
//
//  Created by Rodrigo Mato Castellano on 3/7/25.
//
import SwiftUI

public class InMemoryImageCacheStrategy: ObservableObject, ImageCacheStrategy {
    nonisolated(unsafe) public static let shared: InMemoryImageCacheStrategy = .init()
    
    private var dynamicMemoryCache: [String: Image]
    
    private init(dynamicMemoryCache: [String : Image] = [:]) {
        self.dynamicMemoryCache = dynamicMemoryCache
    }

    public func store(_ image: Image, forKey key: String) {
        dynamicMemoryCache[key] = image
    }

    public func retrieve(forKey key: String) -> Image? {
        dynamicMemoryCache[key]
    }
}
