import CoreArchitecture
import CoreModels
import Foundation

enum TripStartDate {
    static func inferred(
        createdAt: Date,
        month: Month,
        calendar: Calendar = .current
    ) -> Date? {
        let createdDay = calendar.startOfDay(for: createdAt)
        let createdMonthIndex = calendar.component(.month, from: createdAt) - 1
        guard let targetMonthIndex = Month.all.firstIndex(of: month) else { return nil }

        if createdMonthIndex == targetMonthIndex {
            return createdDay
        }

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = calendar.component(.year, from: createdAt)
            + (targetMonthIndex < createdMonthIndex ? 1 : 0)
        components.month = targetMonthIndex + 1
        components.day = 1
        return calendar.date(from: components).map(calendar.startOfDay(for:))
    }

    static func isCurrentOrUpcoming(
        createdAt: Date?,
        month: Month?,
        durationDays: Int?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let createdAt, let month, let durationDays else { return true }
        guard let start = inferred(createdAt: createdAt, month: month, calendar: calendar),
              let exclusiveEnd = calendar.date(
                byAdding: .day,
                value: max(durationDays, 0),
                to: start
              ) else { return true }
        return exclusiveEnd > calendar.startOfDay(for: now)
    }
}

enum HomeTripItem: Equatable, Identifiable {
    case personal(Trip)
    case group(GroupTripSummary)
    case seeAll

    var id: String {
        switch self {
        case let .personal(trip):
            return [
                "personal",
                trip.details.destination.name,
                trip.details.month.rawValue,
                String(trip.details.duration),
                String(trip.createdAt?.timeIntervalSince1970 ?? 0)
            ].joined(separator: ":")
        case let .group(summary):
            return "group:\(summary.groupId)"
        case .seeAll:
            return "see-all"
        }
    }

    var createdAt: Date? {
        switch self {
        case let .personal(trip): trip.createdAt
        case let .group(summary): summary.createdAt
        case .seeAll: nil
        }
    }

    var sortName: String {
        switch self {
        case let .personal(trip): trip.destination
        case let .group(summary): summary.destination
        case .seeAll: ""
        }
    }
}

@MainActor
final class HomeTripsStore: ObservableObject {
    @Published private(set) var items: [HomeTripItem] = []

    private let personalTrips: () throws -> [Trip]
    private let groupTrips: () -> [GroupTripSummary]
    private let calendar: Calendar
    private let now: () -> Date

    init(
        personalTrips: @escaping () throws -> [Trip] = { try SavedTripsStore.loadTrips() },
        groupTrips: @escaping () -> [GroupTripSummary] = { GroupTripCredentialsStore.summaries },
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.personalTrips = personalTrips
        self.groupTrips = groupTrips
        self.calendar = calendar
        self.now = now
    }

    func load() {
        do {
            items = Self.makeItems(
                personal: try personalTrips(),
                groups: groupTrips(),
                now: now(),
                calendar: calendar
            )
        } catch {
            items = Self.makeItems(
                personal: [],
                groups: groupTrips(),
                now: now(),
                calendar: calendar
            )
        }
    }

    nonisolated static func makeItems(
        personal: [Trip],
        groups: [GroupTripSummary],
        now: Date,
        calendar: Calendar
    ) -> [HomeTripItem] {
        let personalItems = personal
            .filter {
                TripStartDate.isCurrentOrUpcoming(
                    createdAt: $0.createdAt,
                    month: $0.details.month,
                    durationDays: $0.details.duration,
                    now: now,
                    calendar: calendar
                )
            }
            .map(HomeTripItem.personal)

        let groupItems = groups
            .filter {
                TripStartDate.isCurrentOrUpcoming(
                    createdAt: $0.createdAt,
                    month: $0.startMonth,
                    durationDays: $0.durationDays,
                    now: now,
                    calendar: calendar
                )
            }
            .map(HomeTripItem.group)

        let sorted = (personalItems + groupItems).sorted { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (left?, right?) where left != right:
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            default:
                return lhs.sortName.localizedCaseInsensitiveCompare(rhs.sortName) == .orderedAscending
            }
        }

        guard sorted.count > 4 else { return sorted }
        return Array(sorted.prefix(4)) + [.seeAll]
    }
}
