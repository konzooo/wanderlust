import SwiftUI

/// Semantic type roles — the named design-system scale for text.
/// Prefer these over raw `.kanit*()` calls when the text matches one of these jobs.
///
/// **The rule these encode is content-type, not hierarchy.** Kanit is the app's
/// voice: it renders chrome — titles, tab and segment labels, section headings,
/// eyebrows. Anything the *model* wrote renders in SF Pro Rounded, so generated
/// prose reads as prose and never as another piece of the app's furniture. A
/// heading written by the model is still model text; it does not get Kanit for
/// being a heading.
extension DS {
    public enum Typography {
        // MARK: - Chrome (Kanit)

        /// Big screen-level statement. One size across all weights — weight signals the context.
        public static let displayRegular = Font.kanit(34)
        public static let displayMedium = Font.kanitMedium(34)
        public static let displayLight = Font.kanitLight(34)
        public static let displayBold = Font.kanitBold(34)

        /// Sheet / modal title.
        public static let sheetTitle = Font.kanitItalic(22)

        /// Page subtitle, directly under a Display title.
        public static let subtitle = Font.kanitLight(18)

        /// Label above a sheet form field. Same size as `subtitle` today by
        /// coincidence, not identity — kept separate so the two can diverge later.
        public static let fieldCaption = Font.kanitLight(18)

        /// Field / section label (Next Trip form).
        public static let fieldLabel = Font.kanitMedium(16)

        /// Heading above a content section — a suggestions carousel, a group in
        /// the favourites list.
        public static let sectionHeader = Font.kanitMedium(18)

        /// Title of one segment of content, e.g. a day in the itinerary.
        public static let segmentTitle = Font.kanitMedium(19)

        /// The small italic label introducing a block of generated prose
        /// ("The case", "What to know").
        public static let eyebrow = Font.kanitMediumItalic(15)

        /// Where a favourite came from, shown beside it.
        public static let contextLabel = Font.kanitItalic(14)

        /// Tab-bar and pill-selector labels.
        public static let tabLabel = Font.kanitMedium(14)

        // MARK: - Generated content (SF Pro Rounded)

        /// Model-written prose inside a card.
        public static let generatedBody = Font.system(size: 15, design: .rounded)

        /// Model-written prose as a list row — itinerary items, favourites.
        public static let generatedListItem = Font.system(size: 15.5, design: .rounded)

        /// The name of a place the model chose, used as a card's title. Still
        /// model output, so still Rounded — weight carries the emphasis.
        public static let generatedTitle = Font.system(size: 18, weight: .semibold, design: .rounded)
    }
}
