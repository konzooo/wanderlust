//
//  SecondaryButtonStyle.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 12/6/25.
//

import SwiftUI

public struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    var internalPadding: CGFloat
    
    public init(fullWidth: Bool, internalPadding: CGFloat = 12) {
        self.fullWidth = fullWidth
        self.internalPadding = internalPadding
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kanitMedium(18))
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, internalPadding)
            .padding(.horizontal, internalPadding*1.4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.appTint, lineWidth: 2)
                    .background(          // subtle blue-tint fill like your cards
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.blue.opacity(0.06))
                    )
                    .shadow(radius: 2)
            )
            .foregroundColor(Color.appTint)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
