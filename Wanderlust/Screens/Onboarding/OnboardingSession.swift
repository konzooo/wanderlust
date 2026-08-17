//
//  OnboardingSession.swift
//  Wanderlust
//
//  Launch-scoped presentation state, for the intros that persist a "seen" flag
//  only when the user commits to something.
//
//  The Traveller DNA intro is the case that needs it. "Maybe later" deliberately
//  does not persist anything — the user hasn't declined, they've deferred — but
//  the Profile tab presents it as a full-screen cover on tab activation, so
//  without a launch-scoped guard "later" would mean "again in four seconds".
//
//  Deliberately not `@AppStorage`: a snooze that survives reinstalls is a
//  different feature, and one nobody asked for. This resets on cold launch,
//  which is the same lifetime the splash uses for the same reason.
//

import Foundation

@MainActor
final class OnboardingSession: ObservableObject {
    static let shared = OnboardingSession()

    private init() {}

    /// Set once the DNA intro has been presented in this process, whatever the
    /// user did with it.
    var didShowDNAIntroThisLaunch = false

    /// Cleared by the debug menu's "Reset onboarding", so the flow can be
    /// re-tested without reinstalling.
    func reset() {
        didShowDNAIntroThisLaunch = false
    }
}
