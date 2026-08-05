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

    /// Know Before You Go ships as a visible placeholder on purpose: the tab is
    /// part of the shell being reviewed, and it says plainly that its content is
    /// still coming rather than pretending to be empty.
    static let knowBeforeYouGoEnabled = true
}
