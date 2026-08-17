//
//  SplashKit.swift
//  DesignSystem
//
//  Shared pieces behind the launch animation: the animatable aurora and the
//  per-letter wordmark.
//
//  Three rules the splash obeys, because one that breaks them is a design
//  failure however good it looks:
//
//  1. It is time-boxed and never waits on the network. Whoever presents it gets
//     `onFinished` on a fixed schedule; if the app's data is not ready by then,
//     the app appears with skeletons.
//  2. Reduce Motion collapses it to a short cross-fade rather than a slower
//     version of the same choreography.
//  3. It is a cold-launch event. Presenting it on every foreground is what
//     turns a signature moment into a toll booth.
//

import SwiftUI

// MARK: - Host

/// Presents the launch animation and calls `onFinished` when it ends — or
/// almost immediately when Reduce Motion is on.
public struct SplashView: View {
    /// Total wall-clock time before `onFinished`, in the full-motion case.
    public static let duration: Double = 1.55
    /// What Reduce Motion gets instead: long enough to register, short enough
    /// not to be a wait.
    public static let reducedDuration: Double = 0.5

    private let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(onFinished: @escaping () -> Void = {}) {
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            if reduceMotion {
                ReducedMotionSplash()
            } else {
                AuroraBloomSplash()
            }
        }
        .task {
            try? await Task.sleep(
                for: .seconds(reduceMotion ? Self.reducedDuration : Self.duration)
            )
            onFinished()
        }
    }
}

/// Reduce Motion gets the same composition with no choreography — the brand
/// still lands, nothing moves.
struct ReducedMotionSplash: View {
    @State private var shown = false

    var body: some View {
        ZStack {
            SplashAurora(bloom: 1, drift: 0)
            VStack(spacing: 26) {
                PinPlaneMark(size: 78)
                Wordmark(reveal: 1, letterLift: 0)
            }
        }
        .opacity(shown ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: shown)
        .onAppear { shown = true }
    }
}

// MARK: - Aurora

/// The `AuroraBackground` blobs, made animatable.
///
/// `bloom` scales and fades the blobs in from the centre; `drift` is a
/// continuous 0...1 phase that keeps them slowly moving so the backdrop is
/// never a frozen image behind a moving logo.
///
/// Public because the onboarding flow opens on the same aurora the splash ends
/// on: at `bloom: 1` this is the app's own backdrop density, so splash and
/// welcome are one continuous scene rather than two that cut.
public struct SplashAurora: View {
    public var bloom: Double
    public var drift: Double

    public init(bloom: Double, drift: Double) {
        self.bloom = bloom
        self.drift = drift
    }

    private struct Blob {
        let color: Color
        let size: CGFloat
        let offset: CGSize
        let travel: CGSize
        let blur: CGFloat
    }

    private static let blobs: [Blob] = [
        Blob(color: Color.appTint.opacity(0.32), size: 340,
             offset: CGSize(width: -140, height: -280),
             travel: CGSize(width: 26, height: 18), blur: 90),
        Blob(color: Color.lightPurple.opacity(0.28), size: 300,
             offset: CGSize(width: 160, height: -180),
             travel: CGSize(width: -22, height: 24), blur: 80),
        Blob(color: Color(red: 1.0, green: 0.85, blue: 0.55).opacity(0.35), size: 320,
             offset: CGSize(width: 140, height: 360),
             travel: CGSize(width: 18, height: -28), blur: 90)
    ]

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.gradientTop, Color.white, Color.gradientBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            ForEach(Array(Self.blobs.enumerated()), id: \.offset) { index, blob in
                // Each blob leads the next slightly, so the bloom opens as a
                // wave instead of a single pulse.
                let lead = max(0, min(1, bloom * 1.35 - Double(index) * 0.12))
                let phase = drift + Double(index) * 0.33

                Circle()
                    .fill(blob.color)
                    .frame(width: blob.size, height: blob.size)
                    .blur(radius: blob.blur)
                    .scaleEffect(0.45 + 0.55 * lead)
                    .opacity(lead)
                    .offset(
                        x: blob.offset.width * lead + blob.travel.width * sin(phase * 2 * .pi),
                        y: blob.offset.height * lead + blob.travel.height * cos(phase * 2 * .pi)
                    )
            }
        }
        .ignoresSafeArea()
    }
}

/// Drives a slow, never-ending drift phase for the aurora.
public struct DriftingAurora<Content: View>: View {
    public var bloom: Double
    @ViewBuilder public var content: (Double) -> Content

    public init(bloom: Double, @ViewBuilder content: @escaping (Double) -> Content) {
        self.bloom = bloom
        self.content = content
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // 14s loop: slow enough to read as atmosphere, not as motion.
            let phase = (t.truncatingRemainder(dividingBy: 14)) / 14
            ZStack {
                SplashAurora(bloom: bloom, drift: phase)
                content(phase)
            }
        }
    }
}

// MARK: - Wordmark

/// WANDERLUST, drawn per-letter so the reveal can stagger.
///
/// The letterforms are Kanit rather than traced outlines of `app-logo`; that is
/// the one place this stops being a faithful vector rebuild. Swapping in a
/// traced path later only changes this view.
struct Wordmark: View {
    /// 0...1 across the whole word. Each letter consumes a slice.
    var reveal: Double
    /// How far, in points, an un-revealed letter sits below its final position.
    var letterLift: CGFloat = 14
    var size: CGFloat = 30

    private static let letters = Array("WANDERLUST")

    var body: some View {
        HStack(spacing: size * 0.14) {
            ForEach(Array(Self.letters.enumerated()), id: \.offset) { index, letter in
                let start = Double(index) / Double(Self.letters.count) * 0.55
                let local = max(0, min(1, (reveal - start) / 0.45))

                Text(String(letter))
                    .font(.kanitMedium(Float(size)))
                    .foregroundStyle(Color.appTint)
                    .opacity(local)
                    .offset(y: letterLift * (1 - local))
                    .scaleEffect(0.86 + 0.14 * local, anchor: .bottom)
            }
        }
        .compositingGroup()
    }
}

/// The subtitle beat, held back until the mark has landed.
struct SplashTagline: View {
    var opacity: Double

    var body: some View {
        Text("Your unique path starts here")
            .font(.kanitLightItalic(14))
            .foregroundStyle(Color.darkGray.opacity(0.75))
            .opacity(opacity)
    }
}
