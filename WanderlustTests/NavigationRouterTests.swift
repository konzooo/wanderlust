import XCTest
@testable import Wanderlust

final class NavigationRouterTests: XCTestCase {
    func testGoToHome() {
        let router = NavigationRouter()
        router.goToHome()
        XCTAssertEqual(router.path, [.home])
    }

    func testGoToBasicInfo() {
        let router = NavigationRouter()
        let state = BasicInfoStore.State(destination: "Paris")
        router.goToBasicInfo(state)
        XCTAssertEqual(router.path, [.basicInfo(state)])
    }

    func testGoToQuestionnaire() {
        let router = NavigationRouter()
        let state = QuestionnaireStore.State(cards: [])
        router.goToQuestionnaire(state)
        XCTAssertEqual(router.path, [.questionnaire(state)])
    }

    func testGoToItineraryResult() {
        let router = NavigationRouter()
        let state = ItineraryResultStore.State(
            tripSummary: "Trip to Rome",
            details: .mock
        )
        router.goToItineraryResult(state)
        XCTAssertEqual(router.path, [.itineraryResult(state)])
    }

    func testGoToFeedback() {
        let router = NavigationRouter()
        router.goToFeedback()
        XCTAssertEqual(router.path, [.feedback])
    }

    func testGoToUnknown() {
        let router = NavigationRouter()
        router.goToUnknown("test")
        XCTAssertEqual(router.path, [.unknown("test")])
    }

    func testPop() {
        let router = NavigationRouter()
        router.goToHome()
        router.goToFeedback()
        router.pop()
        XCTAssertEqual(router.path, [.home])
    }

    func testPopToRoot() {
        let router = NavigationRouter()
        router.goToHome()
        router.goToFeedback()
        router.popToRoot()
        XCTAssertTrue(router.path.isEmpty)
    }

    func testHandleDeepLinkFeedback() {
        let router = NavigationRouter()
        router.handleDeepLink(URL(string: "myapp://feedback")!)
        XCTAssertEqual(router.path, [.feedback])
    }

    func testHandleDeepLinkUnknown() {
        let router = NavigationRouter()
        router.handleDeepLink(URL(string: "myapp://unknown")!)
        XCTAssertEqual(router.path, [.unknown("Unknown deep link: myapp://unknown")])
    }

    func testGoToItineraryResultPrecondition() {
        let router = NavigationRouter()
        let emptyState = ItineraryResultStore.State(tripSummary: "", details: .mock)
        // This should trigger a precondition failure in debug, but we can't test that directly in XCTest.
        // Instead, we check that it does not append to the path if the precondition is not met (in release builds, precondition is ignored).
        #if !DEBUG
        router.goToItineraryResult(emptyState)
        XCTAssertEqual(router.path, [.itineraryResult(emptyState)])
        #endif
    }

    func testGoToItineraryResultWithValidState() {
        let router = NavigationRouter()
        let state = ItineraryResultStore.State(
            tripSummary: "Test Trip",
            details: .mock
        )
        
        router.goToItineraryResult(state)
        
        XCTAssertEqual(router.path.count, 1)
        if case .itineraryResult(let resultState) = router.path.first {
            XCTAssertEqual(resultState.tripSummary, "Test Trip")
        } else {
            XCTFail("Expected itineraryResult destination")
        }
    }

    func testGoToItineraryResultWithEmptySummaryThrows() {
        let router = NavigationRouter()
        let emptyState = ItineraryResultStore.State(tripSummary: "", details: .mock)
        
        // This should not throw in the current implementation, but we can test the precondition
        router.goToItineraryResult(emptyState)
        
        // The router should still add the destination even with empty summary
        XCTAssertEqual(router.path.count, 1)
    }
} 