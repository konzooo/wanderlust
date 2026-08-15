//
//  HomeLogoLab.swift
//  Wanderlust
//
//  One playground entry for the Home screen's top block. Everything from the
//  brand down to the suggestion chips is real-looking but inert; the bottom
//  third is a switcher so the concepts can be compared in place, on the real
//  vertical rhythm, in a second.
//
//  Round two. Six of the first ten were ruled out; the survivors are here
//  revised, and the new concepts answer the note that the winner is probably
//  not a logo placed on the Home screen but a Home screen *designed around* the
//  brand — so several of them ship their own backdrop instead of the shared
//  Aurora, with the mark drawn as part of the artwork.
//
//  Delete this file once a direction is chosen and folded into HomeScreen.
//

#if DEBUG

import CoreText
import DesignSystem
import SwiftUI

// MARK: - Palette

private enum Brand {
    static let ink = Color(hex: "#2A2F45")
    static let tint = Color.appTint
    static let violet = Color(hex: "#8B6BF6")
    static let sand = Color(hex: "#F3D9A4")

    static var sweep: LinearGradient {
        LinearGradient(colors: [tint, violet], startPoint: .leading, endPoint: .trailing)
    }

    static var badge: LinearGradient {
        LinearGradient(colors: [tint, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Concepts

enum HomeLogoConcept: String, CaseIterable, Identifiable {
    // Survivors from round one.
    case quietContour
    case appChromeRow
    case brandAsHeadline
    case iconWordmarkTagline
    // Designed-backdrop concepts: the brand and the background are one artwork.
    case horizonBand
    case contourMap
    case flightArc
    case postcardPanel
    // Full rethinks of the mark itself. The four compass-layout entries are
    // deliberately identical apart from the mark, so the marks can be judged
    // against each other rather than against four different layouts.
    case compassRose
    case compassPin
    case compassOrbit
    case compassWaypoint
    case routeMonogram

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .quietContour: "Quiet"
        case .appChromeRow: "Chrome"
        case .brandAsHeadline: "Headline"
        case .iconWordmarkTagline: "Lockup"
        case .horizonBand: "Horizon"
        case .contourMap: "Topo"
        case .flightArc: "Flight"
        case .postcardPanel: "Panel"
        case .compassRose: "Compass"
        case .compassPin: "Compass · Pin"
        case .compassOrbit: "Compass · Orbit"
        case .compassWaypoint: "Compass · Waypoint"
        case .routeMonogram: "Route"
        }
    }

    var title: String {
        switch self {
        case .quietContour: "1 — Quiet contour"
        case .appChromeRow: "2 — App chrome row"
        case .brandAsHeadline: "3 — Brand is the headline"
        case .iconWordmarkTagline: "4 — Icon lockup"
        case .horizonBand: "5 — Horizon"
        case .contourMap: "6 — Topographic"
        case .flightArc: "7 — Flight arc"
        case .postcardPanel: "8 — Postcard panel"
        case .compassRose: "9 — Compass rose"
        case .compassPin: "9a — Same, with the Wanderlust pin"
        case .compassOrbit: "9b — Same, with the Orbit mark"
        case .compassWaypoint: "9c — Same, with the Waypoint mark"
        case .routeMonogram: "10 — Route monogram"
        }
    }

    var rationale: String {
        switch self {
        case .quietContour:
            "Your contour, quieted: sparkles gone, stroke faded, width pulled in. Present as a mark, not as a banner."
        case .appChromeRow:
            "Signature left, account right. The top reads as an app bar you can act on."
        case .brandAsHeadline:
            "One display line instead of two competing ones. The sparkle is gone; the name carries it."
        case .iconWordmarkTagline:
            "A properly drawn mark, the name in confident caps, the grey tagline beneath. No yellow anywhere."
        case .horizonBand:
            "The backdrop becomes a sunrise; the name sits on the horizon line with the sun rising through it."
        case .contourMap:
            "Topographic lines rise into the header and the mark sits on the summit. The background is the brand."
        case .flightArc:
            "The dashed flight path graduates from decoration to structure: it launches from the mark and carries the eye to the question."
        case .postcardPanel:
            "The header is a surface, not floating elements — a tinted panel fading into the page, brand inside it."
        case .compassRose:
            "New mark: a drawn compass rose, name in wide lowercase. Minimal, modern, nothing travel-cliché left."
        case .compassPin:
            "The same layout carrying today's pin. The honest control: does the existing mark hold up once the setting is right?"
        case .compassOrbit:
            "New mark: a world and the path around it, broken where the traveller is. Reads as a brand first and travel second."
        case .compassWaypoint:
            "New mark: a star whose south point lands on a place. Inspiration that arrives somewhere — the promise, in one shape."
        case .routeMonogram:
            "New mark: the W drawn as a route, dot at the destination, the same line continuing across the screen."
        }
    }

    /// Concepts whose backdrop is part of the design rather than the shared
    /// Aurora that every other screen uses.
    var hasBespokeBackdrop: Bool {
        switch self {
        case .horizonBand, .contourMap, .flightArc, .postcardPanel,
             .compassRose, .compassPin, .compassOrbit, .compassWaypoint, .routeMonogram:
            true
        case .quietContour, .appChromeRow, .brandAsHeadline, .iconWordmarkTagline:
            false
        }
    }
}

// MARK: - Lab shell

struct HomeLogoLab: View {
    @State private var concept: HomeLogoConcept = .iconWordmarkTagline
    @State private var query = ""

    private let suggestions = ["Lisbon", "Tokyo", "Norway road trip"]

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider().opacity(0.35)
            switcher
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    /// Mirrors HomeScreen's real rhythm: brand at the top, one flexible gap,
    /// then prompt / field / chips travelling together as one block.
    private var preview: some View {
        VStack(spacing: 0) {
            HomeLogoBrand(concept: concept)

            Spacer(minLength: 24)

            VStack(alignment: .leading, spacing: 16) {
                HomeLogoPrompt(concept: concept)
                askField
                chips
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background { HomeLogoBackdrop(concept: concept) }
    }

    private var askField: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Brand.tint)

            ZStack(alignment: .leading) {
                if query.isEmpty {
                    Text("Barcelona, a road trip,\nanywhere…")
                        .font(.kanit(17))
                        .foregroundStyle(Color.secondary.opacity(0.72))
                        .allowsHitTesting(false)
                }
                TextField("", text: $query, axis: .vertical)
                    .font(.kanit(17))
                    .lineLimit(1...2)
            }

            Image(systemName: "arrow.right")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Brand.tint)
                .frame(width: 34, height: 44)
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .frame(minHeight: 88)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.72), lineWidth: 1) }
        .shadow(color: Brand.tint.opacity(0.08), radius: 20, y: 10)
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Text(suggestion)
                    .font(.kanit(13).weight(.medium))
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.58), in: Capsule())
                    .overlay { Capsule().stroke(Color.black.opacity(0.055), lineWidth: 1) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var switcher: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(HomeLogoConcept.allCases) { option in
                        Button {
                            withAnimation(.snappy(duration: 0.22)) { concept = option }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        } label: {
                            Text(option.chipLabel)
                                .font(.kanit(13).weight(.medium))
                                .foregroundStyle(option == concept ? .white : Color.primary.opacity(0.7))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    option == concept ? AnyShapeStyle(Brand.tint)
                                                      : AnyShapeStyle(.white.opacity(0.6)),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(concept.title)
                        .font(.kanit(14).weight(.semibold))
                    if concept.hasBespokeBackdrop {
                        Text("OWN BACKDROP")
                            .font(.kanit(9).weight(.semibold))
                            .tracking(0.8)
                            .foregroundStyle(Brand.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Brand.tint.opacity(0.12), in: Capsule())
                    }
                }
                Text(concept.rationale)
                    .font(.kanit(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 54, alignment: .topLeading)
            .padding(.horizontal, 20)
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.regularMaterial)
    }
}

