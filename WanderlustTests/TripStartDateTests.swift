import CoreModels
import XCTest
@testable import Wanderlust

final class TripStartDateTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Sofia")!
        return calendar
    }

    func testSameMonthStartsAtCreationDay() throws {
        let created = try date(2026, 8, 12, hour: 17)
        let start = try XCTUnwrap(
            TripStartDate.inferred(createdAt: created, month: .August, calendar: calendar)
        )

        XCTAssertEqual(start, calendar.startOfDay(for: created))
    }

    func testFutureMonthStartsOnFirstDay() throws {
        let start = try XCTUnwrap(
            TripStartDate.inferred(
                createdAt: date(2026, 8, 12),
                month: .october,
                calendar: calendar
            )
        )

        XCTAssertEqual(start, try date(2026, 10, 1))
    }

    func testEarlierMonthRollsIntoNextYear() throws {
        let start = try XCTUnwrap(
            TripStartDate.inferred(
                createdAt: date(2026, 12, 20),
                month: .february,
                calendar: calendar
            )
        )

        XCTAssertEqual(start, try date(2027, 2, 1))
    }

    func testEndDateIsExclusive() throws {
        let created = try date(2026, 8, 10, hour: 15)

        XCTAssertTrue(TripStartDate.isCurrentOrUpcoming(
            createdAt: created,
            month: .August,
            durationDays: 2,
            now: try date(2026, 8, 11, hour: 23),
            calendar: calendar
        ))
        XCTAssertFalse(TripStartDate.isCurrentOrUpcoming(
            createdAt: created,
            month: .August,
            durationDays: 2,
            now: try date(2026, 8, 12),
            calendar: calendar
        ))
    }

    func testCalendarDayArithmeticSurvivesDST() throws {
        let created = try date(2026, 3, 28, hour: 18)
        let start = try XCTUnwrap(
            TripStartDate.inferred(createdAt: created, month: .march, calendar: calendar)
        )
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start))

        XCTAssertEqual(calendar.component(.day, from: end), 30)
        XCTAssertTrue(TripStartDate.isCurrentOrUpcoming(
            createdAt: created,
            month: .march,
            durationDays: 2,
            now: try date(2026, 3, 29, hour: 20),
            calendar: calendar
        ))
    }

    func testMissingLegacyMetadataStaysEligible() throws {
        XCTAssertTrue(TripStartDate.isCurrentOrUpcoming(
            createdAt: nil,
            month: nil,
            durationDays: nil,
            now: try date(2026, 8, 12),
            calendar: calendar
        ))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        )))
    }
}
