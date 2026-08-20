//
//  WelcomeScreen.swift
//  Wanderlust
//
//  The first-launch flow: four pages over one continuous backdrop.
//
//  The aurora is `DriftingAurora` at the same density the splash ends on, so
//  the hand-off is a cross-fade with nothing visibly cutting — the launch
//  animation resolves into this screen rather than being replaced by it. It
//  sits outside the pager, which is the whole trick: the backdrop holds still
//  while the content slides over it, so four pages read as one place.
//
//  Page selection is bound rather than free-running because each page's demo
//  is a loop; they run only while their page is on screen, which keeps the
//  page-3 and page-4 loops from burning cycles behind a page nobody is
//  looking at.
//
//  The shape is: a promise, then three steps, each with one job — set up the
//  trip and swipe, see the advice, then see what hearting it does. Splitting
//  favouriting out from the advice page (rather than tucking it in as that
//  page's last beat) gives it room to actually be shown happening: three
//  suggestions get hearted in view, then become the same rows, restyled, in a
//  favourites list — cause and consequence on one surface.
//

import CoreArchitecture
import DesignSystem
import SwiftUI

struct WelcomeScreen: View {
    var onFinish: () -> Void = {}

    private enum Page: Int, CaseIterable, Identifiable {
        case promise
        case setup
        case advice
        case favourites

        var id: Int { rawValue }
        var isLast: Bool { self == .favourites }
        var buttonTitle: String {
            isLast ? "Start exploring" : "Continue"
        }

        /// Analytics entry point, so the drop-off across the flow is
        /// measurable — see ANALYTICS.md.
        var analyticsID: String {
            switch self {
            case .promise:    "page_promise"
            case .setup:      "page_setup"
            case .advice:     "page_advice"
            case .favourites: "page_favourites"
            }
        }
    }

    @State private var page: Page = .promise

