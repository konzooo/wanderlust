import XCTest
@testable import Wanderlust

@MainActor
final class NavigationRouterTests: XCTestCase {
    func testTabPathsAreIsolated() {
        let router = NavigationRouter()

        router.goToBasicInfo(.init(destination: "Paris"))
        router.selectedTab = .trips
        router.goToGroupCreate()

        XCTAssertEqual(router.homePath, [.basicInfo(.init(destination: "Paris"))])
        XCTAssertEqual(router.tripsPath, [.groupCreate(.create)])
        XCTAssertTrue(router.profilePath.isEmpty)
    }

    func testResetStackReplacesOnlyTargetTab() {
        let router = NavigationRouter()
        router.goToBasicInfo(.init(destination: "Paris"), on: .home)
        router.goToFeedback(on: .profile)

        router.goToGroupCreate(on: .home, resetStack: true)

        XCTAssertEqual(router.homePath, [.groupCreate(.create)])
        XCTAssertEqual(router.profilePath, [.feedback])
    }

    func testItineraryResetLandsOnOriginRootWithoutSyntheticTripsFrame() {
        let router = NavigationRouter()
        router.selectedTab = .trips
        router.goToBasicInfo(.init(destination: "Rome"))
        router.goToQuestionnaire()
        let state = TripOutputStore.State(
            details: .init(
                destination: .init(name: "Rome"),
                members: .init(groupType: .solo),
                duration: 3,
                month: .may
            ),
            mode: .newTrip
        )

        router.goToItineraryResult(state, resetStack: true)

        XCTAssertEqual(router.tripsPath, [.itineraryResult(state)])
        XCTAssertTrue(router.homePath.isEmpty)
    }

    func testUniversalJoinLinkSelectsTripsAndReplacesItsStack() {
        let router = NavigationRouter()
        router.goToFeedback(on: .trips)

        router.handleDeepLink(URL(string: "https://wanderlust.get-catalyst.app/join/01234")!)

        XCTAssertEqual(router.selectedTab, .trips)
        XCTAssertEqual(router.tripsPath, [.groupJoin(code: "01234")])
        XCTAssertEqual(router.groupJoinAnalyticsSource, "deep_link")
    }

    func testCustomSchemeJoinLinkSelectsTrips() {
        let router = NavigationRouter()

        router.handleDeepLink(URL(string: "wanderlust://join/54321")!)

        XCTAssertEqual(router.selectedTab, .trips)
        XCTAssertEqual(router.tripsPath, [.groupJoin(code: "54321")])
    }

    func testMalformedJoinCodeFallsThroughToUnknown() {
        let router = NavigationRouter()

        router.handleDeepLink(URL(string: "wanderlust://join/12ab3")!)

        XCTAssertEqual(router.selectedTab, .home)
        guard case .unknown = router.homePath.first else {
            return XCTFail("Expected malformed join link to become unknown")
        }
    }

    func testSharedTripLinkSelectsTripsAndNormalizesHex() {
        let router = NavigationRouter()
        let code = "ABCDEF0123456789ABCDEF0123456789"

        router.handleDeepLink(URL(string: "wanderlust://t/\(code)")!)

        XCTAssertEqual(router.selectedTab, .trips)
        XCTAssertEqual(router.tripsPath, [.sharedTrip(code: code.lowercased())])
    }

    func testUniversalFeedbackLinkSelectsProfileAndResets() {
        let router = NavigationRouter()
        router.goToDebugMenu(on: .profile)

        router.handleDeepLink(URL(string: "https://wanderlust.get-catalyst.app/feedback")!)

        XCTAssertEqual(router.selectedTab, .profile)
        XCTAssertEqual(router.profilePath, [.feedback])
    }

    func testCustomSchemeFeedbackLinkUsesHostSegment() {
        let router = NavigationRouter()

        router.handleDeepLink(URL(string: "wanderlust://feedback")!)

        XCTAssertEqual(router.selectedTab, .profile)
        XCTAssertEqual(router.profilePath, [.feedback])
    }

#if DEBUG
    func testDebugLinkSelectsProfileAndResets() {
        let router = NavigationRouter()
        router.goToFeedback(on: .profile)

        router.handleDeepLink(URL(string: "wanderlust://debug")!)

        XCTAssertEqual(router.selectedTab, .profile)
        XCTAssertEqual(router.profilePath, [.debugMenu])
    }
#endif

    func testUnknownLinkSelectsHomeAndRendersUnknownDestination() {
        let router = NavigationRouter()
        router.goToGroupCreate(on: .home)

        router.handleDeepLink(URL(string: "wanderlust://not-a-real-route")!)

        XCTAssertEqual(router.selectedTab, .home)
        guard case let .unknown(message) = router.homePath.first else {
            return XCTFail("Expected unknown destination")
        }
        XCTAssertTrue(message?.contains("not-a-real-route") == true)
    }
}
