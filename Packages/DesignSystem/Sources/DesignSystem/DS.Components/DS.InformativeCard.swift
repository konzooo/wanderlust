//
//  DS.InformativeCard.swift
//  DesignSystem
//
//  Created by Rodrigo Mato Castellano on 5/28/25.
//

import SwiftUI

extension DS {
    public struct InformativeCard: View {
        let title: String
        let subtitle: String
        let icon: Image
        let onTap: () -> Void

        @State private var isPressed = false

        public init(title: String, subtitle: String, icon: Image, onTap: @escaping () -> Void, isPressed: Bool = false) {
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.onTap = onTap
            self.isPressed = isPressed
        }

        public var body: some View {
            Button {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = true
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    isPressed = false
                    onTap()
                }
            } label: {
                cardView

            }
            .buttonStyle(PlainButtonStyle())
        }

        var cardView: some View {
            // 1️⃣ Main row -----------------------------------------------------------
            HStack(alignment: .center, spacing: 12) {

                // ICON ---------------------------------------------------------------
//                icon                       // <- use the Image passed in init
//                    .resizable()
//                    .scaledToFit()
//                    .frame(width: 24, height: 24)
                    // If you really want the emoji literal instead, replace
                Text("💡").font(.system(size: 28))
                    .frame(width: 32, alignment: .leading)   // guarantees room

                // TITLE + SUBTITLE --------------------------------------------------
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.kanitItalic(14))
                        .italic()
                        .foregroundColor(.darkGray)

                    Text(subtitle)
                        .font(.kanit(11))
                        .foregroundColor(Color(hex: "#2B2B2B"))
                        .lineLimit(3)                        // up-to 3 lines
                        .fixedSize(horizontal: false,
                                   vertical: true)          // allow wrapping
                }
                .layoutPriority(1)                          // don’t compress
            }
            .padding(.trailing, 40)        // ← leave room for chevron overlay

            // 2️⃣ Chevron pinned on the right ---------------------------------------
            .overlay(
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.trailing, 12),
                alignment: .trailing
            )

            // 3️⃣ Card styling -------------------------------------------------------
            .padding(.Padding.sm2)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.infoCardBkg)
                    .shadow(color: .black.opacity(0.2),
                            radius: 4, x: -2, y: -2)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }

    }
}


#Preview {
    DS.InformativeCard(
        title: "Your Feedback",
        subtitle: "We want to build this app together with you. Give us your feedback and suggestions.",
        icon: Image(systemName: "lightbulb.fill")
    ) {
        print("Card tapped!")
        // Navigate, show sheet, etc.
    }
    .padding()
}
