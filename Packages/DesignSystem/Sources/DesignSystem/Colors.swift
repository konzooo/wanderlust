//
//  Colors.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/1/25.
//

import SwiftUI

public extension Color {
    static let appTint: Self = Color(hex: "#586FF2")
    
    // UI
    static let infoCardBkg: Self = Color(hex: "#E1E1E1")
    static let popoverBackground: Self = Color(hex: "#F1EBDF")
    static let buttonText: Self = Color(hex: "#F5F5F5")
    static let border: Self = Color(hex: "#2C2C2C")
    static let textLink: Self = Color(hex: "#0A84FF")
    
    // Palette
    static let lightPurple: Self = Color(hex: "#6B84F6")
    static let darkGray: Self = Color(hex: "#363636")
    
    // Gradient
    static let gradientTop: Self = Color(red: 0.9, green: 0.95, blue: 1.0)
    static let gradientBottom: Self = Color(red: 1.0, green: 0.94, blue: 0.8)

    // Suggestions (alternating section backgrounds)
    static let suggestionTintA: Self = Color(hex: "#D8E3EE")
    static let suggestionTintB: Self = Color(hex: "#F1F6FA")
}

