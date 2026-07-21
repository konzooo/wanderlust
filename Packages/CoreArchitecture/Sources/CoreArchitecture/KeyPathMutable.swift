import Foundation

/// Protocol defining requirements for component to be a MutableState
/// - Providing default logic to modify properties through key paths.
public protocol KeyPathMutable {
    func modifying<T>(_ keyPath: WritableKeyPath<Self, T>, to value: T) -> Self
}

extension KeyPathMutable {
    /// Modify self with a mutable closure
    /// - Parameter modify: closure including a mutable version of self
    /// - Returns: new modified self
    private func modified(_ update: (inout Self) -> Void) -> Self {
        var viewState = self
        update(&viewState)
        return viewState
    }

    /// Modify a variable through a key path and return the modified self
    /// - Parameters:
    ///   - keyPath: variable key path
    ///   - value: new value
    /// - Returns: modified self
    public func modifying<T>(_ keyPath: WritableKeyPath<Self, T>, to value: T) -> Self {
        modified { $0[keyPath: keyPath] = value }
    }

    /// Mutates a variable through a KeyPath with a new value
    /// - Parameters:
    ///   - keyPath: keypath to the variable
    ///   - value: variable new value
    public mutating func update<T>(_ keyPath: WritableKeyPath<Self, T>, to value: T) {
        self[keyPath: keyPath] = value
    }

    /// Concatenate several key path modification actions
    static func .= <T>(lhs: Self, rhs: (WritableKeyPath<Self, T>, T)) -> Self {
        lhs.modifying(rhs.0, to: rhs.1)
    }
}

infix operator .=: AdditionPrecedence
