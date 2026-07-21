//
//  Fonts.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/1/25.
//

import Foundation
import SwiftUI

//private extension Bundle {
//    static var module: Bundle {
//        Bundle(for: BundleToken.self)
//    }
//}
//
//private final class BundleToken {}
//
//public enum FontRegistration {
//    public static func registerFonts() {
//        let fontNames = [
//            "Kanit-Regular",
//            "Kanit-Thin",
//            "Kanit-Light",
//            "Kanit-Bold",
//            "Kanit-Italic",
//            "Kanit-MediumItalic",
//            "Kanit-LightItalic"
//        ]
//        
//        for fontName in fontNames {
//            guard let fontURL = Bundle.module.url(forResource: fontName, withExtension: "ttf") else {
//                print("Failed to find font: \(fontName)")
//                continue
//            }
//            
//            guard let fontDataProvider = CGDataProvider(url: fontURL as CFURL) else {
//                print("Failed to load font data provider: \(fontName)")
//                continue
//            }
//            
//            guard let font = CGFont(fontDataProvider) else {
//                print("Failed to create font: \(fontName)")
//                continue
//            }
//            
//            var error: Unmanaged<CFError>?
//            if !CTFontManagerRegisterGraphicsFont(font, &error) {
//                print("Failed to register font: \(fontName)")
//            }
//        }
//    }
//}

//public extension Font {
//    static func kanit(_ customSize: Float) -> Font { Font.custom("Kanit-Regular", size: CGFloat(customSize)) }
//    static func kanitThin(_ customSize: Float) -> Font { Font.custom("Kanit-Thin", size: CGFloat(customSize)) }
//    static func kanitLight(_ customSize: Float) -> Font { Font.custom("Kanit-Light", size: CGFloat(customSize)) }
//    static func kanitBold(_ customSize: Float) -> Font { Font.custom("Kanit-Bold", size: CGFloat(customSize)) }
//    static func kanitItalic(_ customSize: Float) -> Font { Font.custom("Kanit-Italic", size: CGFloat(customSize)) }
//    static func kanitBoldItalic(_ customSize: Float) -> Font { Font.custom("Kanit-BoldItalic", size: CGFloat(customSize)) }
//    static func kanitMediumItalic(_ customSize: Float) -> Font { Font.custom("Kanit-MediumItalic", size: CGFloat(customSize)) }
//    static func kanitLightItalic(_ customSize: Float) -> Font { Font.custom("Kanit-LightItalic", size: CGFloat(customSize)) }
//}

// TEST
//for familyName in UIFont.familyNames {
//    print("Family: \(familyName)")
//    for fontName in UIFont.fontNames(forFamilyName: familyName) {
//        print("  \(fontName)")
//    }
//}
