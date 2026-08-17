//
//  FavouritesCollectDemoView.swift
//  Wanderlust
//
//  Step 3 of `WelcomeScreen`: concrete suggestions get hearted, then burst
//  into a favourites list styled like the real one.
//
//  Two things changed from the first pass at this page. First, the
//  suggestions themselves: three sentences of advice all looked and read the
//  same, so hearting one felt arbitrary. These are named places with one
//  concrete, practical line each — an icon-badge row, the same visual grammar
//  `TripAdviceDemoView`'s briefing already uses — so each card has its own
//  identity and a reason to be the one you'd tap.
//
//  Second, the collect moment. Relabelling the same row in place read as one
//  card with new text, not as "this became your favourites list" — because
//  nothing about the destination looked different from the place a suggestion
//  came from. So the collect beat now does three things together: a heart
//  bursts once at the centre of the card, the suggestion rows are replaced by
//  rows styled like the real `FavoriteCard` (plain flowing text, a circular
//  heart button on the trailing edge, `regularMaterial`) under the same
//  "FROM YOUR SUGGESTIONS" label `FavouritesListView` uses, and the hero warms
//  and retitles at the same moment. Different shape, different surface,
//  same trip.
//

import CoreArchitecture
import DesignSystem
import Networking
import SwiftUI

struct FavouritesCollectDemoView: View {
    var isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Suggestion {
        let icon: String
        let title: String
        let detail: String
        /// What the collected favourites row shows — title and detail folded
        /// into one flowing line, the way `FavoriteCard` renders a single
        /// `Text` rather than a title/subtitle pair.
        var collected: String { "\(title) — \(detail)" }
    }

    /// Occasions, not logistics — "board at Graça" is a tip; "sunset drinks"
    /// is a plan. The suggestions page is the one place in the flow that's
    /// meant to sound like the trip itself, not like prep for it.
    private static let suggestions: [Suggestion] = [
        Suggestion(icon: "sunset.fill", title: "Sunset drinks at Park Bar", detail: "a rooftop over a car park — book ahead, packed by 7"),
        Suggestion(icon: "fork.knife", title: "Lunch at Taberna da Rua das Flores", detail: "family-run tasca, no reservations, arrive by noon"),
        Suggestion(icon: "beach.umbrella.fill", title: "Beach day at Costa da Caparica", detail: "20 minutes by ferry, better waves than Cascais")
    ]

    @State private var revealedCount = 0
    @State private var heartedFlags = [false, false, false]
    @State private var isCollected = false
    /// Driven by two sequential `withAnimation` calls (up, then down) rather
    /// than one continuous 0→1 ramp — see `runOnce()`. A single ramp with a
    /// derived "rises then falls" opacity formula never rendered: SwiftUI's
    /// `withAnimation` interpolates the *rendered modifier value* between its
    /// value at the old state and its value at the new state, not by
    /// resampling the body continuously. A formula that evaluates to 0 at
    /// both `burst == 0` and `burst == 1` therefore interpolates 0 → 0 — the
    /// peak in the middle never gets sampled. Two real snapshots (0 → 0.95,
    /// then 0.95 → 0) each interpolate correctly because the state itself
    /// passes through the peak.
    @State private var burstOpacity: Double = 0
    @State private var burstScale: CGFloat = 0.5
    @State private var favouriteWash: Double = 0
    @State private var loop: Task<Void, Never>?
    @State private var heroImageURL: AsyncValue<URL> = .initial

    private let imageService = UnsplashService()
    private static let heroQuery = "Lisbon yellow tram 28"

