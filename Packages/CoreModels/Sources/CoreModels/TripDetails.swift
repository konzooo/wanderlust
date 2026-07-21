import Foundation

extension Trip {
    public struct Details: Equatable, Hashable, Codable, Sendable {
        // This in the future could/should to be specific known location mapped from an automcomplete API ?
        public var destination: Place
        public var members: Members
        public var duration: Int
        public var month: Month
        
        public init(destination: Place = Place(name: ""), members: Members = Members(groupType: .solo), duration: Int = 0, month: Month = .january) {
            self.destination = destination
            self.members = members
            self.duration = duration
            self.month = month
        }
    }
}

extension Trip.Details {
    public struct Members: Hashable, Equatable, Codable, Sendable {
        public var groupType: GroupType
        public var avgAge: Int?
        public var gender: Gender?
        public var customizations: String?

        public init(groupType: GroupType, avgAge: Int? = nil, gender: Gender? = nil, customizations: String? = nil) {
            self.groupType = groupType
            self.avgAge = avgAge
            self.gender = gender
            self.customizations = customizations
        }

        public var stringAvgAge: String? {
            guard let age = avgAge else { return nil }
            return String(age)
        }
    }

    public enum Gender: String, Equatable, Codable, Sendable, CaseIterable {
        case mixed
        case male
        case female

        public static let all: [Gender] = [.male, .female, .mixed]
    }

    public enum GroupType: String, Equatable, Codable, Sendable, CaseIterable {
        case solo
        case couple
        case group
        case family

        public static let all: [GroupType] = [.solo, .couple, .group, .family]
    }
}

public struct Place: Equatable, Hashable, Codable, Sendable {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
}

public enum Month: String, CaseIterable, Identifiable, Equatable, Hashable, Codable, Sendable {
    case january
    case february
    case march
    case april
    case may
    case June
    case July
    case August
    case September
    case october
    case november
    case december
    
    public var id: UUID { UUID() }

    public var simplified: String {
        String(self.rawValue.prefix(3))
    }

    public static let all: [Month] = [.january, .february, .march, .april, .may, .June, .July, .August, .September, .october, .november, .december]
}

public extension Trip.Details {
    static var mock: Self {
        .init(destination: .init(name: "Destination, Country"), members: .init(groupType: .couple), duration: 3, month: .August)
    }
}
