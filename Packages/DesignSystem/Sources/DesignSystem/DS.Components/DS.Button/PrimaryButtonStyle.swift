//
//  PrimaryButtonStyle.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 12/6/25.
//


import SwiftUI

//public struct PrimaryButtonStyle: ButtonStyle {
//    var fullWidth: Bool = false
//    
//    public init(fullWidth: Bool = false) {
//        self.fullWidth = fullWidth
//    }
//    
//    public func makeBody(configuration: Configuration) -> some View {
//        configuration.label
//            .font(.kanit(20))
//            .frame(maxWidth: fullWidth ? .infinity : nil)
//            .padding(.vertical, 12)
//            .padding(.horizontal, 22)
//            .background(
//                RoundedRectangle(cornerRadius: 14, style: .continuous)
//                    .fill(Color.appTint)            // the same indigo you use elsewhere
//                    .shadow(radius: 4)
//            )
//            .foregroundColor(.white)
//            .opacity(configuration.isPressed ? 0.75 : 1)
//            .scaleEffect(configuration.isPressed ? 0.97 : 1)
//            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
//    }
//}

public struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    public init(fullWidth: Bool = false) {
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryButton(
            configuration: configuration,
            fullWidth: fullWidth
        )
    }

    private struct PrimaryButton: View {
        let configuration: Configuration
        let fullWidth: Bool

        // ← read the enabled/disabled flag
        @Environment(\.isEnabled) private var isEnabled: Bool

        var body: some View {
            configuration.label
                .font(.kanit(20))
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .padding(.vertical, 12)
                .padding(.horizontal, 22)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat.Radius.control, style: .continuous)
                        .fill(Color.appTint)
                        .shadow(radius: 4)
                )
                .foregroundColor(.white)
                // ← if disabled, dim to 40%; else show press-state opacity
                .opacity(!isEnabled
                         ? 0.5
                         : (configuration.isPressed ? 0.75 : 1)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}