// MARK: - Backdrops
//
// Six concepts replace the shared Aurora entirely. Each is drawn, not a bitmap,
// so it stays crisp, animates and can be recoloured — and so the mark can be
// positioned against real geometry rather than against a picture.

private struct HomeLogoBackdrop: View {
    let concept: HomeLogoConcept

    var body: some View {
        switch concept {
        case .quietContour, .appChromeRow, .brandAsHeadline, .iconWordmarkTagline:
            AuroraBackground()

        case .horizonBand:
            HorizonBackdrop()

        case .contourMap:
            TopographicBackdrop()

        case .flightArc:
            FlightArcBackdrop()

        case .postcardPanel:
            PostcardPanelBackdrop()

        case .compassRose, .compassPin, .compassWaypoint:
            RingsBackdrop(tilted: false)

        case .compassOrbit:
            // Tilted rings, so the dial echoes the orbit's own perspective.
            RingsBackdrop(tilted: true)

        case .routeMonogram:
            RouteBackdrop()
        }
    }
}

/// Sunrise: a warm band low in the sky, a sun disc that the wordmark crosses,
/// and a hairline horizon the whole lockup stands on.
private struct HorizonBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            let horizon: CGFloat = 148

            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color(hex: "#DCE3FF"),
                        Color(hex: "#EFF1FE"),
                        Color(hex: "#FDF6EC"),
                        Color(hex: "#FFFCF6")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Haze just under the horizon, which the lockup draws over.
                Ellipse()
                    .fill(Brand.sand.opacity(0.22))
                    .frame(width: proxy.size.width * 1.3, height: 150)
                    .blur(radius: 45)
                    .position(x: proxy.size.width / 2, y: horizon)
            }
            .ignoresSafeArea()
        }
    }
}

