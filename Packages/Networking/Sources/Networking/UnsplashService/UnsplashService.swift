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
    
    /// Creates a new Unsplash service instance.
    /// - Parameters:
    ///   - apiClient: The network client to use (defaults to APIClient)
    ///   - baseURL: The base URL for the Unsplash API (defaults to search endpoint)
    public init(
        apiClient: NetworkClient = APIClient(),
        baseURL: String = "https://api.unsplash.com/search/photos"
    ) {
        self.accessKey = Constants.accessKey
        self.apiClient = apiClient
        self.baseURL = baseURL
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
