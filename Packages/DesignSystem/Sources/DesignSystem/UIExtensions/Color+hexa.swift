//
//  Color+hexa.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/4/25.
//

import SwiftUI

public extension Color {
    init(hex: String) {
        // Remove any leading "#"
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") {
            sanitized.removeFirst()
        }

        // Scan the hexadecimal into an integer
        var rgb: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&rgb)

        // Parse the components
        let r, g, b, a: UInt64
        switch sanitized.count {
        case 6: // RRGGBB
            (r, g, b, a) = ( (rgb & 0xFF0000) >> 16,
                             (rgb & 0x00FF00) >> 8,
                              rgb & 0x0000FF,
                             0xFF )
        case 8: // RRGGBBAA
            (r, g, b, a) = ( (rgb & 0xFF000000) >> 24,
                             (rgb & 0x00FF0000) >> 16,
                             (rgb & 0x0000FF00) >> 8,
                              rgb & 0x000000FF )
        default:
            (r, g, b, a) = (1, 1, 1, 0) // default to white/clear or any fallback
        }

        // Create the Color
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
