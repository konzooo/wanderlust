import Foundation

/// Protocol defining the contract for services that provide destination images
public protocol ImageService {
    /// Fetches an image URL for a destination query
    /// - Parameter query: The destination query (e.g., "Barcelona, Spain", "Costa Brava")
    /// - Returns: A URL pointing to the image
    /// - Throws: An error if the request fails or no results are found
    func fetchImageURL(for query: String) async throws -> URL
}

/// Represents a request to search for images on Unsplash.
///
/// This structure encapsulates all the parameters needed to search for images,
/// including the search query and various filters to refine the results.
public struct UnsplashRequest: Encodable {
    /// The search query string (e.g., "Barcelona, Spain", "Costa Brava")
    public let query: String
    
    /// Number of results to return per page (default: 1)
    public let perPage: Int
    
    /// Image orientation filter (default: "landscape")
    public let orientation: String
    
    /// Content safety filter (default: "high" for PG-13+ content)
    public let contentFilter: String
    
    /// Creates a new Unsplash search request.
    /// - Parameters:
    ///   - query: The search query string
    ///   - perPage: Number of results per page (default: 1)
    ///   - orientation: Image orientation filter (default: "landscape")
    ///   - contentFilter: Content safety filter (default: "high")
    public init(
        query: String,
        perPage: Int = 1,
        orientation: String = "landscape",
        contentFilter: String = "high"
    ) {
        self.query = query
        self.perPage = perPage
        self.orientation = orientation
        self.contentFilter = contentFilter
    }
    
    enum CodingKeys: String, CodingKey {
        case query
        case perPage = "per_page"
        case orientation
        case contentFilter = "content_filter"
    }
}

/// Represents the response from an Unsplash search request.
///
/// This structure decodes the JSON response from Unsplash's search API,
/// containing an array of photo results with their associated URLs.
public struct UnsplashResponse: Decodable {
    /// Array of photo results from the search
    public let results: [Photo]
    
    /// Represents a single photo result from Unsplash
    public struct Photo: Decodable {
        /// Contains URLs for different sizes of the photo
        public struct URLs: Decodable {
            /// URL for the regular-sized version of the photo (~1080px wide)
            public let regular: URL
        }
        /// URLs for different sizes of the photo
        public let urls: URLs
    }
}

/// Errors that can occur during Unsplash API operations
public enum UnsplashError: Error, Equatable {
    /// Thrown when the API URL cannot be constructed
    case failedToBuildUrl
    
    /// Thrown when no results are found for the search query
    case noResults
    
    /// Thrown when there's an error decoding the API response
    case decodingError(Error)
    
    /// Thrown when there's a network-related error
    case networkingError(Error)
    
    public static func == (lhs: UnsplashError, rhs: UnsplashError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToBuildUrl, .failedToBuildUrl),
             (.noResults, .noResults):
            return true
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.networkingError(let lhsError), .networkingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
} 