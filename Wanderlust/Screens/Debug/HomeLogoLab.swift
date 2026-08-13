//
//  HomeLogoLab.swift
//  Wanderlust
//
//  One playground entry for the Home screen's top block: brand mark, subtitle
//  and prompt. Everything from the wordmark down to the suggestion chips is
//  real-looking but inert; the bottom third is a switcher so the ten concepts
//  can be compared in place, on the live Aurora backdrop, in a second.
//
//  Delete this file once a direction is chosen and folded into HomeScreen.
//

#if DEBUG

import CoreText
import DesignSystem
import SwiftUI

// MARK: - Concepts

enum HomeLogoConcept: String, CaseIterable, Identifiable {
    case contourWordmark
    case bleedBackdrop
    case leadingSignature
    case appChromeRow
    case monogramOnly
    case brandAsHeadline
    case editorialRules
    case gradientCompact
    case greetingLed
    case letterpress

    var id: String { rawValue }

    var chipLabel: String {
        switch self {
        case .contourWordmark: "Contour"
        case .bleedBackdrop: "Bleed"
        case .leadingSignature: "Signature"
        case .appChromeRow: "Chrome"
        case .monogramOnly: "Monogram"
        case .brandAsHeadline: "Headline"
        case .editorialRules: "Editorial"
        case .gradientCompact: "Compact"
        case .greetingLed: "Greeting"
        case .letterpress: "Letterpress"
        }
    }

    var title: String {
        switch self {
        case .contourWordmark: "1 — Contour wordmark"
        case .bleedBackdrop: "2 — Wordmark as backdrop"
        case .leadingSignature: "3 — Leading signature"
        case .appChromeRow: "4 — App chrome row"
        case .monogramOnly: "5 — Monogram only"
        case .brandAsHeadline: "6 — Brand is the headline"
        case .editorialRules: "7 — Editorial rules"
        case .gradientCompact: "8 — Compact gradient mark"
        case .greetingLed: "9 — Greeting leads"
        case .letterpress: "10 — Letterpress"
        }
    }

    var rationale: String {
        switch self {
        case .contourWordmark:
            "Same lockup, hollow. Outlined glyphs weigh a third of the filled ones, so it can stay large without shouting."
        case .bleedBackdrop:
            "The wordmark stops being an object and becomes the surface: full-bleed, near-transparent, the prompt sitting on top of it."
        case .leadingSignature:
            "Left-aligned to the same column as everything below. The mark is a signature, not a splash screen."
        case .appChromeRow:
            "Signature left, account right. The top reads as an app bar you can act on, which is what a returning user wants."
        case .monogramOnly:
            "No wordmark at all. The app's name is on the icon they tapped; the screen only needs the mark."
        case .brandAsHeadline:
            "One display line instead of two competing ones — the name does the work the question was doing."
        case .editorialRules:
            "Tracked caps between hairlines, no sparkle, no subtitle. Quiet fashion-house confidence."
        case .gradientCompact:
            "Small, dense, gradient-filled, one sparkle as punctuation. Brand present at 40% of the height."
        case .greetingLed:
            "Brand shrinks to a tab-bar-sized mark; the screen greets you and gets to the point."
        case .letterpress:
            "Pressed into the aurora rather than placed on it — big, but reading as texture, not as a logo drop."
        }
    }
}

// MARK: - Lab shell

struct HomeLogoLab: View {
    @State private var concept: HomeLogoConcept = .leadingSignature
    @State private var query = ""

    private let suggestions = ["Lisbon", "Tokyo", "Norway road trip", "North Vietnam"]

    var body: some View {
        VStack(spacing: 0) {
            preview
            Divider().opacity(0.35)
            switcher
        }
        .background { AuroraBackground() }
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
        .background(alignment: .top) { HomeLogoBackdrop(concept: concept) }
    }

