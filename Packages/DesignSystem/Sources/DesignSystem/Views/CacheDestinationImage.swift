//
//  CacheDestinationImage.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 4/7/25.
//

import Foundation
import CoreArchitecture
import SwiftUI

public struct CacheDestinationImage: View {
    let cacheKey: String
    let imageUrlState: AsyncValue<URL>
    let imageCache: any ImageCacheStrategy

    public init(
        cacheKey: String,
        imageUrlState: AsyncValue<URL>,
        imageCache: any ImageCacheStrategy = InMemoryImageCacheStrategy.shared
    ) {
        self.cacheKey = cacheKey
        self.imageUrlState = imageUrlState
        self.imageCache = imageCache
    }

    public var body: some View {
        if let image = imageCache.retrieve(forKey: cacheKey) {
            image.resizable().scaledToFill()
        } else {
            switch imageUrlState {
            case .initial, .loading:
                placeholder.overlay { ProgressView() }
            case .loaded(let url):
                AsyncImage(url: url, transaction: .init(animation: .easeInOut)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .onAppear {
                                imageCache.store(image, forKey: cacheKey)
                            }
                    case .failure, .empty:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            case .error:
                placeholder
            }
        }
    }

    var placeholder: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: "airplane")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
} 
