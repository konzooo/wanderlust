import Foundation

/*

 Degrees will be passed as Double between 0 and 360 where 0 points to top and 180 points to bottom.

 0
 |
 |
 |
 270--------------90
 |
 |
 |
 180

 */

public enum CardControl {
    case swipe(SwipeDirection)
    case undo
}

public protocol Direction {
    /// Converts a Double (degrees) into a directional case (Self).
    static func direction(degrees: Double) -> Self?
    func rawValue() -> String
}

public enum LeftRight: String, Direction {
    case left, right

    public static func direction(degrees: Double) -> Self? {
        switch degrees {
        case 045..<135: return .right
        case 225..<315: return .left
        default: return nil
        }
    }

    public func rawValue() -> String {
        self.rawValue
    }
}

public enum SwipeDirection: String, Direction {
    case left, top, right

    public static func direction(degrees: Double) -> Self? {
        switch degrees {
        case 045..<135: return .right
        case 225..<315: return .left
        case 315..<360, 0..<045: return .top
        default: return nil
        }
    }

    public func rawValue() -> String {
        self.rawValue
    }
}

public enum FourDirections: String, Direction {
    case top, right, bottom, left

    public static func direction(degrees: Double) -> Self? {
        switch degrees {
        case 045..<135: return .right
        case 135..<225: return .bottom
        case 225..<315: return .left
        default: return .top
        }
    }

    public func rawValue() -> String {
        self.rawValue
    }

}

public enum EightDirections: String, Direction {
    case top, right, bottom, left, topLeft, topRight, bottomLeft, bottomRight

    public static func direction(degrees: Double) -> Self? {
        switch degrees {
        case 022.5..<067.5: return .topRight
        case 067.5..<112.5: return .right
        case 112.5..<157.5: return .bottomRight
        case 157.5..<202.5: return .bottom
        case 202.5..<247.5: return .bottomLeft
        case 247.5..<292.5: return .left
        case 292.5..<337.5: return .topLeft
        default: return .top
        }
    }

    public func rawValue() -> String {
        self.rawValue
    }

}
