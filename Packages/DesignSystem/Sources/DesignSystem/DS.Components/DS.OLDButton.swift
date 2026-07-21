//
//  DesignSystem.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/1/25.
//

import Foundation
import SwiftUI

public extension DS {
    public struct OLDButton: View {
        let title: String
        let enabled: Bool
        let font: Font
        let fullWidth: Bool

        let onTap: (() -> Void)?

        public init(
            title: String,
            font: Font,
            enabled: Bool = true,
            fullWidth: Bool = false,
            onTap: (() -> Void)? = nil
        ) {
            self.title = title
            self.font = font
            self.enabled = enabled
            self.fullWidth = fullWidth
            self.onTap = onTap
        }

        public var body: some View {
            Text(title)
                .padding(.vertical, .Padding.sm2)
                .padding(.horizontal, .Padding.md3)
                .frame(maxWidth: fullWidth ? .infinity : nil)

                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(enabled ? Color.appTint : Color.gray)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(enabled ? Color.border : Color.clear, lineWidth: 1)
                )
                .font(font)
                .foregroundColor(.buttonText)
                .conditional(onTap != nil) { view in
                    view.onTapGesture {
                            onTap?()
                        }
                }
                .disabled(!enabled)
        }
    }
}

#Preview {
    DS.OLDButton(title: "Let's go ->", font: .body)
}
