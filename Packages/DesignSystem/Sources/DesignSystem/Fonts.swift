import SwiftUI

public extension Font {
    static func kanit(_ customSize: Float) -> Font { Font.custom("Kanit-Regular", size: CGFloat(customSize)) }
    static func kanitThin(_ customSize: Float) -> Font { Font.custom("Kanit-Thin", size: CGFloat(customSize)) }
    static func kanitLight(_ customSize: Float) -> Font { Font.custom("Kanit-Light", size: CGFloat(customSize)) }
    static func kanitBold(_ customSize: Float) -> Font { Font.custom("Kanit-Bold", size: CGFloat(customSize)) }
    static func kanitItalic(_ customSize: Float) -> Font { Font.custom("Kanit-Italic", size: CGFloat(customSize)) }
    static func kanitMedium(_ customSize: Float) -> Font { Font.custom("Kanit-Medium", size: CGFloat(customSize)) }
    static func kanitBoldItalic(_ customSize: Float) -> Font { Font.custom("Kanit-BoldItalic", size: CGFloat(customSize)) }
    static func kanitMediumItalic(_ customSize: Float) -> Font { Font.custom("Kanit-MediumItalic", size: CGFloat(customSize)) }
    static func kanitLightItalic(_ customSize: Float) -> Font { Font.custom("Kanit-LightItalic", size: CGFloat(customSize)) }
}
