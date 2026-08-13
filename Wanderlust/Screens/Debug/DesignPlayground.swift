//
//  DesignPlayground.swift
//  Wanderlust
//
//  Registry of in-progress design explorations, listed in the Debug Menu
//  (triple-tap the Home logo in a DEBUG build). Add an entry whenever you
//  start a new variant; delete the entry (and its screen file) once you've
//  merged it into the real screen or ruled it out.
//

import SwiftUI

/// A single design-exploration entry shown in the Debug Menu's Design Playground list.
struct DesignVariant: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let destination: AnyView

    init<Content: View>(
        id: String,
        title: String,
        subtitle: String,
        @ViewBuilder destination: () -> Content
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.destination = AnyView(destination())
    }
}

enum DesignPlayground {
#if DEBUG
    private static let homeLogoVariants: [DesignVariant] = [
        DesignVariant(
            id: "home-logo-lab",
            title: "Home — Logo Lab",
            subtitle: "Ten takes on the top block, switchable in place: contour, bleed, signature, chrome, monogram, headline, editorial, compact, greeting, letterpress."
        ) {
            HomeLogoLab()
        }
    ]
    private static let tripHeaderVariants: [DesignVariant] = [
        DesignVariant(
            id: "trip-header-native-lockup",
            title: "Trip Header 1 — Native Lockup",
            subtitle: "Highest and most consistent: icon, title and subtitle live inside the standard navigation bar."
        ) {
            TripHeaderConceptLab(style: .nativeLockup)
        },
        DesignVariant(
            id: "trip-header-leading-lockup",
            title: "Trip Header 2 — Leading Lockup",
            subtitle: "Compact and branded: a small icon badge leads a title and essential subtitle beneath the navigation bar."
        ) {
            TripHeaderConceptLab(style: .leadingLockup)
        },
        DesignVariant(
            id: "trip-header-centered-signature",
            title: "Trip Header 3 — Centered Signature",
            subtitle: "Closest to today: the centered icon, title and subtitle are tightened into a smaller deliberate signature."
        ) {
            TripHeaderConceptLab(style: .centeredSignature)
        }
    ]
    private static let outputVariants: [DesignVariant] = [
        DesignVariant(
            id: "output-eval-samples",
            title: "Trip Output — real evaluation output",
            subtitle: "Eight destinations of actual model output from the §13 matrix run, in the real screen. For judging factuality, which nothing offline can score."
        ) {
            EvalSampleBrowser()
        }
    ]
#else
    private static let homeLogoVariants: [DesignVariant] = []
    private static let tripHeaderVariants: [DesignVariant] = []
    private static let outputVariants: [DesignVariant] = []
#endif

    /// Registry of in-progress design explorations. Add/remove entries here.
    static let variants: [DesignVariant] = homeLogoVariants + tripHeaderVariants + outputVariants
}
