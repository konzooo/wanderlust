//
//  TasksService.swift
//
//  Created by Rodrigo Mato Castellano
//

import Foundation

public struct SwapiService: PlanetsService {

    /// The base URL string of the swapi api.
    /// Defaults to `Constants.plantsUrlString`.
    private let baseUrlString: String

    /// The NetworkClient used to perform the network request.
    /// Defaults to the URLSession client, but can be injected for testing.
    private let apiClient: NetworkClient

    /// Initializer exposing `apiClient` parameter which allows easy injection in tests or other use cases.
    /// - Parameters:
    ///   - apiClient: A `NetworkClient` used for performing requests
    public init(
        apiClient: NetworkClient = APIClient()
    ) {
        self.baseUrlString = Constants.plantsUrlString
        self.apiClient = apiClient
    }

    /// Fetches an array of `Planet` objects
    /// - Returns: An array of `API.Planet`
    public func fetchPlanets() async throws -> [API.Planet] {
        guard let url = URL(string: baseUrlString) else {
            throw SwapiServiceError.failedToBuildUrl
        }

        do {
            /// 1- Uncomment to use `https://swapi.tech` or for UnitTests
//            let data = try await apiClient.get(url: url)
//            let response = try decoder.decode(PlanetsResponse.self, from: data)

            /// 2- Uncomment to use the APP
            let response = try decoder.decode(PlanetsResponse.self, from: mockPlanetsPageJSON)

            return response.results // not using any other value from the response for now
        } catch {
            throw SwapiServiceError.decodingError(error)
        }
    }

    // JSON decode with required DateFormatter
    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}

private extension SwapiService {
    enum Constants {
        /// Default Planets endpoint
        static let plantsUrlString = "https://swapi.tech/api/planets/"
    }
}

enum SwapiServiceError: Error {
    case failedToBuildUrl
    case decodingError(Error)
}
