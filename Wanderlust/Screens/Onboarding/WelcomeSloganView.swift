//
//  WelcomeSloganView.swift
//  Wanderlust
//
//  The promise page's sentence — page 1 of `WelcomeScreen`.
//
//  Two earlier passes tried to make the sentence itself the performance: first
//  a character-by-character typewriter, then a two-clause reveal with a
//  baseline lift on the second half. Both asked the reader to watch the words
//  arrive before they could read them, and neither earned its keep against the
//  simplest option — just show the sentence.
//
//  This drops the performance. The sentence appears once, as a whole, the way
//  a well-set page simply *is* rather than *becomes*. The only thing that
//  keeps moving afterwards is a very slow, very quiet glow breathing behind
//  the two highlighted phrases — its amplitude is tuned to "is that actually
//  moving?" rather than to anything demonstrative. It borrows its 11s pacing
//  from `DriftingAurora`, which is already breathing behind the whole page, so
//  the two read as one atmosphere instead of competing for attention.
//

import DesignSystem
import SwiftUI

struct WelcomeSloganView: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isIn = false
    @State private var hasPlayed = false

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || !isIn)) { timeline in
            sentence
                .multilineTextAlignment(.leading)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background { glow(at: timeline.date) }
                .opacity(isIn ? 1 : 0)
                .offset(y: isIn ? 0 : 10)
                .accessibilityLabel(WelcomeSlogan.plainText)
        }
        .onChange(of: isActive, initial: true) { _, active in
            guard active, !hasPlayed else { return }
            hasPlayed = true
            Task { await enter() }
        }
    }

    // MARK: Sentence

    private var sentence: Text {
        WelcomeSlogan.runs.reduce(Text("")) { $0 + styled($1) }
    }

    private func styled(_ run: WelcomeSlogan.Run) -> Text {
        guard run.isHighlighted else {
            return Text(run.text)
                .font(.kanitLight(29))
                .foregroundStyle(Color(hex: "#2A2F45").opacity(0.88))
        }

        return Text(run.text)
            .font(.kanitMedium(29))
            .foregroundStyle(
                LinearGradient(colors: [Color.appTint, Color(hex: "#8B6BF6")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
    }

    // MARK: Glow

    /// One soft field behind the whole sentence rather than one glow per
    /// highlighted phrase. Two independent glows on a two-line block read as a
    /// UI effect chasing the words; a single wide, faint bloom reads as the
    /// thought itself quietly lit.
    private func glow(at date: Date) -> some View {
        let t = date.timeIntervalSinceReferenceDate
        let phase = (t.truncatingRemainder(dividingBy: 11)) / 11
        let level = 0.05 + 0.05 * (0.5 + 0.5 * sin(phase * 2 * .pi))

        return Ellipse()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#8B6BF6").opacity(level), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 230
                )
            )
            .blur(radius: 30)
            .padding(-36)
            .accessibilityHidden(true)
    }

    // MARK: Entrance

    private func enter() async {
        guard !reduceMotion else {
            isIn = true
            return
        }

        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.82)) { isIn = true }
    }
}

#if DEBUG
#Preview("Slogan") {
    ZStack {
        DriftingAurora(bloom: 1) { _ in Color.clear }
        WelcomeSloganView(isActive: true)
            .padding(.horizontal, 28)
    }
}
#endif
