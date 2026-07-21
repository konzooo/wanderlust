//
//  ToastView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/12/25.
//

import SwiftUI

/// Reusable toast/banner resembling the screenshot.
/// Call `toast(.success, ...)` on any View (see extension below).
import SwiftUI

public extension DS {
    public struct Toast: View {
        public enum Style {
            case success, error, info

            var tint: Color {
                switch self {
                case .success:
                    return Color(red: 0.65, green: 0.85, blue: 0.65) // #A7D9A7
                case .error:
                    return Color(red: 0.91, green: 0.63, blue: 0.63) // #E9A1A1
                case .info:
                    return Color(red: 0.57, green: 0.75, blue: 0.90) // #92BEE6
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

        public var body: some View {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(style.tint.opacity(0.7))
                        .frame(width: 28, height: 28)

                    Image(systemName: style.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                .alignmentGuide(VerticalAlignment.center) { d in d[VerticalAlignment.center] }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline).bold()

                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                    }
                }
                .foregroundColor(.primary)

                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(style.tint)
                    .opacity(0.9)
            )
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityElement(children: .combine)
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

