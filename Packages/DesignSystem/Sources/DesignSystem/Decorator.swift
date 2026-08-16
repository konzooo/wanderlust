//
//  DesignSystem.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 10/6/25.
//
import SwiftUI

public enum DS {
    @MainActor public static func applyUniformDesign() {
        UISegmentedControl.applyAppTint(UIColor(Color.appTint))
        UITabBar.applyUniformAppearance(tint: UIColor(Color.appTint))
    }
}

extension UITabBar {
    static func applyUniformAppearance(tint: UIColor) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground

        let proxy = UITabBar.appearance()
        proxy.standardAppearance = appearance
        proxy.scrollEdgeAppearance = appearance
        proxy.tintColor = tint
    }
}

extension UISegmentedControl {
    /// Applies bold text + custom tint when a segment is selected
    /// and keeps the default system colour when it isn’t.
    static func applyAppTint(_ tint: UIColor, fontSize: CGFloat = 12) {
        let selected: [NSAttributedString.Key: Any] = [
            .foregroundColor: tint,
            .font: UIFont.boldSystemFont(ofSize: fontSize)
        ]

        let normal: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: fontSize)
        ]

        let appearance = UISegmentedControl.appearance()
        appearance.setTitleTextAttributes(normal,    for: .normal)
        appearance.setTitleTextAttributes(selected,  for: .selected)
    }
}