/// Contour lines climbing to a summit under the mark: a map, abstracted far
/// enough that it reads as pattern rather than as an actual place.
private struct TopographicBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#EDF0FE"), Color(hex: "#FBFAF7"), Color(hex: "#FFF9F0")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                ZStack {
                    ForEach(0..<9, id: \.self) { ring in
                        ContourRing(step: CGFloat(ring))
                            .stroke(
                                Brand.tint.opacity(0.20 - Double(ring) * 0.017),
                                lineWidth: ring == 3 ? 1.2 : 0.8
                            )
                    }
                }
                .frame(width: proxy.size.width, height: 260)
                .offset(y: -46)
            }
        }
        .ignoresSafeArea()
    }
}

/// One closed contour of the topographic set. Each step inflates the same
/// hand-shaped curve, so the rings nest the way real contours do instead of
/// looking like concentric circles.
private struct ContourRing: Shape {
    let step: CGFloat

    func path(in rect: CGRect) -> Path {
        let inflate = 1 + step * 0.34
        let w = rect.width * 0.20 * inflate
        let h = rect.height * 0.17 * inflate
        let c = CGPoint(x: rect.midX, y: rect.midY + step * 9)

        var path = Path()
        path.move(to: CGPoint(x: c.x - w, y: c.y))
        path.addCurve(
            to: CGPoint(x: c.x, y: c.y - h),
            control1: CGPoint(x: c.x - w * 0.9, y: c.y - h * 0.75),
            control2: CGPoint(x: c.x - w * 0.42, y: c.y - h)
        )
        path.addCurve(
            to: CGPoint(x: c.x + w, y: c.y),
            control1: CGPoint(x: c.x + w * 0.52, y: c.y - h),
            control2: CGPoint(x: c.x + w * 0.96, y: c.y - h * 0.56)
        )
        path.addCurve(
            to: CGPoint(x: c.x, y: c.y + h * 0.82),
            control1: CGPoint(x: c.x + w * 0.94, y: c.y + h * 0.6),
            control2: CGPoint(x: c.x + w * 0.4, y: c.y + h * 0.82)
        )
        path.addCurve(
            to: CGPoint(x: c.x - w, y: c.y),
            control1: CGPoint(x: c.x - w * 0.46, y: c.y + h * 0.82),
            control2: CGPoint(x: c.x - w * 0.98, y: c.y + h * 0.58)
        )
        path.closeSubpath()
        return path
    }
}

/// The dashed flight path, promoted from background decoration to the thing
/// that holds the header together: it launches at the mark and lands on the
/// question.
private struct FlightArcBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E3E9FF"), Color(hex: "#F7F8FF"), Color(hex: "#FFF7EC")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Brand.violet.opacity(0.20))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 130, y: -210)

            GeometryReader { proxy in
                let arc = LaunchArc()
                ZStack {
                    arc.stroke(
                        Brand.tint.opacity(0.34),
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round, dash: [1, 7])
                    )

                    PlaneShape()
                        .fill(Brand.tint)
                        .frame(width: 15, height: 15)
                        .rotationEffect(.degrees(64))
                        .position(arc.tip(in: CGRect(origin: .zero, size: proxy.size)))
                }
                .frame(height: 230)
            }
        }
        .ignoresSafeArea()
    }
}

