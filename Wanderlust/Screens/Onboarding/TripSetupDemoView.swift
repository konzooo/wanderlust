//
//  TripSetupDemoView.swift
//  Wanderlust
//
//  Step 1 of `WelcomeScreen`: the whole setup, not just the destination.
//
//  Plays the real Basic Info form in miniature — where, how long, when — so
//  "a few basics" is something the viewer watches take about four seconds
//  rather than a claim they have to take on trust.
//
//  Deck order starts on `Card5` (History & Culture vs Modern Life), which poses
//  a sharper question than the city-vs-landscape card and reads better small.
//

import DesignSystem
import SwiftUI

struct TripSetupDemoView: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var typedCount = 0
    @State private var revealedFields = 0
    @State private var showsDeck = false
    @State private var topCard = 0
    @State private var flyDirection: [Int: CGFloat] = [:]
    @State private var loop: Task<Void, Never>?

    private static let destination = "Lisbon"
    private static let cards = ["Card5", "Card2", "Card3"]

    private let cardWidth: CGFloat = 172
    private let cardHeight: CGFloat = 232

    var body: some View {
        ZStack {
            setupCard
                .opacity(showsDeck ? 0 : 1)
                .scaleEffect(showsDeck ? 0.95 : 1)

            deck
                .opacity(showsDeck ? 1 : 0)
                .scaleEffect(showsDeck ? 1 : 0.95)
        }
        .frame(height: cardHeight + 22)
        .accessibilityElement()
        .accessibilityLabel("A trip is set up — Lisbon, five days in June — then travel style cards are swiped")
        .onChange(of: isActive, initial: true) { _, active in
            active ? start() : stop()
        }
        .onDisappear(perform: stop)
    }

    // MARK: Setup form

    /// The Basic Info card at a quarter scale: the same three questions in the
    /// same order, on the same glass.
    private var setupCard: some View {
        VStack(spacing: 0) {
            field(icon: "mappin.circle.fill", label: "Where to?") {
                HStack(spacing: 0) {
                    Text(String(Self.destination.prefix(typedCount)))
                        .font(.kanitMedium(15))
                        .foregroundStyle(Color(hex: "#2A2F45"))

                    if typedCount < Self.destination.count {
                        Rectangle()
                            .fill(Color.appTint)
                            .frame(width: 1.5, height: 16)
                            .padding(.leading, 2)
                    }
                }
            }

            divider

            field(icon: "clock.fill", label: "Trip duration?", shown: revealedFields >= 1) {
                HStack(spacing: 8) {
                    // The slider fill lands where "5 days" sits on the real
                    // control, so the number has something to have come from.
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: 62, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.appTint)
                                .frame(width: revealedFields >= 1 ? 25 : 0, height: 4)
                        }

                    Text("5 days")
                        .font(.kanitMedium(15))
                        .foregroundStyle(Color.appTint)
                }
            }

            divider

            field(icon: "calendar", label: "Start of your trip?", shown: revealedFields >= 2) {
                HStack(spacing: 6) {
                    ForEach(["May", "Jun", "Jul"], id: \.self) { month in
                        let isSelected = month == "Jun"
                        Text(month)
                            .font(.kanit(12).weight(isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? .white : Color(hex: "#2A2F45").opacity(0.45))
                            .fixedSize()
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isSelected ? Color.appTint : .clear, in: Capsule())
                    }
                }
            }
        }
        .padding(14)
        // 300, not 262. At the tighter width the labels and their values fought
        // for the same row and SwiftUI resolved it by wrapping the values one
        // character per line — "5 days" came out as a vertical "5 d a".
        .frame(maxWidth: 300)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.07), radius: 14, y: 6)
    }

    private func field(
        icon: String,
        label: String,
        shown: Bool = true,
        @ViewBuilder value: () -> some View
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.appTint)
                .frame(width: 18)

            Text(label)
                .font(.kanit(12))
                .foregroundStyle(.secondary)
                .fixedSize()

            Spacer(minLength: 8)

            // Values never wrap. They are short by construction, and a wrapped
            // one is always a layout fault rather than a long value.
            value()
                .fixedSize()
        }
        .padding(.vertical, 9)
        .opacity(shown ? 1 : 0)
        .offset(y: shown ? 0 : 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.06))
            .frame(height: 1)
    }

    // MARK: Deck

    private var deck: some View {
        ZStack {
            ForEach(Array(Self.cards.enumerated()), id: \.offset) { index, name in
                let depth = index - topCard

                Image(name)
                    .resizable()
                    .scaledToFill()
                    .frame(width: cardWidth, height: cardHeight)
                    .clipShape(RoundedRectangle(cornerRadius: .Radius.cardSmall, style: .continuous))
                    .shadow(color: .black.opacity(0.16), radius: 12, y: 6)
                    .scaleEffect(depth < 0 ? 1 : 1 - Double(depth) * 0.07)
                    .rotationEffect(.degrees(depth < 0 ? Double(flyDirection[index] ?? 1) * 20 : 0))
                    .offset(
                        x: depth < 0 ? (flyDirection[index] ?? 1) * 340 : 0,
                        y: depth < 0 ? -18 : -CGFloat(depth) * 9
                    )
                    .opacity(depth < 0 ? 0 : (depth > 2 ? 0 : 1))
                    .zIndex(-Double(depth))
            }
        }
    }

    // MARK: Loop

    private func start() {
        guard loop == nil else { return }

        guard !reduceMotion else {
            typedCount = Self.destination.count
            revealedFields = 2
            showsDeck = true
            return
        }

        loop = Task { @MainActor in
            while !Task.isCancelled { await runOnce() }
        }
    }

    private func stop() {
        loop?.cancel()
        loop = nil
    }

    private func runOnce() async {
        reset()
        try? await Task.sleep(for: .milliseconds(320))
        guard !Task.isCancelled else { return }

        for count in 1...Self.destination.count {
            typedCount = count
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
        }

        // Duration, then month — each answered as if by someone deciding, with
        // a beat between. Firing them together would read as a form being
        // filled by a script rather than by a person.
        try? await Task.sleep(for: .milliseconds(360))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { revealedFields = 1 }

        try? await Task.sleep(for: .milliseconds(560))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { revealedFields = 2 }

        try? await Task.sleep(for: .milliseconds(760))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.4)) { showsDeck = true }

        try? await Task.sleep(for: .milliseconds(640))
        guard !Task.isCancelled else { return }
        swipeTop(towards: 1)

        try? await Task.sleep(for: .milliseconds(720))
        guard !Task.isCancelled else { return }
        swipeTop(towards: -1)

        try? await Task.sleep(for: .milliseconds(950))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: 0.35)) { showsDeck = false }
        try? await Task.sleep(for: .milliseconds(430))
    }

    private func swipeTop(towards direction: CGFloat) {
        flyDirection[topCard] = direction
        withAnimation(.easeOut(duration: 0.48)) { topCard += 1 }
    }

    private func reset() {
        typedCount = 0
        revealedFields = 0
        showsDeck = false
        topCard = 0
        flyDirection = [:]
    }
}

#if DEBUG
#Preview("Trip setup demo") {
    ZStack {
        DriftingAurora(bloom: 1) { _ in Color.clear }
        TripSetupDemoView(isActive: true)
    }
}
#endif
