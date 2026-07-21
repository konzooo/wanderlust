import SwiftUI

public struct CardStackConfiguration: EnvironmentKey, Sendable {
    public static let defaultValue = CardStackConfiguration()

    let maxVisibleCards: Int
    let swipeThreshold: Double
    let cardOffset: CGFloat
    let cardScale: CGFloat
    let animation: Animation
    let animationDuration: CGFloat

    public init(
        maxVisibleCards: Int = 5,
        swipeThreshold: Double = 0.5,
        cardOffset: CGFloat = 10,
        cardScale: CGFloat = 0.1,
        animationDuration: CGFloat = 0.48,
        animation: Animation? = nil
    ) {
        self.maxVisibleCards = maxVisibleCards
        self.swipeThreshold = swipeThreshold
        self.cardOffset = cardOffset
        self.cardScale = cardScale
        self.animationDuration = animationDuration
        if let animation {
            self.animation = animation
        } else {
            self.animation = .easeOut(duration: animationDuration)
        }
    }
}

extension EnvironmentValues {
    public var cardStackConfiguration: CardStackConfiguration {
        get { self[CardStackConfiguration.self] }
        set { self[CardStackConfiguration.self] = newValue }
    }
}
