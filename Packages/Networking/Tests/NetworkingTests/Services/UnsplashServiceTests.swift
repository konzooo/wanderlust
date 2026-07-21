import XCTest
@testable import Networking

final class UnsplashServiceTests: XCTestCase {
    
    func test_fetchImageURL_returnsImageURL() async throws {
        // Given
        let mockResponse = """
        {
            "results": [
                {
                    "urls": {
                        "regular": "https://images.unsplash.com/photo-1234567890"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let client = MockNetworkClient(stub: .success(mockResponse))
        let sut = UnsplashService(apiClient: client)
        
        // When
        let imageURL = try await sut.fetchImageURL(for: "Barcelona, Spain")
        
        // Then
        XCTAssertEqual(imageURL.absoluteString, "https://images.unsplash.com/photo-1234567890")
    }
    
    func test_fetchImageURL_whenNoResults_throwsNoResultsError() async {
        // Given
        let mockResponse = """
        {
            "results": []
        }
        """.data(using: .utf8)!
        
        let client = MockNetworkClient(stub: .success(mockResponse))
        let sut = UnsplashService(apiClient: client)
        
        // When/Then
        do {
            _ = try await sut.fetchImageURL(for: "NonexistentPlace")
            XCTFail("Expected noResults error, but got success")
        } catch let error as UnsplashError {
            XCTAssertEqual(error, .noResults, "Expected noResults error, but got \(error)")
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    func test_fetchImageURL_whenDecodingFails_throwsDecodingError() async {
        // Given
        let invalidJSON = Data("{}".utf8)
        let client = MockNetworkClient(stub: .success(invalidJSON))
        let sut = UnsplashService(apiClient: client)
        
        // When/Then
        do {
            _ = try await sut.fetchImageURL(for: "Barcelona")
            XCTFail("Expected decoding error, but got success")
        } catch UnsplashError.decodingError {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_fetchImageURL_propagatesNetworkError() async {
        // Given
        struct DummyError: Error {}
        let client = MockNetworkClient(stub: .failure(DummyError()))
        let sut = UnsplashService(apiClient: client)
        
        // When/Then
        do {
            _ = try await sut.fetchImageURL(for: "Barcelona")
            XCTFail("Expected network error, but got success")
        } catch UnsplashError.networkingError {
            // Expected error
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_fetchImageURL_includesRequiredHeaders() async throws {
        // Given
        let mockResponse = """
        {
            "results": [
                {
                    "urls": {
                        "regular": "https://images.unsplash.com/photo-1234567890"
                    }
                }
            ]
        }
        """.data(using: .utf8)!
        
        let client = MockNetworkClient(stub: .success(mockResponse))
        let sut = UnsplashService(apiClient: client)
        
        // When
        _ = try await sut.fetchImageURL(for: "Barcelona")
        
        // Then
        XCTAssertNotNil(client.capturedHeaders)
        XCTAssertEqual(client.capturedHeaders?["Authorization"], "Client-ID \(UnsplashService.Constants.accessKey)")
        XCTAssertEqual(client.capturedHeaders?["Accept-Version"], "v1")
    }
} 
