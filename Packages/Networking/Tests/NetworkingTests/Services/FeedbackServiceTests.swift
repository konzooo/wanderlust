import XCTest
@testable import Networking

final class FeedbackServiceTests: XCTestCase {
    
    func test_sendFeedback_success() async throws {
        // Given
        let feedback = FeedbackRequest(
            userID: "test_user_001",
            feedback: "Test feedback",
            suggestion: "Add dark mode"
        )
        let client = MockNetworkClient(stub: .success(Data()))
        let sut = FeedbackService(apiClient: client)
        
        // When
        let result = try await sut.sendFeedback(feedback)
        
        // Then
        XCTAssertTrue(result)
        XCTAssertNotNil(client.capturedHeaders)
        XCTAssertEqual(client.capturedHeaders?["Content-Type"], "application/x-www-form-urlencoded")
        XCTAssertNotNil(client.capturedBody)
    }
    
    func test_sendFeedback_whenEncodingFails_throwsEncodingError() async {
        // Given
        let feedback = FeedbackRequest(
            userID: "test_user_001",
            feedback: "Test feedback",
            suggestion: "Add dark mode"
        )
        let client = MockNetworkClient(stub: .failure(EncodingError.invalidValue("", EncodingError.Context(
            codingPath: [],
            debugDescription: "Test encoding error"
        ))))
        let sut = FeedbackService(apiClient: client)
        
        // When/Then
        do {
            _ = try await sut.sendFeedback(feedback)
            XCTFail("Expected encoding error, but got success")
        } catch let error as FeedbackError {
            XCTAssertEqual(error, .encodingError(EncodingError.invalidValue("", EncodingError.Context(
                codingPath: [],
                debugDescription: "Test encoding error"
            ))))
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    func test_sendFeedback_whenNetworkFails_throwsNetworkingError() async {
        // Given
        let feedback = FeedbackRequest(
            userID: "test_user_001",
            feedback: "Test feedback",
            suggestion: "Add dark mode"
        )
        struct DummyError: Error {}
        let client = MockNetworkClient(stub: .failure(DummyError()))
        let sut = FeedbackService(apiClient: client)
        
        // When/Then
        do {
            _ = try await sut.sendFeedback(feedback)
            XCTFail("Expected networking error, but got success")
        } catch let error as FeedbackError {
            XCTAssertEqual(error, .networkingError(DummyError()))
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    func test_sendFeedback_includesRequiredHeaders() async throws {
        // Given
        let feedback = FeedbackRequest(
            userID: "test_user_001",
            feedback: "Test feedback",
            suggestion: "Add dark mode"
        )
        let client = MockNetworkClient(stub: .success(Data()))
        let sut = FeedbackService(apiClient: client)
        
        // When
        _ = try await sut.sendFeedback(feedback)
        
        // Then
        XCTAssertNotNil(client.capturedHeaders)
        XCTAssertEqual(client.capturedHeaders?["Content-Type"], "application/x-www-form-urlencoded")
    }
    
    func test_sendFeedback_encodesBodyCorrectly() async throws {
        // Given
        let feedback = FeedbackRequest(
            userID: "test_user_001",
            feedback: "Test feedback",
            suggestion: "Add dark mode"
        )
        let client = MockNetworkClient(stub: .success(Data()))
        let sut = FeedbackService(apiClient: client)
        
        // When
        _ = try await sut.sendFeedback(feedback)
        
        // Then
        XCTAssertNotNil(client.capturedBody)
        let bodyString = String(data: client.capturedBody!, encoding: .utf8)!
        XCTAssertTrue(bodyString.contains("user_id=test_user_001"))
        XCTAssertTrue(bodyString.contains("feedback=Test+feedback"))
        XCTAssertTrue(bodyString.contains("suggestion=Add+dark+mode"))
    }
} 
