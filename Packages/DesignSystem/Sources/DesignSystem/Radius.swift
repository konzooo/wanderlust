import Foundation

extension CGFloat {
    public enum Radius {
        /// Small clipped elements & bordered form fields.
        public static let compact: CGFloat = 8
        /// Text inputs & input-adjacent backgrounds.
        public static let field: CGFloat = 12
        /// Buttons — kept isolated from Card sizes even where they coincide today.
        public static let control: CGFloat = 14
        /// Small content cards (itinerary card, swipe cards, secret-tip callout).
        public static let cardSmall: CGFloat = 16
        /// Full-bleed photo surfaces (Home hero image).
        public static let image: CGFloat = 20
        /// Large content cards (form card, Saved Trip card).
        public static let cardLarge: CGFloat = 24
    }
}
