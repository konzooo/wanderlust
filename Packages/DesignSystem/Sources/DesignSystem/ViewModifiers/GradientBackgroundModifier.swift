//
//  GradientBackground.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 10/6/25.
//


import SwiftUI

struct GradientBackgroundModifier: ViewModifier {
    let topColor: Color
    let bottomColor: Color

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [topColor, bottomColor]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    public func gradientBackground(
        topColor: Color = Color.gradientTop,
        bottomColor: Color = Color.gradientBottom
    ) -> some View {
        self.modifier(GradientBackgroundModifier(topColor: topColor, bottomColor: bottomColor))
    }
}