    private let heartRed = Color(hex: "#EE6262")
    private let heroHeight: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            hero
            content
        }
        .frame(maxWidth: 300)
        .frame(height: 314, alignment: .top)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 18, y: 8)
        .accessibilityElement()
        .accessibilityLabel("Three Lisbon suggestions get hearted and become a saved favourites list")
        .onChange(of: isActive, initial: true) { _, active in
            active ? start() : stop()
        }
        .onDisappear(perform: stop)
        .task { await loadHeroImageIfNeeded() }
    }

    // MARK: Hero

    private var hero: some View {
        CacheDestinationImage(cacheKey: "welcome.favouritesCollectDemo", imageUrlState: heroImageURL)
            .frame(width: 300, height: heroHeight)
            .clipped()
            .overlay {
                LinearGradient(colors: [.black.opacity(0.14), .black.opacity(0.64)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay {
                LinearGradient(
                    colors: [heartRed.opacity(0.46 * favouriteWash), heartRed.opacity(0.04 * favouriteWash)],
                    startPoint: .bottomLeading,
                    endPoint: .topTrailing
                )
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
            Text(isCollected ? "Your Favourites in Lisbon" : "Lisbon")
                .font(.kanitMedium(17))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 1)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(spacing: 5) {
                Image(systemName: isCollected ? "heart.fill" : "calendar")
                    .font(.system(size: 9, weight: .bold))
                Text(isCollected ? "3 saved" : "5 days in June")
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
        ZStack {
            VStack(alignment: .leading, spacing: 8) {
                header

                if isCollected {
                    collectedList
                } else {
                    suggestionList
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 13)
            .padding(.top, 11)

            burstHeart
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: isCollected ? "heart.fill" : "sparkles")
                .font(.system(size: 10, weight: .semibold))

            Text(isCollected ? "FROM YOUR SUGGESTIONS" : "Suggestions for you")
                .font(isCollected
                      ? .system(size: 10, weight: .heavy, design: .rounded)
                      : .kanitMedium(12))
                .kerning(isCollected ? 0.9 : 0)
        }
        .foregroundStyle(isCollected ? Color.appTint : Color.appTint)
        .id(isCollected)
        .transition(.opacity)
    }

    /// The "before" state: an icon-badge row per place, matching
    /// `TripAdviceDemoView`'s briefing — dense enough to read as a real
    /// suggestions feed rather than a stack of sentences.
    private var suggestionList: some View {
        VStack(spacing: 6) {
            ForEach(Array(Self.suggestions.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.appTint)
                        .frame(width: 22, height: 22)
                        .background(Color.appTint.opacity(0.13), in: Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.primary)
                        Text(item.detail)
                            .font(.system(size: 10.5, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: heartedFlags[index] ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundStyle(heartedFlags[index] ? Color.red : Color(.systemGray3))
                        .symbolEffect(.bounce, value: heartedFlags[index])
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.white.opacity(0.62), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.black.opacity(0.05), lineWidth: 1)
                }
                .opacity(index < revealedCount ? 1 : 0)
                .offset(y: index < revealedCount ? 0 : 8)
            }
        }
        .transition(.asymmetric(
            insertion: .opacity,
            removal: .opacity.combined(with: .scale(scale: 0.97))
        ))
    }

    /// The "after" state: mirrors `FavoriteCard` almost exactly — one flowing
    /// line of text, a circular heart button on the trailing edge, plain
    /// `regularMaterial`. Deliberately a different row shape from the
    /// suggestion list above it, not the same card with new words in it.
    private var collectedList: some View {
        VStack(spacing: 7) {
            ForEach(Array(Self.suggestions.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item.collected)
                        .font(.system(size: 11.5, design: .rounded))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "heart.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.red)
                        .frame(width: 22, height: 22)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.black.opacity(0.05), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
    }

    /// One heart, scaling up and out from the centre of the card and gone
    /// before it can be mistaken for a persistent element. This is the "more
    /// exciting" beat — the moment three separate taps become one list.
    private var burstHeart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 46, weight: .bold))
            .foregroundStyle(heartRed)
            .scaleEffect(burstScale)
            .opacity(burstOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: Loop

    private func start() {
        guard loop == nil else { return }

        guard !reduceMotion else {
            revealedCount = Self.suggestions.count
            heartedFlags = [true, true, true]
            isCollected = true
            favouriteWash = 1
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
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        for count in 1...Self.suggestions.count {
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { revealedCount = count }
            try? await Task.sleep(for: .milliseconds(260))
        }

        try? await Task.sleep(for: .milliseconds(650))
        guard !Task.isCancelled else { return }

        for index in heartedFlags.indices {
            guard !Task.isCancelled else { return }
            heartedFlags[index] = true
            try? await Task.sleep(for: .milliseconds(440))
        }

        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }

        // The burst pops on its own first — a beat where it's the only thing
        // moving, so it actually reads before anything else changes — then
        // the row swap, header relabel and hero warm land together as it
        // starts to fade.
        withAnimation(.spring(response: 0.22, dampingFraction: 0.55)) {
            burstOpacity = 0.95
            burstScale = 1.55
        }
        try? await Task.sleep(for: .milliseconds(200))
        guard !Task.isCancelled else { return }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            isCollected = true
            favouriteWash = 1
        }
        withAnimation(.easeIn(duration: 0.4)) {
            burstOpacity = 0
            burstScale = 1.9
        }

        try? await Task.sleep(for: .milliseconds(2400))
        guard !Task.isCancelled else { return }

        withAnimation(.easeInOut(duration: 0.4)) { favouriteWash = 0 }
        try? await Task.sleep(for: .milliseconds(450))
    }

    private func reset() {
        revealedCount = 0
        heartedFlags = [false, false, false]
        isCollected = false
        burstOpacity = 0
        burstScale = 0.5
        favouriteWash = 0
    }
}

#if DEBUG
#Preview("Favourites collect demo") {
    ZStack {
        DriftingAurora(bloom: 1) { _ in Color.clear }
        FavouritesCollectDemoView(isActive: true)
    }
}
#endif
