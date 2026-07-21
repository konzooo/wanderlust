import XCTest
@testable import Networking

final class SwapiServiceTests: XCTestCase {
    
    func test_fetchPlanets_returnsDecodedPlanets() async throws {
        // Given
        let client = MockNetworkClient(stub: .success(mockPlanetsPageJSON))
        let sut = SwapiService(apiClient: client)
        
        // When
        let planets = try await sut.fetchPlanets()
        
        // Then
        XCTAssertEqual(planets.count, 10)
        XCTAssertEqual(planets.first?.name, "Tatooine")
    }
}
