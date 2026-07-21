//
//  FeedbackService.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano on 5/29/25.
//

import Foundation

public struct FeedbackService {
    private let apiClient: NetworkClient
    private let bodyEncoder: BodyEncoder

    public init(
        apiClient: NetworkClient = APIClient(),
        bodyEncoder: BodyEncoder = FormURLEncodedBodyEncoder()
    ) {
        self.apiClient    = apiClient
        self.bodyEncoder  = bodyEncoder
    }

    public func sendFeedback(_ feedback: FeedbackRequest) async throws -> Bool {
        guard let url = URL(string: Constants.url) else {
            throw FeedbackError.failedToBuildUrl
        }

        do {
            let (bodyData, contentType) = try bodyEncoder.encode(feedback)
            let headers = ["Content-Type": contentType]
            _ = try await apiClient.post(url: url, body: bodyData, headers: headers)
            return true
        } catch let error as EncodingError {
            throw FeedbackError.encodingError(error)
        } catch {
            throw FeedbackError.networkingError(error)
        }
    }
}

private extension FeedbackService {
    enum Constants {
        static let url = "https://script.google.com/macros/s/AKfycbx9K8R4b0KkNJGEDsx1Z9I-PGStclk8zl_cNOHgIIgQZrK7P7krs64wa4_Jc7KrK6Apvg/exec"
    }
}
