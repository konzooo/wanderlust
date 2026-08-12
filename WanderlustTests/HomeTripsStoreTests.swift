import CoreModels
import Foundation
import XCTest
@testable import Wanderlust

final class HomeTripsStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testMergesPersonalAndGroupTripsNewestFirst() throws {
        let personal = trip("Lisbon", createdAt: try date(2026, 8, 11), duration: 10)
        let group = summary("Alps", createdAt: try date(2026, 8, 10), duration: 10)

        let items = HomeTripsStore.makeItems(
            personal: [personal],
            groups: [group],
            now: try date(2026, 8, 12),
            calendar: calendar
        )

        guard case let .personal(first) = items.first else {
            return XCTFail("Expected newest personal trip first")
        }
        XCTAssertEqual(first.details.destination.name, "Lisbon")
        guard case let .group(second) = items.last else {
            return XCTFail("Expected group trip second")
        }
        XCTAssertEqual(second.destination, "Alps")
    }

    func testFiltersFinishedTripsButKeepsLegacyEntries() throws {
        let finished = trip("Old", createdAt: try date(2026, 6, 2), month: .June, duration: 2)
        let legacy = GroupTripSummary(
            groupId: "legacy",
            name: "Legacy",
            destination: "Somewhere",
            code: "12345"
        )

        let items = HomeTripsStore.makeItems(
            personal: [finished],
            groups: [legacy],
            now: try date(2026, 8, 12),
            calendar: calendar
        )

        XCTAssertEqual(items, [.group(legacy)])
    }

    func testCapsAtFourAndAddsSeeAllOnlyWhenNeeded() throws {
        let trips = try (7...11).map { day in
            trip("Trip \(day)", createdAt: try date(2026, 8, day), duration: 30)
        }

        let capped = HomeTripsStore.makeItems(
            personal: trips,
            groups: [],
            now: try date(2026, 8, 12),
            calendar: calendar
        )
        XCTAssertEqual(capped.count, 5)
        XCTAssertEqual(capped.last, .seeAll)

        let uncapped = HomeTripsStore.makeItems(
            personal: Array(trips.prefix(4)),
            groups: [],
            now: try date(2026, 8, 12),
            calendar: calendar
        )
        XCTAssertEqual(uncapped.count, 4)
        XCTAssertFalse(uncapped.contains(.seeAll))
    }

    func testOldGroupSummaryJSONDecodesWithoutDateFields() throws {
        let data = Data(#"{"groupId":"old","name":"Old group","destination":"Rome","code":"54321"}"#.utf8)
        let summary = try JSONDecoder().decode(GroupTripSummary.self, from: data)

        XCTAssertNil(summary.createdAt)
        XCTAssertNil(summary.startMonth)
        XCTAssertNil(summary.durationDays)
    }

    private func trip(
        _ destination: String,
        createdAt: Date,
        month: Month = .August,
        duration: Int
    ) -> Trip {
        Trip(
            details: .init(
                destination: .init(name: destination),
                members: .init(groupType: .solo),
                duration: duration,
                month: month
            ),
            itinerary: .mock,
            suggestions: nil,
            createdAt: createdAt
        )
    }

    private func summary(_ destination: String, createdAt: Date, duration: Int) -> GroupTripSummary {
        GroupTripSummary(
            groupId: destination,
            name: "\(destination) crew",
            destination: destination,
            code: "12345",
            createdAt: createdAt,
            startMonth: .August,
            durationDays: duration
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )))
    }
}