    var body: some View {
        ZStack {
            DriftingAurora(bloom: 1) { _ in Color.clear }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Page.allCases) { candidate in
                        pageContent(candidate).tag(candidate)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                footer
            }
        }
        // A floating overlay rather than a reserved row or a toolbar item.
        // A dedicated row pushed the whole page down by its own height, which
        // fought the promise page's logo for the top of the screen. A toolbar
        // item depends on a `NavigationStack` ancestor to have anywhere to
        // render — this screen is presented as a bare full-screen layer with
        // none, so a toolbar item here would silently not appear. An overlay
        // has neither problem: it costs no layout space, and it renders
        // wherever the view is hosted.
        .overlay(alignment: .topTrailing) {
            Button("Skip") {
                AnalyticsTracker.shared.log(
                    .init(.onboardingSkipped, properties: [
                        "flow": .string("welcome"),
                        "page": .string(page.analyticsID)
                    ])
                )
                onFinish()
            }
                .font(.kanit(14))
                .foregroundStyle(.secondary)
                .opacity(page.isLast ? 0 : 1)
                .disabled(page.isLast)
                .padding(.top, 12)
                .padding(.trailing, 20)
                .animation(.easeInOut(duration: 0.2), value: page.isLast)
                .accessibilityHint("Skips the introduction")
        }
        .onChange(of: page, initial: true) { _, current in
            AnalyticsTracker.shared.log(
                .screenViewed(.welcome, entryPoint: current.analyticsID)
            )
        }
    }

    // MARK: Chrome

    private var footer: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(Page.allCases) { candidate in
                    Circle()
                        .fill(candidate == page ? Color.appTint : Color.black.opacity(0.16))
                        .frame(width: 6, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .accessibilityHidden(true)

            Button(page.buttonTitle) {
                if page.isLast {
                    AnalyticsTracker.shared.log(
                        .init(.onboardingCompleted, properties: [
                            "flow": .string("welcome"),
                            "page": .string(page.analyticsID)
                        ])
                    )
                    onFinish()
                } else if let next = Page(rawValue: page.rawValue + 1) {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    withAnimation(.easeInOut(duration: 0.3)) { page = next }
                }
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .animation(nil, value: page)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 24)
    }

    // MARK: Pages

    @ViewBuilder
    private func pageContent(_ candidate: Page) -> some View {
        let isActive = candidate == page

        switch candidate {
        case .promise:
            // `GeometryReader` isn't decoration here — it's what keeps the
            // 480pt rings from working. A `ZStack` sizes itself to its widest
            // child by default, so without pinning both layers to the page's
            // real width, the rings inflate the whole page's layout width and
            // the sentence below rewraps against that inflated width instead
            // of the screen's, running off both edges. Pinning the ZStack and
            // the text `VStack` to `proxy.size.width` lets the rings render
            // past the bounds — `ZStack` doesn't clip — without either of them
            // seeing anything but the true page width.
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    bearingRings

                    VStack(spacing: 0) {
                        // Clearance above the lockup so it doesn't sit flush
                        // against the very top of the page.
                        Spacer()
                            .frame(height: 64)
                        brandMark
                        // A fixed, generous gap — two line-heights on top of
                        // the base spacing — so the lockup and the sentence
                        // read as two distinct blocks, not a header crowding
                        // the words underneath it.
                        Spacer()
                            .frame(height: 108 + 38 * 2)
                        WelcomeSloganView(isActive: isActive)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 28)
                    .frame(width: proxy.size.width)
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }

        case .setup:
            explainer(
                eyebrow: "STEP 1",
                title: "A few basics, then swipe",
                body: "Where, how long, and roughly when. Then swipe through a handful of choices — that's how we learn your style."
            ) {
                TripSetupDemoView(isActive: isActive)
            }

        case .advice:
            explainer(
                eyebrow: "STEP 2",
                title: "Local travel advice tailored to you",
                body: "What's worth knowing before you land, what locals actually recommend, and what to skip."
            ) {
                TripAdviceDemoView(isActive: isActive)
            }

        case .favourites:
            explainer(
                eyebrow: "STEP 3",
                title: "Heart it to keep it",
                body: "Tap the heart on anything that stands out and it's added to your favourites — your own curated list for the trip."
            ) {
                FavouritesCollectDemoView(isActive: isActive)
            }
        }
    }

    private func explainer(
        eyebrow: String,
        title: String,
        body: String,
        @ViewBuilder demo: () -> some View
    ) -> some View {
        VStack(spacing: 26) {
            Spacer(minLength: 0)

            demo()

            VStack(alignment: .leading, spacing: 9) {
                Text(eyebrow)
                    .font(.kanit(11).weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color.appTint)

                Text(title)
                    .font(.kanitLight(27))
                    .foregroundStyle(Color(hex: "#2A2F45"))
                    .fixedSize(horizontal: false, vertical: true)

                Text(body)
                    .font(.kanit(15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }

    // MARK: Brand lockup

    /// The compass lockup from `HomeScreen.brand` — the app's own signature,
    /// reused rather than reinvented on the screen that introduces it. The
    /// sentence below it and its animation are untouched by this; it's purely
    /// a header. No rings inside this view — see `bearingRings`, which draws
    /// them as the page's own backdrop rather than as this view's background,
    /// so they can be sized and positioned exactly the way `HomeBackground`
    /// sizes and positions them: bleeding off the top and sides, not sitting
    /// inside a tidy little badge behind the mark.
    private var brandMark: some View {
        VStack(spacing: 8) {
            PinPlaneMark(size: 32)

            Text("wanderlust")
                .font(.kanitLight(20))
                .tracking(6)
                .padding(.leading, 6)
                .foregroundStyle(Color(hex: "#2A2F45").opacity(0.9))

            Text("Get inspired for your next travel")
                .font(.kanitLightItalic(10))
                .foregroundStyle(.secondary)
        }
    }

    /// `HomeBackground`'s exact ring geometry — five rings, 96pt apart in
    /// diameter starting at 96, fading by the same 0.021 step per ring. The
    /// largest is 480pt: wider than the page, which is the point. Centred
    /// close to the top edge (`yOffset`) rather than on the mark, its top
    /// three quarters run off-screen and only the bottom arcs show — the
    /// "background bleeding past the edges" look Home has, not a
    /// fully-visible circle sitting neatly behind the logo.
    private var bearingRings: some View {
        let yOffset: CGFloat = 34
        let largest: CGFloat = 480

        return ZStack {
            ForEach(0..<5, id: \.self) { ring in
                Circle()
                    .stroke(Color.appTint.opacity(0.17 - Double(ring) * 0.021), lineWidth: 0.9)
                    .frame(width: 96 + CGFloat(ring) * 96, height: 96 + CGFloat(ring) * 96)
            }
        }
        .frame(height: largest)
        .offset(y: yOffset - largest / 2)
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Welcome") {
    WelcomeScreen()
}
#endif