    private var askField: some View {
        HStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Color.appTint)

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
                .foregroundStyle(Color.appTint)
                .frame(width: 34, height: 44)
        }
        .padding(.leading, 20)
        .padding(.trailing, 14)
        .frame(minHeight: 88)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 24))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.72), lineWidth: 1) }
        .shadow(color: Color.appTint.opacity(0.08), radius: 20, y: 10)
    }

    private var chips: some View {
        HStack(spacing: 8) {
            ForEach(suggestions.prefix(3), id: \.self) { suggestion in
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
                                    option == concept ? AnyShapeStyle(Color.appTint)
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
                Text(concept.title)
                    .font(.kanit(14).weight(.semibold))
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
// MARK: - The ten top blocks
//
// Each concept is split into three layers so the lab can keep HomeScreen's real
// vertical rhythm: the brand sits at the top, the prompt travels with the input
// field, and anything meant to read as part of the background is drawn behind
// both rather than inserted between them.

/// The brand lockup, at the very top of the screen.
private struct HomeLogoBrand: View {
    let concept: HomeLogoConcept

    private let accent = Color(hex: "#F5C56B")
    private var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color.appTint, Color(hex: "#8B6BF6")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        switch concept {
        // 1 — the current lockup, hollow.
        case .contourWordmark:
            VStack(spacing: 0) {
                SparkleCluster(style: .outlined)
                    .frame(width: 60, height: 52)

                WordmarkShape(text: "WANDERLUST", tracking: 6)
                    .stroke(Color.appTint, style: StrokeStyle(lineWidth: 1.1, lineJoin: .round))
                    .frame(height: 25)
                    .padding(.top, 10)

                Text("Get inspired for your next travel")
                    .font(.kanitLightItalic(10))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }

        // 2 — the wordmark is the surface, drawn in the backdrop layer.
        case .bleedBackdrop:
            Color.clear.frame(height: 74)

        // 3 — a signature on the same left rail as everything below.
        case .leadingSignature:
            HStack(spacing: 9) {
                PinPlaneMark(size: 16)
                Text("WANDERLUST")
                    .font(.kanit(13).weight(.semibold))
                    .tracking(3.4)
                    .foregroundStyle(Color.appTint)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

        // 4 — the same signature, made into a real app bar.
        case .appChromeRow:
            HStack(spacing: 9) {
                PinPlaneMark(size: 16)
                Text("WANDERLUST")
                    .font(.kanit(13).weight(.semibold))
                    .tracking(3.4)
                    .foregroundStyle(Color.appTint)

                Spacer()

                Image(systemName: "person.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.appTint)
                    .frame(width: 34, height: 34)
                    .background(.white.opacity(0.66), in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.8), lineWidth: 1) }
            }
            .frame(minHeight: 44)

        // 5 — the mark alone; the name was on the icon they tapped.
        case .monogramOnly:
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.appTint, Color(hex: "#8B6BF6")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                PlaneShape()
                    .fill(.white)
                    .frame(width: 20, height: 20)
                    .rotationEffect(.degrees(45))
            }
            .frame(width: 44, height: 44)
            .shadow(color: Color.appTint.opacity(0.26), radius: 12, y: 6)
            .frame(maxWidth: .infinity, alignment: .leading)

        // 6 — the name becomes the display line; no lockup above it.
        case .brandAsHeadline:
            Color.clear.frame(height: 8)

        // 7 — tracked caps between hairlines. No sparkle, no subtitle.
        case .editorialRules:
            HStack(spacing: 14) {
                hairline
                Text("WANDERLUST")
                    .font(.kanit(15).weight(.medium))
                    .tracking(5.2)
                    .foregroundStyle(Color.appTint.opacity(0.9))
                    .fixedSize()
                    // Tracking hangs off the final T; offset half of it back so
                    // the word sits optically centred between the rules.
                    .padding(.leading, 5.2)
                hairline
            }
            .frame(minHeight: 44)

        // 8 — small, dense, gradient, one sparkle as punctuation.
        case .gradientCompact:
            HStack(alignment: .top, spacing: 5) {
                Text("WANDERLUST")
                    .font(.kanit(21).weight(.semibold))
                    .tracking(3.2)
                    .foregroundStyle(brandGradient)
                SparkleShape()
                    .fill(accent)
                    .frame(width: 9, height: 9)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)

        // 9 — brand steps back to tab-bar size so the greeting can lead.
        case .greetingLed:
            HStack(spacing: 7) {
                PinPlaneMark(size: 12)
                Text("WANDERLUST")
                    .font(.kanit(10).weight(.semibold))
                    .tracking(2.6)
                    .foregroundStyle(Color.appTint.opacity(0.75))
            }
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)

        // 10 — pressed into the aurora rather than placed on it.
        case .letterpress:
            ZStack {
                WordmarkShape(text: "WANDERLUST", tracking: 5)
                    .fill(.white.opacity(0.9))
                    .frame(height: 29)
                    .offset(y: 1.4)

                WordmarkShape(text: "WANDERLUST", tracking: 5)
                    .fill(Color.appTint.opacity(0.42))
                    .frame(height: 29)
                    .offset(y: -0.8)

                WordmarkShape(text: "WANDERLUST", tracking: 5)
                    .fill(Color(hex: "#E4E8F8"))
                    .frame(height: 29)
            }
            .compositingGroup()
            .frame(height: 54)
        }
    }

    private var hairline: some View {
        Rectangle()
            .fill(Color.appTint.opacity(0.28))
            .frame(height: 1)
    }
}