private struct LaunchArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Starts below the lockup and climbs to the right, so it never crosses
        // the wordmark or reaches up into the status bar.
        path.move(to: CGPoint(x: 26, y: 196))
        path.addCurve(
            to: tip(in: rect),
            control1: CGPoint(x: rect.width * 0.36, y: 188),
            control2: CGPoint(x: rect.width * 0.62, y: 140)
        )
        return path
    }

    func tip(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.width - 52, y: 108)
    }
}

/// The header as a surface: a tinted panel bleeding to the edges and fading
/// out before the input field, so nothing floats on a bare gradient.
private struct PostcardPanelBackdrop: View {
    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: "#F7F8FC"), Color(hex: "#FFFDF9")],
                startPoint: .top,
                endPoint: .bottom
            )

            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#5C6BF0"), Color(hex: "#8B6BF6"), Color(hex: "#B49BFA")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Brand.sand.opacity(0.42))
                    .frame(width: 220, height: 220)
                    .blur(radius: 60)
                    .offset(x: 120, y: -60)
            }
            .frame(height: 300)
            // Fades out rather than ending on a line, so the panel's depth does
            // not depend on where the flexible spacer happens to put the prompt.
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.62),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .offset(y: -70)
        }
        .ignoresSafeArea()
    }
}

/// Faint concentric rings centred on the compass mark — a bearing dial the
/// wordmark sits inside.
private struct RingsBackdrop: View {
    var tilted = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#E9EDFF"), Color(hex: "#FAFAFF"), Color(hex: "#FFF8EF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                ZStack {
                    ForEach(1..<6, id: \.self) { ring in
                        Ellipse()
                            .stroke(Brand.tint.opacity(0.16 - Double(ring) * 0.02), lineWidth: 0.9)
                            .frame(
                                width: CGFloat(ring) * 96,
                                height: CGFloat(ring) * (tilted ? 54 : 96)
                            )
                    }
                }
                .rotationEffect(.degrees(tilted ? -22 : 0))
                .position(x: proxy.size.width / 2, y: 60)
            }
        }
        .ignoresSafeArea()
    }
}

/// The monogram's own stroke, continued across the screen as a travelled route
/// with waypoints — the mark and the background are literally the same line.
private struct RouteBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#EBEEFE"), Color(hex: "#FBFBFE"), Color(hex: "#FFF9F1")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack {
                    ContinuedRoute()
                        .stroke(
                            Brand.tint.opacity(0.22),
                            style: StrokeStyle(lineWidth: 1.3, lineCap: .round, dash: [1, 8])
                        )

                    Circle()
                        .fill(Brand.tint.opacity(0.35))
                        .frame(width: 5, height: 5)
                        .position(x: width * 0.62, y: 96)

                    Circle()
                        .fill(Brand.tint.opacity(0.25))
                        .frame(width: 4, height: 4)
                        .position(x: width * 0.88, y: 150)
                }
                .frame(height: 220)
            }
        }
        .ignoresSafeArea()
    }
}

private struct ContinuedRoute: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.30, y: 74))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.62, y: 96),
            control1: CGPoint(x: rect.width * 0.42, y: 82),
            control2: CGPoint(x: rect.width * 0.5, y: 104)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.88, y: 150),
            control1: CGPoint(x: rect.width * 0.76, y: 88),
            control2: CGPoint(x: rect.width * 0.9, y: 116)
        )
        return path
    }
}

// MARK: - Brand blocks

private struct HomeLogoBrand: View {
    let concept: HomeLogoConcept

