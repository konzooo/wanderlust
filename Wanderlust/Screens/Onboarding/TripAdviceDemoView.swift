//
//  TripAdviceDemoView.swift
//  Wanderlust
//
//  Step 2 of `WelcomeScreen`: one destination photo, three beats of practical
//  content — what to know before you land, what a local would tell you, and
//  what a local would steer you away from.
//
//  No heart icon anywhere on this page, on purpose. Favouriting has its own
//  step later in the flow (`FavouritesCollectDemoView`); a control that never
//  does anything on this particular screen would read as broken, not as a
//  preview of what's coming.
//

import CoreArchitecture
import DesignSystem
import Networking
import SwiftUI

struct TripAdviceDemoView: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Beat { case briefing, advice, avoid }

    @State private var beat: Beat = .briefing
    @State private var contentIn: Double = 1
    @State private var revealedBriefing = 0
    @State private var revealedAdvice = 0
    @State private var revealedAvoid = 0
    @State private var loop: Task<Void, Never>?
    @State private var heroImageURL: AsyncValue<URL> = .initial

    private let imageService = UnsplashService()
    private static let heroQuery = "Lisbon yellow tram 28"

    private struct BriefingItem {
        let icon: String
        let text: String
    }

    private static let briefing: [BriefingItem] = [
        BriefingItem(
            icon: "figure.walk",
            text: "It's steep. Real shoes — and take an Uber even for ten minutes, everyone does."
        ),
        BriefingItem(
            icon: "fork.knife",
            text: "Lunch is 1–3pm, dinner rarely before 8. Kitchens close earlier than you'd think."
        ),
        BriefingItem(
            icon: "bubble.left.and.bubble.right",
            text: "*Bom dia* and *obrigado* — *obrigada* if you're a woman. That's most of it."
        )
    ]

    private static let advice: [String] = [
        "Skip the Santa Justa queue — the walkway from Largo do Carmo reaches the same view, free.",
        "Ask for *uma bica*, not *um café*. It's the only way anyone here orders an espresso."
    ]

    private static let avoid: [String] = [
        "Skip *A Brasileira* for coffee — gorgeous room, tourist prices, forgettable espresso.",
        "Don't agree to a tuk-tuk price after the ride — fix it before you get in, or dinner costs less."
    ]

    /// Warm rather than blue — the one beat on this page telling you what
    /// *not* to do earns a different colour from the two telling you what to.
    private let cautionAmber = Color(hex: "#C2760C")
    private let heroHeight: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            hero
            content
        }
        .frame(maxWidth: 300)
        .frame(height: 300, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
        .accessibilityElement()
        .accessibilityLabel("A Lisbon trip: what's worth knowing before you land, local advice, and what to avoid")
        .onChange(of: isActive, initial: true) { _, active in
            active ? start() : stop()
        }
        .onDisappear(perform: stop)
        .task { await loadHeroImageIfNeeded() }
    }

    // MARK: Hero

    private var hero: some View {
        CacheDestinationImage(cacheKey: "welcome.tripAdviceDemo", imageUrlState: heroImageURL)
            .frame(width: 300, height: heroHeight)
            .clipped()
            .overlay {
                LinearGradient(colors: [.black.opacity(0.14), .black.opacity(0.64)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { heroTitle }
            .frame(height: heroHeight)
            .clipped()
    }

    private func loadHeroImageIfNeeded() async {
        guard case .initial = heroImageURL else { return }
        heroImageURL = .loading
        do {
            let url = try await imageService.fetchImageURL(for: Self.heroQuery)
            heroImageURL = .loaded(url)
        } catch {
            heroImageURL = .error(error)
        }
    }

    private var heroTitle: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Lisbon")
                .font(.kanitMedium(17))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 1)

            HStack(spacing: 5) {
                Image(systemName: "calendar")
                    .font(.system(size: 9, weight: .bold))
                Text("5 days in June")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.92))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 11)
    }

    // MARK: Content

    private var content: some View {
        ZStack(alignment: .top) {
            switch beat {
            case .briefing: briefingContent
            case .advice:   adviceContent
            case .avoid:    avoidContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 13)
        .padding(.top, 12)
        .opacity(contentIn)
    }

    private var briefingContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            label(icon: "lightbulb", text: "Know before you go", tint: Color.appTint)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(Self.briefing.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: item.icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.appTint)
                            .frame(width: 18, height: 18)
                            .background(Color.appTint.opacity(0.13), in: Circle())

                        Text(emphasised(item.text))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .opacity(index < revealedBriefing ? 1 : 0)
                    .offset(y: index < revealedBriefing ? 0 : 6)
                }
            }
        }
    }

    private var adviceContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            label(icon: "figure.walk", text: "Local advice", tint: Color.appTint)

            VStack(spacing: 7) {
                ForEach(Array(Self.advice.enumerated()), id: \.offset) { index, text in
                    factRow(text)
                        .opacity(index < revealedAdvice ? 1 : 0)
                        .offset(y: index < revealedAdvice ? 0 : 8)
                }
            }
        }
    }

    private var avoidContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            label(icon: "exclamationmark.triangle.fill", text: "What to avoid", tint: cautionAmber)

            VStack(spacing: 7) {
                ForEach(Array(Self.avoid.enumerated()), id: \.offset) { index, text in
                    factRow(text)
                        .opacity(index < revealedAvoid ? 1 : 0)
                        .offset(y: index < revealedAvoid ? 0 : 8)
                }
            }
        }
    }

    /// No heart, no accessory — a plain fact card. Step 3 is where hearting
    /// this same kind of row becomes the point. Shared by advice and avoid:
    /// the two beats are told apart by their label above, not by the card
    /// shape underneath it.
    private func factRow(_ text: String) -> some View {
        Text(emphasised(text))
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
            .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.black.opacity(0.05), lineWidth: 1)
            }
    }

    private func label(icon: String, text: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.kanitMedium(12))
        }
        .foregroundStyle(tint)
    }

    /// The font is set per run so the italic on `*uma bica*` survives, which
    /// a `.font()` modifier on the whole `Text` would strip.
    private func emphasised(_ text: String) -> AttributedString {
        let base = Font.system(size: 11.5, design: .rounded)

        return text.components(separatedBy: "*")
            .enumerated()
            .reduce(into: AttributedString()) { result, part in
                var run = AttributedString(part.element)
                run.font = part.offset.isMultiple(of: 2) ? base : base.italic()
                result += run
            }
    }

    // MARK: Loop

    private func start() {
        guard loop == nil else { return }

        guard !reduceMotion else {
            beat = .advice
            revealedBriefing = Self.briefing.count
            revealedAdvice = Self.advice.count
            revealedAvoid = Self.avoid.count
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
        try? await Task.sleep(for: .milliseconds(280))
        guard !Task.isCancelled else { return }

        for count in 1...Self.briefing.count {
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.3)) { revealedBriefing = count }
            try? await Task.sleep(for: .milliseconds(300))
        }

        try? await Task.sleep(for: .milliseconds(2100))
        guard !Task.isCancelled else { return }

        await swapContent(to: .advice)

        for count in 1...Self.advice.count {
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { revealedAdvice = count }
            try? await Task.sleep(for: .milliseconds(340))
        }

        try? await Task.sleep(for: .milliseconds(1900))
        guard !Task.isCancelled else { return }

        await swapContent(to: .avoid)

        for count in 1...Self.avoid.count {
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { revealedAvoid = count }
            try? await Task.sleep(for: .milliseconds(340))
        }

        try? await Task.sleep(for: .milliseconds(1900))
        guard !Task.isCancelled else { return }
    }

    private func swapContent(to next: Beat) async {
        withAnimation(.easeOut(duration: 0.22)) { contentIn = 0 }
        try? await Task.sleep(for: .milliseconds(240))
        guard !Task.isCancelled else { return }

        beat = next
        withAnimation(.easeIn(duration: 0.26)) { contentIn = 1 }
        try? await Task.sleep(for: .milliseconds(180))
    }

    private func reset() {
        beat = .briefing
        contentIn = 1
        revealedBriefing = 0
        revealedAdvice = 0
        revealedAvoid = 0
    }
}

#if DEBUG
#Preview("Trip advice demo") {
    ZStack {
        DriftingAurora(bloom: 1) { _ in Color.clear }
        TripAdviceDemoView(isActive: true)
    }
}
#endif
