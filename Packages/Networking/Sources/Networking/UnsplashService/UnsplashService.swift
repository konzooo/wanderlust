import Foundation

/// A service for fetching destination images from Unsplash.
///
/// This service provides functionality to search for and retrieve images
/// of destinations (cities, countries, regions) using the Unsplash API.
/// It's designed to be used with dependency injection and follows the
/// same pattern as other services in the Networking package.
public struct UnsplashService: ImageService {
    /// The network client used for making HTTP requests
    private let apiClient: NetworkClient
    
    /// The Unsplash API access key (Client ID)
    private let accessKey: String
    
    /// The base URL for the Unsplash search API
    private let baseURL: String

    /// Query → chosen image URL. The normal app initializer enables the
    /// persistent cache; the dependency-injection initializer intentionally
    /// leaves it off so tests and specialized clients remain deterministic.
    private let urlCache: PersistentUnsplashURLCache?

    public init(baseURL: String = "https://api.unsplash.com/search/photos") {
        self.init(apiClient: APIClient(), baseURL: baseURL, urlCache: .shared)
    }
    
    /// Creates a new Unsplash service instance.
    /// - Parameters:
    ///   - apiClient: The network client to use.
    ///   - baseURL: The base URL for the Unsplash API (defaults to search endpoint)
    public init(
        apiClient: NetworkClient,
        baseURL: String = "https://api.unsplash.com/search/photos"
    ) {
        self.init(apiClient: apiClient, baseURL: baseURL, urlCache: nil)
    }

    init(
        apiClient: NetworkClient,
        baseURL: String = "https://api.unsplash.com/search/photos",
        urlCache: PersistentUnsplashURLCache?
    ) {
        self.accessKey = Constants.accessKey
        self.apiClient = apiClient
        self.baseURL = baseURL
        self.urlCache = urlCache
    }
    
    /// Fetches a landscape image URL for a destination query.
    ///
    /// This method searches Unsplash for images matching the given query
    /// and returns the URL of the first landscape image found.
    ///
    /// - Parameter query: The destination query (e.g., "Barcelona, Spain", "Costa Brava")
    /// - Returns: A URL pointing to the image on Unsplash
    /// - Throws: `UnsplashError` if the request fails or no results are found
    public func fetchImageURL(for query: String) async throws -> URL {
        if let cached = urlCache?.retrieve(for: query) {
            return cached
        }

        guard let url = URL(string: baseURL) else {
            throw UnsplashError.failedToBuildUrl
        }
        
        let request = UnsplashRequest(query: query)
        let headers = [
            "Authorization": "Client-ID \(accessKey)",
            "Accept-Version": "v1"
        ]
        
        do {
            let data = try await apiClient.get(
                url: url,
                queryItems: request.asQueryItems(),
                headers: headers
            )
            let response = try JSONDecoder().decode(UnsplashResponse.self, from: data)
            
            guard let imageURL = response.results.first?.urls.regular else {
                throw UnsplashError.noResults
            }
            
            urlCache?.store(imageURL, for: query)
            return imageURL
        } catch let error as DecodingError {
            throw UnsplashError.decodingError(error)
        } catch let error as UnsplashError {
            throw error
        } catch {
            throw UnsplashError.networkingError(error)
        }
    }
    
    enum Constants {
        static let accessKey = "ySD0m163_1TPP6dOZdjybAhWFpC-7thmRJrAMO9-JzI"
    }
}

/// Small, durable cache for Unsplash search results. This is separate from the
/// downloaded-image cache: it prevents a repeated search from selecting a new
/// first result before the renderer even sees an image URL.
final class PersistentUnsplashURLCache: @unchecked Sendable {
    static let shared = PersistentUnsplashURLCache()

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let lock = NSLock()

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "com.wanderlust.unsplash.selectedImageURLs"
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func retrieve(for query: String) -> URL? {
        lock.withLock {
            guard let raw = entries()[normalized(query)] else { return nil }
            return URL(string: raw)
        }
    }

    func store(_ url: URL, for query: String) {
        lock.withLock {
            var values = entries()
            values[normalized(query)] = url.absoluteString
            userDefaults.set(values, forKey: storageKey)
        }
    }

    private func entries() -> [String: String] {
        userDefaults.dictionary(forKey: storageKey) as? [String: String] ?? [:]
    }

    private func normalized(_ query: String) -> String {
        query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .lowercased()
    }
}

// MARK: - Private Helpers
private extension UnsplashRequest {
    /// Converts the request parameters into URL query items.
    ///
    /// This method transforms the request's properties into URLQueryItems
    /// that can be used to build the API request URL.
    ///
    /// - Returns: An array of URLQueryItems representing the request parameters
    func asQueryItems() -> [URLQueryItem] {
        [
            URLQueryItem(name: CodingKeys.query.rawValue, value: query),
            URLQueryItem(name: CodingKeys.perPage.rawValue, value: String(perPage)),
            URLQueryItem(name: CodingKeys.orientation.rawValue, value: orientation),
            URLQueryItem(name: CodingKeys.contentFilter.rawValue, value: contentFilter)
        ]
    }
}