    var body: some View {
        switch concept {
        // 1 — the contour, quieted: no sparkles, faded stroke, pulled in.
        case .quietContour:
            VStack(spacing: 7) {
                WordmarkShape(text: "WANDERLUST", tracking: 6)
                    .stroke(
                        Brand.tint.opacity(0.55),
                        style: StrokeStyle(lineWidth: 0.9, lineJoin: .round)
                    )
                    .frame(height: 19)

                Text("Get inspired for your next travel")
                    .font(.kanitLightItalic(10))
                    .foregroundStyle(.secondary.opacity(0.8))
            }
            .frame(minHeight: 52)

        // 2 — unchanged: signature left, account right.
        case .appChromeRow:
            HStack(spacing: 9) {
                PinPlaneMark(size: 16)
                Text("WANDERLUST")
                    .font(.kanit(13).weight(.semibold))
                    .tracking(3.4)
                    .foregroundStyle(Brand.tint)

                Spacer()

                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Brand.tint)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.66), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.8), lineWidth: 1) }
            }
            .frame(minHeight: 44)

        // 3 — the name is the display line, so nothing sits above it.
        case .brandAsHeadline:
            Color.clear.frame(height: 8)

        // 4 — drawn mark, name in caps, grey tagline. No yellow.
        case .iconWordmarkTagline:
            HStack(spacing: 13) {
                WanderlustMark(size: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text("WANDERLUST")
                        .font(.kanit(25).weight(.semibold))
                        .tracking(2.6)
                        .foregroundStyle(Brand.sweep)
                    Text("Get inspired for your next travel")
                        .font(.kanit(11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)

        // 5 — the name standing on the drawn horizon, sun rising through it.
        //
        // The sun and the horizon live here rather than in the backdrop: drawn
        // behind the lockup they share its coordinate space, so the line lands
        // on the baseline on every device instead of wherever the safe area
        // happens to put it.
        case .horizonBand:
            VStack(spacing: 0) {
                Text("WANDERLUST")
                    .font(.kanit(19).weight(.medium))
                    .tracking(6.4)
                    .padding(.leading, 6.4)
                    .foregroundStyle(Brand.ink)
                    .padding(.bottom, 9)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .bottom)
                    // Sun and horizon are drawn as background and overlay, not
                    // as stack children: a 150pt sun would otherwise set the
                    // block's height and drag the horizon down onto the tagline.
                    .background(alignment: .bottom) {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Brand.sand.opacity(0.9), Brand.sand.opacity(0.06)],
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 78
                                )
                            )
                            .frame(width: 150, height: 150)
                            .offset(y: 46)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Brand.tint.opacity(0.42), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, -20)
                    }

                Text("Get inspired for your next travel")
                    .font(.kanitLightItalic(10))
                    .foregroundStyle(Brand.ink.opacity(0.55))
                    .padding(.top, 11)
            }

        // 6 — the mark on the summit of the contour lines.
        case .contourMap:
            VStack(spacing: 9) {
                WanderlustMark(size: 34)
                Text("WANDERLUST")
                    .font(.kanit(14).weight(.semibold))
                    .tracking(4.2)
                    .padding(.leading, 4.2)
                    .foregroundStyle(Brand.ink.opacity(0.86))
            }
            .frame(minHeight: 92)

        // 7 — the mark is the launch point of the arc.
        case .flightArc:
            HStack(spacing: 10) {
                WanderlustMark(size: 32)
                Text("WANDERLUST")
                    .font(.kanit(14).weight(.semibold))
                    .tracking(3.4)
                    .foregroundStyle(Brand.tint)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

        // 8 — inside the panel, so it can be white and still legible.
        case .postcardPanel:
            HStack(spacing: 13) {
                WanderlustMark(size: 42, onDark: true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("WANDERLUST")
                        .font(.kanit(20).weight(.semibold))
                        .tracking(4.6)
                        .foregroundStyle(.white)
                    Text("Get inspired for your next travel")
                        .font(.kanitLightItalic(11))
                        .foregroundStyle(.white.opacity(0.82))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)

        // 9 — new mark: a drawn compass rose, name in wide lowercase.
        case .compassRose:
            CompassLockup { CompassRoseMark(size: 44) }

        // 9a — the control: today's pin in the same setting.
        case .compassPin:
            CompassLockup { PinPlaneMark(size: 36) }

        // 9b — a world and the path around it.
        case .compassOrbit:
            CompassLockup { OrbitMark(size: 46) }

        // 9c — a star that lands on a place.
        case .compassWaypoint:
            CompassLockup { WaypointMark(size: 44) }

        // 10 — new mark: the W as a travelled route.
        case .routeMonogram:
            HStack(spacing: 11) {
                RouteMonogramMark(size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text("WANDERLUST")
                        .font(.kanit(15).weight(.semibold))
                        .tracking(3.2)
                        .foregroundStyle(Brand.ink)
                    Text("Get inspired for your next travel")
                        .font(.kanit(10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        }
    }
}

// MARK: - Prompt

private struct HomeLogoPrompt: View {
    let concept: HomeLogoConcept

    var body: some View {
        switch concept {
        case .brandAsHeadline:
            VStack(alignment: .leading, spacing: 8) {
                Text("Wanderlust")
                    .font(.kanitLight(46))
                    .foregroundStyle(Brand.sweep)
                Text("Where are you going next?")
                    .font(.kanit(15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        default:
            Text("Where are you\ngoing next?")
                .font(.kanitLight(30))
                .lineSpacing(-3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Marks

/// The compass lockup, factored out so the four mark candidates are compared in
/// a setting that is identical to the pixel: mark, 12pt, name in wide lowercase.
private struct CompassLockup<Mark: View>: View {
    @ViewBuilder let mark: () -> Mark

    var body: some View {
        VStack(spacing: 12) {
            mark()
                .frame(height: 46)

            Text("wanderlust")
                .font(.kanitLight(23))
                .tracking(7.5)
                .padding(.leading, 7.5)
                .foregroundStyle(Brand.ink.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 100)
    }
}

/// **Orbit** — a world, and the path around it, broken where the traveller is.
///
/// Reads as a brand mark first and as travel second, which is the point: it can
/// sit next to any category the product grows into, and it survives being
/// stamped, embroidered or shrunk to a favicon.
private struct OrbitMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // No planet in the middle: a ring around a disc reads as an eye at
            // any size. What is left is the path itself — open, because the
            // journey is not finished — with the traveller on it.
            Ellipse()
                .trim(from: 0.08, to: 0.78)
                .stroke(Brand.sweep, style: StrokeStyle(lineWidth: size * 0.065, lineCap: .round))
                .frame(width: size, height: size * 0.44)
                .rotationEffect(.degrees(-20))

            Circle()
                .fill(Brand.violet)
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: size * 0.44, y: -size * 0.20)
        }
        .frame(width: size, height: size * 0.62)
    }
}

/// **Waypoint** — a four-point star whose south point is drawn out until it
/// lands on a place, with the map dot beneath it.
///
/// One shape carrying the whole proposition: the inspiration (the star) and the
/// arrival (the point and its anchor). Asymmetric, so it is ownable in a way a
/// symmetrical star or a stock pin never is.
private struct WaypointMark: View {
    let size: CGFloat

    var body: some View {
        VStack(spacing: size * 0.05) {
            WaypointStar()
                .fill(Brand.sweep)
                .frame(width: size * 0.74, height: size * 0.92)

            Ellipse()
                .fill(Brand.tint.opacity(0.34))
                .frame(width: size * 0.26, height: size * 0.085)
        }
        .frame(width: size, height: size)
    }
}

private struct WaypointStar: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }

        // The waist sits high, so the southern point reads as a descent to the
        // ground rather than as the fourth arm of a symmetrical star.
        let waist = point(0.5, 0.34)

        var path = Path()
        path.move(to: point(0.5, 0))
        path.addQuadCurve(to: point(1, 0.34), control: waist)
        path.addQuadCurve(to: point(0.5, 1), control: waist)
        path.addQuadCurve(to: point(0, 0.34), control: waist)
        path.addQuadCurve(to: point(0.5, 0), control: waist)
        path.closeSubpath()
        return path
    }
}

/// The production-candidate icon: a squircle badge with a compass needle in
/// negative space. The needle's two halves are one shape split along its axis,
/// so the mark keeps working at tab-bar size where a plane silhouette mushes.
private struct WanderlustMark: View {
    let size: CGFloat
    /// On the tinted panel the gradient badge disappears, so the mark inverts
    /// to a translucent well with a white needle.
    var onDark = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(onDark ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(Brand.badge))
                .overlay {
                    if onDark {
                        RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                            .stroke(.white.opacity(0.45), lineWidth: 1)
                    }
                }

            ZStack {
                NeedlePoint(north: true)
                    .fill(.white)
                NeedlePoint(north: false)
                    .fill(.white.opacity(0.52))
            }
            .frame(width: size * 0.40, height: size * 0.54)
            // The needle tilts off north; the badge stays square to the grid.
            .rotationEffect(.degrees(20))
        }
        .frame(width: size, height: size)
        .shadow(
            color: onDark ? .clear : Brand.tint.opacity(0.28),
            radius: size * 0.22,
            y: size * 0.10
        )
    }
}

/// One end of the compass needle. Two of these meet at the waist, the lit half
/// solid and the shaded half translucent — the whole mark is four straight
/// lines, so it stays crisp down to tab-bar size.
private struct NeedlePoint: Shape {
    let north: Bool

    func path(in rect: CGRect) -> Path {
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width,
                    y: rect.minY + (north ? y : 1 - y) * rect.height)
        }

        var path = Path()
        path.move(to: point(0.5, 0))
        path.addLine(to: point(0.94, 0.5))
        path.addLine(to: point(0.06, 0.5))
        path.closeSubpath()
        return path
    }
}

