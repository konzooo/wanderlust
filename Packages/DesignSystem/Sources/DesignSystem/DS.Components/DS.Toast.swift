//
//  ToastView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/12/25.
//

import SwiftUI

/// Reusable lightweight toast. A title-only toast renders as a compact capsule;
/// a toast with supporting text expands into a small material card.
/// Call `toast(.success, ...)` on any View (see extension below).
import SwiftUI

public extension DS {
    public struct Toast: View {
        public enum Style {
            case success, error, info

            var tint: Color {
                switch self {
                case .success:
                    return Color(red: 0.65, green: 0.85, blue: 0.65)
                case .error:
                    return Color(red: 0.91, green: 0.63, blue: 0.63)
                case .info:
                    return Color(red: 0.57, green: 0.75, blue: 0.90)
                }
            }

            var iconName: String {
                switch self {
                case .success: return "checkmark"
                case .error:   return "xmark"
                case .info:    return "info"
                }
            }
        }

        public enum Position {
            case top
            case bottom
        }

        let style: Style
        let title: String
        let subtitle: String?

        @ViewBuilder
        public var body: some View {
            if subtitle == nil {
                toastContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1))
                    .shadow(color: .black.opacity(0.16), radius: 16, y: 7)
                    .padding(.horizontal, 16)
                    .accessibilityElement(children: .combine)
            } else {
                toastContent
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(style.tint)
                            .opacity(0.9)
                    )
                    .padding(.horizontal)
                    .accessibilityElement(children: .combine)
            }
        }

        private var toastContent: some View {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(subtitle == nil ? compactTint : style.tint.opacity(0.7))
                        .frame(width: 26, height: 26)

                    Image(systemName: style.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(subtitle == nil ? DS.Typography.tabLabel : .headline)

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                    }
                }
                .foregroundStyle(.primary)

                if subtitle != nil {
                    Spacer(minLength: 0)
                }
            }
        }

        private var compactTint: Color {
            switch style {
            case .success: Color.appTint
            case .error, .info: style.tint
            }
        }
    }
}

#Preview {
    DS.Toast(
        style: .success,
        title: "Thanks for the feedback" ,
        subtitle: "It means a lot to us 🫶🏻"
    )
}

//.toast(
//    style: .success,
//    title: "Thanks for the feedback" ,
//    subtitle: "It means a lot to us 🫶🏻",
//    isPresented: $present,
//    position: .top
//)
