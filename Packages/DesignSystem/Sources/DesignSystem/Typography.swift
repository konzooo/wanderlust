import SwiftUI

/// Semantic type roles — the named design-system scale for text.
/// Prefer these over raw `.kanit*()` calls when the text matches one of these jobs.
extension DS {
    public enum Typography {
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
    }
}