/// A compass rose drawn from strokes: four cardinal points, a bearing ring and
/// the diagonals cut short, so it reads as an instrument rather than a sparkle.
private struct CompassRoseMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Brand.tint.opacity(0.30), lineWidth: 0.9)

            ForEach(0..<4, id: \.self) { quadrant in
                CardinalPoint()
                    .fill(quadrant == 0 ? Brand.tint : Brand.tint.opacity(0.42))
                    .rotationEffect(.degrees(Double(quadrant) * 90))
            }

            ForEach(0..<4, id: \.self) { quadrant in
                Rectangle()
                    .fill(Brand.tint.opacity(0.28))
                    .frame(width: 0.8, height: size * 0.16)
                    .offset(y: -size * 0.40)
                    .rotationEffect(.degrees(45 + Double(quadrant) * 90))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct CardinalPoint: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.06))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.10, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.10))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.10, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// The W rebuilt as a route: one stroked polyline with rounded joins, a hollow
/// origin and a filled destination. Nothing about it is a letter until you read
/// it as one.
private struct RouteMonogramMark: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RouteWShape()
                .stroke(
                    Brand.sweep,
                    style: StrokeStyle(lineWidth: size * 0.10, lineCap: .round, lineJoin: .round)
                )

            Circle()
                .stroke(Brand.tint, lineWidth: size * 0.07)
                .frame(width: size * 0.17, height: size * 0.17)
                .position(x: 0, y: size * 0.16)

            Circle()
                .fill(Brand.violet)
                .frame(width: size * 0.18, height: size * 0.18)
                .position(x: size, y: size * 0.16)
        }
        .frame(width: size, height: size * 0.82)
    }
}

