//
//  OutputFeatureFlags.swift
//  Wanderlust
//
//  What the output shell is allowed to show before the work behind it exists.
//

import Foundation

/// Merge gates for the trip output.
///
/// The shell is built ahead of the content it will eventually hold, so these
/// exist to make "built" and "shipped" different things. A tab whose content is
/// not real yet must not reach a traveller as an empty room — and the way that
/// mistake normally happens is that the shell lands, the flag is implicit, and
/// nobody notices until it is in a build.
enum OutputFeatureFlags {
    /// Near You needs MapKit address grounding, real walking distances and the
    /// device-side privacy boundary before it means anything. Until then the
    /// tab is not offered at all — a "Near You" that guesses distances is worse
    /// than no Near You.
    static let nearYouEnabled = false

    /// Know Before You Go now has real content behind it — its own component,
    /// prompt, schema, persistence and retry — so the tab is live rather than a
    /// placeholder. The flag stays as the off switch: v1's taxonomy is
    /// explicitly provisional and expected to be reworked, and a tab that can be
    /// closed is easier to rework than one that cannot.
    static let knowBeforeYouGoEnabled = true

    /// Interest chips now open append-only deep dives through the backend's D9
    /// cap, persist with the trip, and travel in published solo shares.
    static let interestChipsEnabled = true

    /// Where to stay lives behind "Don't have a place booked yet?" on the Near
    /// You tab (§7), so it is gated with it. The content is generated, saved
    /// and shared now so that S10 has real data to ground against rather than
    /// having to add a call at the same time as the MapKit work.
    static var whereToStayEnabled: Bool { nearYouEnabled }

    /// Which arm of the D15 experiment this build runs.
    ///
    /// Must match `SUGGESTIONS_VARIANT` in
    /// `ConvexBackend/convex/lib/components.ts` — the value is sent with every
    /// request and the two are one decision, recorded twice. See
    /// `ConvexBackend/docs/d15-decision.md` for the measurement behind it.
    static let suggestionsVariant: SuggestionsVariant = .split
}
