//
//  SplashLab.swift
//  DesignSystem
//
//  Harness for the launch animation, shown in the Debug Menu's Design
//  Playground. Judging motion from stills or from a preview canvas is guesswork
//  — this replays it full-screen on device, and cross-fades into a stand-in for
//  the first screen so the hand-off can be checked without relaunching.
//

import SwiftUI

public struct SplashLab: View {
    /// Bumped to tear down and rebuild the splash, which is how a replay works
    /// when the choreography runs off `onAppear`.
    @State private var run = 0
    @State private var showHandoff = false
    @State private var finished = false

    public init() {}

    public var body: some View {
        ZStack {
            // The splash layers ignore the safe area and redraw every frame;
            // neither has anything to tap, so they are taken out of hit testing
            // entirely rather than left to compete with the controls.
            SplashView { finished = true }
                .id(run)
                .allowsHitTesting(false)

            if showHandoff && finished {
                handoffTarget
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            controls
                .zIndex(1)
        }
        .animation(.easeInOut(duration: 0.35), value: finished)
        .ignoresSafeArea()
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Stands in for the first real screen, to check that the aurora does not
    /// visibly jump when the splash cross-fades out. It is deliberately the
    /// same backdrop at the same density.
    private var handoffTarget: some View {
        ZStack {
            SplashAurora(bloom: 1, drift: 0)
            VStack(spacing: 16) {
                Text("First screen")
                    .font(.kanitMedium(22))
                    .foregroundStyle(Color.darkGray)
                Text("The backdrop should not move when this arrives.")
                    .font(.kanitLight(13))
                    .foregroundStyle(Color.darkGray.opacity(0.7))
            }
        }
    }

    private var controls: some View {
        VStack {
            Spacer()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        finished = false
                        run += 1
                    } label: {
                        Label("Replay", systemImage: "arrow.counterclockwise")
                            .font(.kanitMedium(14))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.appTint.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.appTint)

                    Toggle(isOn: $showHandoff) {
                        Text("Hand-off").font(.kanitMedium(13))
                    }
                    .toggleStyle(.switch)
                    .fixedSize()
                }

                Text(String(format: "%.2fs", SplashView.duration))
                    .font(.kanitLight(11))
                    .foregroundStyle(Color.darkGray.opacity(0.6))
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
    }
}

#if DEBUG
#Preview("Splash Lab") { SplashLab() }
#endif
