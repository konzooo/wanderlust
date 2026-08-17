//
//  WelcomeSlogan.swift
//  Wanderlust
//
//  The promise page's sentence, as styled runs.
//
//  Kept as an ordered run list rather than one string with ranges: the highlight
//  needs a different weight *and* a gradient fill, which `AttributedString`
//  cannot carry through SwiftUI's `Text`. Concatenating styled `Text` runs can.
//

import Foundation

enum WelcomeSlogan {
    struct Run: Identifiable {
        let id = UUID()
        let text: String
        let isHighlighted: Bool
    }

    static let runs: [Run] = [
        Run(text: "Imagine travelling with a friend who ", isHighlighted: false),
        Run(text: "knows you well",                        isHighlighted: true),
        Run(text: " — and happens to be a ",                isHighlighted: false),
        Run(text: "local wherever you go",                  isHighlighted: true),
        Run(text: ".",                                      isHighlighted: false)
    ]

    /// Full sentence, for the accessibility label — VoiceOver should hear one
    /// sentence, not five fragments.
    static var plainText: String {
        runs.map(\.text).joined()
    }
}