/// The display line directly above the input field.
private struct HomeLogoPrompt: View {
    let concept: HomeLogoConcept

    private let accent = Color(hex: "#F5C56B")

    var body: some View {
        switch concept {
        case .brandAsHeadline:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 6) {
                    Text("Wanderlust")
                        .font(.kanitLight(46))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appTint, Color(hex: "#8B6BF6")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    SparkleShape()
                        .fill(accent)
                        .frame(width: 11, height: 11)
                        .padding(.top, 14)
                }
                Text("Where are you going next?")
                    .font(.kanit(15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .greetingLed:
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.kanitLight(34))
                Text("Where are you going next?")
                    .font(.kanit(15))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case .monogramOnly:
            Text("Where are you\ngoing next?")
                .font(.kanitLight(34))
                .lineSpacing(-3)
                .frame(maxWidth: .infinity, alignment: .leading)

        default:
            Text("Where are you\ngoing next?")
                .font(.kanitLight(30))
                .lineSpacing(-3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<18: "Good afternoon"
        default: "Good evening"
        }
    }
}

/// Anything that should read as part of the background rather than as an
/// element sitting on it.
private struct HomeLogoBackdrop: View {
    let concept: HomeLogoConcept

    var body: some View {
        if concept == .bleedBackdrop {
            WordmarkShape(text: "WANDERLUST", tracking: 1, fit: .width)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appTint.opacity(0.24),
                            Color(hex: "#8B6BF6").opacity(0.10)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 56)
                // Cancels the shell's 20pt gutter exactly: the word spans the
                // screen edge to edge without losing its first and last letter.
                .padding(.horizontal, -20)
                .padding(.top, 30)
                .blur(radius: 0.4)
        }
    }
}

// MARK: - Drawn marks

/// A four-pointed sparkle with concave sides, matching the mark in `app-logo`.
private struct SparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: c.x, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: c.y), control: c)
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.maxY), control: c)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: c.y), control: c)
        path.addQuadCurve(to: CGPoint(x: c.x, y: rect.minY), control: c)
        path.closeSubpath()
        return path
    }
}

/// The three-sparkle cluster above the wordmark, filled or as contours.
private struct SparkleCluster: View {
    enum Style { case filled, outlined }

    let style: Style

    private let accent = Color(hex: "#F5C56B")

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .topLeading) {
                sparkle(size: w * 0.52).offset(x: 0, y: 0)
                sparkle(size: w * 0.38).offset(x: w * 0.44, y: w * 0.30)
                sparkle(size: w * 0.28).offset(x: w * 0.18, y: w * 0.56)
            }
        }
    }

    @ViewBuilder
    private func sparkle(size: CGFloat) -> some View {
        switch style {
        case .filled:
            SparkleShape().fill(accent).frame(width: size, height: size)
        case .outlined:
            SparkleShape()
                .stroke(accent, style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
                .frame(width: size, height: size)
        }
    }
}

/// Real glyph outlines for a Kanit string, so the wordmark can be stroked,
/// gradient-filled or offset-stacked — none of which `Text` allows.
///
/// The path is laid out once at a nominal size and then scaled to fill `rect`,
/// so callers only set a height and the width follows the letterforms.
private struct WordmarkShape: Shape {
    enum Fit {
        /// Scale to the offered height; the width follows the letterforms.
        case height
        /// Scale to the offered width, centred vertically — for the full-bleed
        /// treatment, where the word has to span the screen exactly.
        case width
    }

    let text: String
    let tracking: CGFloat
    var fit: Fit = .height
    /// Kanit ships no semibold; bold is the closer match to the letterforms in
    /// `app-logo` once the caps are tracked out.
    var fontName = "Kanit-Bold"

    func path(in rect: CGRect) -> Path {
        let nominal: CGFloat = 100
        let glyphs = glyphPath(size: nominal)
        let bounds = glyphs.boundingRect
        guard bounds.width > 0, bounds.height > 0 else { return Path() }

        let scale = switch fit {
        case .height: rect.height / bounds.height
        case .width: rect.width / bounds.width
        }
        let width = bounds.width * scale
        let height = bounds.height * scale

        var transform = CGAffineTransform.identity
            .translatedBy(
                x: rect.minX + (rect.width - width) / 2,
                y: rect.minY + (fit == .width ? (rect.height - height) / 2 : 0)
            )
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
        let runs = CTLineGetGlyphRuns(line) as! [CTRun]

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
