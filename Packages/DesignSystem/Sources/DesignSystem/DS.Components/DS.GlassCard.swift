//
//  DS.GlassCard.swift
//  DesignSystem
//
//  Frosted-material card used to group form sections over a colored
//  background (Next Trip, Specify Group sheet).
//

import SwiftUI

extension DS {
    public struct GlassCard<Content: View>: View {
        @ViewBuilder var content: Content

        public init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }

        public var body: some View {
            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.07), radius: 10, y: 4)
        }
    }
}

#Preview {
    ZStack {
        LinearGradient(colors: [.gradientTop, .gradientBottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        DS.GlassCard {
            Text("Glass card content")
        }
        .padding()
    }
}
