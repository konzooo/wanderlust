//
//  FeedbackRequest.swift
//  Networking
//
//  Created by Rodrigo Mato Castellano on 5/29/25.
//

public struct FeedbackRequest: Encodable {
    public let userID: String          // e.g. "test_user_001"
    public let feedback: String?       // e.g. "Test feedback"
    public let suggestion: String?     // e.g. "Add dark mode"

    public init(userID: String, feedback: String?, suggestion: String?) {
        self.userID = userID
        self.feedback = feedback
        self.suggestion = suggestion
    }

    enum CodingKeys: String, CodingKey {
        case userID     = "user_id"
        case feedback   = "feedback"
        case suggestion = "suggestion"
    }
}

public enum FeedbackError: Error, Equatable {
    case failedToBuildUrl
    case encodingError(EncodingError)
    case networkingError(Error)
    
    public static func == (lhs: FeedbackError, rhs: FeedbackError) -> Bool {
        switch (lhs, rhs) {
        case (.failedToBuildUrl, .failedToBuildUrl):
            return true
        case (.encodingError(let lhsError), .encodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.networkingError(let lhsError), .networkingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

public enum FeedbackResult: Equatable {
    case success
    case error
}
