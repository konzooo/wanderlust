//
//  AuroraBloomSplash.swift
//  DesignSystem
//
//  The launch animation. The aurora opens from the centre, the pin settles in
//  and pulses once with a ring going out of it, and the wordmark rises.
//
//  It stays symmetrical the whole way through: everything grows from the centre
//  outward, so there is never a frame with weight hanging off one corner.
//
//  It ends on the aurora at exactly the density the rest of the app uses, so the
//  hand-off to the first screen is a straight cross-fade with nothing visibly
//  cutting.
//

import SwiftUI

struct AuroraBloomSplash: View {
    @State private var bloom: Double = 0
    @State private var pinScale: Double = 0.6
    @State private var pinOpacity: Double = 0
    @State private var ringProgress: Double = 0
    @State private var wordReveal: Double = 0
    @State private var taglineOpacity: Double = 0

    private let markSize: CGFloat = 76

    var body: some View {
        DriftingAurora(bloom: bloom) { _ in
            VStack(spacing: 22) {
                markStage
                wordmarkStage
            }
        }
        .task { await choreograph() }
    }

    // MARK: Stages

    private var markStage: some View {
        ZStack {
            // Ring pulse, born with the pin's beat and outliving it.
            Circle()
                .stroke(Color.appTint.opacity(0.5 * (1 - ringProgress)),
                        lineWidth: 2.5 * (1 - ringProgress) + 0.5)
                .frame(width: markSize, height: markSize)
                .scaleEffect(0.7 + ringProgress * 2.4)
                .opacity(ringProgress > 0 ? 1 : 0)

            PinPlaneMark(size: markSize)
                .scaleEffect(pinScale)
                .opacity(pinOpacity)
        }
        .frame(height: markSize * 1.3)
    }

    private var wordmarkStage: some View {
        VStack(spacing: 14) {
            Wordmark(reveal: wordReveal, size: 28)
            SplashTagline(opacity: taglineOpacity)
        }
    }

    // MARK: Choreography

    private func choreograph() async {
        // 0.00 — the aurora opens.
        withAnimation(.spring(response: 0.85, dampingFraction: 0.82)) { bloom = 1 }

        // 0.10 — the pin arrives, scaling up out of the centre.
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation(.easeOut(duration: 0.35)) { pinOpacity = 1 }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { pinScale = 1 }

        // 0.55 — the beat: the pin pushes past its size and the ring goes out.
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.45)) { pinScale = 1.08 }
        withAnimation(.easeOut(duration: 0.9)) { ringProgress = 1 }

        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { pinScale = 1 }

        // 0.67 — the word rises while the ring is still travelling.
        withAnimation(.easeOut(duration: 0.55)) { wordReveal = 1 }

        // 1.07 — the tagline, last and quietest.
        try? await Task.sleep(for: .milliseconds(400))
        withAnimation(.easeOut(duration: 0.4)) { taglineOpacity = 1 }
    }
}

#if DEBUG
#Preview("Aurora Bloom") { AuroraBloomSplash() }
#endif
