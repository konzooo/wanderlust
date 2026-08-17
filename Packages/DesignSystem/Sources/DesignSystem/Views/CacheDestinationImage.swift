//
//  CacheDestinationImage.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 4/7/25.
//

import Foundation
import CoreArchitecture
import SwiftUI
import UIKit

public struct CacheDestinationImage: View {
    let cacheKey: String
    let imageUrlState: AsyncValue<URL>
    let imageCache: any ImageCacheStrategy

    @State private var renderedImage: UIImage?
    @State private var renderedImageKey: String?
    @State private var failedLoadID: String?

    public init(
        cacheKey: String,
        imageUrlState: AsyncValue<URL>,
        imageCache: any ImageCacheStrategy = PersistentImageCacheStrategy.shared
    ) {
        self.cacheKey = cacheKey
        self.imageUrlState = imageUrlState
        self.imageCache = imageCache
    }

    public var body: some View {
        Group {
            if let renderedImage, renderedImageKey == storageKey {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFill()
            } else {
                switch imageUrlState {
                case .initial, .loading:
                    loadingPlaceholder
                case .loaded:
                    if failedLoadID == loadID {
                        placeholder
                    } else {
                        loadingPlaceholder
                    }
                case .error:
                    placeholder
                }
            }
        }
        .task(id: loadID) {
            await loadImage()
        }
    }

    private var loadID: String {
        switch imageUrlState {
        case .loaded(let url): "\(cacheKey)|\(url.absoluteString)"
        case .initial: "\(cacheKey)|initial"
        case .loading: "\(cacheKey)|loading"
        case .error: "\(cacheKey)|error"
        }
    }

    /// Once a URL exists it is the cache identity. That lets the trip card,
    /// header, and favorites sheet share bytes even if their display titles
    /// differ, while two trips to the same destination can still retain
    /// different explicitly-selected photos.
    private var storageKey: String {
        imageUrlState.data?.absoluteString ?? cacheKey
    }

    @MainActor
    private func loadImage() async {
        failedLoadID = nil
        let requestedStorageKey = storageKey
        if renderedImageKey != requestedStorageKey {
            renderedImage = nil
            renderedImageKey = nil
        }

        if let data = await imageCache.retrieveData(forKey: requestedStorageKey),
           let image = UIImage(data: data) {
            guard !Task.isCancelled else { return }
            renderedImage = image
            renderedImageKey = requestedStorageKey
            return
        }

        guard case let .loaded(url) = imageUrlState else { return }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                guard (200..<300).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
            }
            guard let image = UIImage(data: data) else {
                throw URLError(.cannotDecodeContentData)
            }
            guard !Task.isCancelled else { return }
            renderedImage = image
            renderedImageKey = requestedStorageKey
            await imageCache.store(data, forKey: requestedStorageKey)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            failedLoadID = loadID
        }
    }

    private var loadingPlaceholder: some View {
        placeholder.overlay { ProgressView() }
    }

    private var placeholder: some View {
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