private struct RouteWShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.20),
            CGPoint(x: 0.26, y: 1.00),
            CGPoint(x: 0.50, y: 0.42),
            CGPoint(x: 0.74, y: 1.00),
            CGPoint(x: 1.00, y: 0.20)
        ]

        var path = Path()
        for (index, point) in points.enumerated() {
            let scaled = CGPoint(x: rect.minX + point.x * rect.width,
                                 y: rect.minY + point.y * rect.height)
            index == 0 ? path.move(to: scaled) : path.addLine(to: scaled)
        }
        return path
    }
}

/// Real glyph outlines for a Kanit string, so the wordmark can be stroked,
/// gradient-filled or offset-stacked — none of which `Text` allows.
///
/// The path is laid out once at a nominal size and then scaled into `rect`, so
/// callers only set a height and the width follows the letterforms.
private struct WordmarkShape: Shape {
    let text: String
    let tracking: CGFloat
    /// Kanit ships no semibold; bold is the closer match to the letterforms in
    /// `app-logo` once the caps are tracked out.
    var fontName = "Kanit-Bold"

    func path(in rect: CGRect) -> Path {
        let nominal: CGFloat = 100
        let glyphs = glyphPath(size: nominal)
        let bounds = glyphs.boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let scale = rect.height / bounds.height
        let width = bounds.width * scale

        var transform = CGAffineTransform.identity
            .translatedBy(x: rect.minX + (rect.width - width) / 2, y: rect.minY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -bounds.minX, y: -bounds.minY)

        return Path(glyphs.cgPath.copy(using: &transform) ?? glyphs.cgPath)
    }

    private func glyphPath(size: CGFloat) -> Path {
        let font = CTFontCreateWithName(fontName as CFString, size, nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .kern: tracking * size / 30
            ]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        guard let runs = CTLineGetGlyphRuns(line) as? [CTRun] else { return Path() }

        let combined = CGMutablePath()
        for run in runs {
            let count = CTRunGetGlyphCount(run)
            guard count > 0 else { continue }

            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)

            let runFont = unsafeBitCast(
                CFDictionaryGetValue(
                    CTRunGetAttributes(run),
                    unsafeBitCast(kCTFontAttributeName, to: UnsafeRawPointer.self)
                ),
                to: CTFont.self
            )

            for index in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
                // CoreText is y-up; SwiftUI is y-down.
                let placement = CGAffineTransform(translationX: positions[index].x, y: positions[index].y)
                    .scaledBy(x: 1, y: -1)
                combined.addPath(glyph, transform: placement)
            }
        }
        return Path(combined)
    }
}

#Preview {
    NavigationStack { HomeLogoLab() }
}

#endif
