#if DEBUG

import DesignSystem
import SwiftUI
import UIKit

// MARK: - Questionnaire Concept Lab
//
// Five deliberately isolated interaction prototypes for the eight bipolar
// travel-preference dimensions. Nothing in this file writes to TripOrganizer,
// analytics, usage limits, or itinerary generation.

// MARK: Shared semantic content

private struct LabPole {
    let title: String
    let description: String
    let symbol: String
    let beats: [String]
    let moment: String
    let colors: [Color]
}

private struct LabQuestion: Identifiable {
    let id: Int
    let dimension: String
    let prompt: String
    let left: LabPole
    let right: LabPole
}

private enum LabContent {
    static let questions: [LabQuestion] = [
        LabQuestion(
            id: 1,
            dimension: "Surroundings",
            prompt: "What should surround you?",
            left: LabPole(
                title: "City energy",
                description: "People, stories, and urban rhythm",
                symbol: "building.2.fill",
                beats: ["Coffee in a busy square", "Neighborhoods on foot", "A late gallery stop"],
                moment: "Spend an afternoon drifting through lively neighborhoods.",
                colors: [Color(hex: "#6B68E8"), Color(hex: "#D982B5")]
            ),
            right: LabPole(
                title: "Natural beauty",
                description: "Views, trails, and open horizons",
                symbol: "mountain.2.fill",
                beats: ["Wake beside open water", "Follow a ridgeline", "Watch the sky change"],
                moment: "Follow a trail until the city disappears.",
                colors: [Color(hex: "#2F8F83"), Color(hex: "#9BCB7C")]
            )
        ),
        LabQuestion(
            id: 2,
            dimension: "Familiarity",
            prompt: "How much surprise feels good?",
            left: LabPole(
                title: "Proven favorites",
                description: "A reliable plan with no wasted time",
                symbol: "checkmark.seal.fill",
                beats: ["Reserve the known favorite", "Follow a proven route", "Know it will be worth it"],
                moment: "Build the day around places travelers consistently love.",
                colors: [Color(hex: "#5566B8"), Color(hex: "#8FA7E8")]
            ),
            right: LabPole(
                title: "New territory",
                description: "Try something unfamiliar and welcome surprise",
                symbol: "sparkles",
                beats: ["Leave a gap in the plan", "Follow a curious detail", "Try the unfamiliar thing"],
                moment: "Leave a blank afternoon and follow whatever looks curious.",
                colors: [Color(hex: "#E56D5B"), Color(hex: "#F4B85D")]
            )
        ),
        LabQuestion(
            id: 3,
            dimension: "Pace",
            prompt: "What pace restores you?",
            left: LabPole(
                title: "Unwind",
                description: "Slow down, recharge, and enjoy the calm",
                symbol: "cup.and.saucer.fill",
                beats: ["A late breakfast", "Nowhere to rush", "A quiet sunset"],
                moment: "Keep a slow morning with nowhere you need to be.",
                colors: [Color(hex: "#4B91A6"), Color(hex: "#A7D8D2")]
            ),
            right: LabPole(
                title: "Adventure",
                description: "Stay active, explore, and try something new",
                symbol: "figure.hiking",
                beats: ["Start before the crowds", "Take the active route", "Say yes once more"],
                moment: "Book the activity that makes your pulse jump.",
                colors: [Color(hex: "#EF7A48"), Color(hex: "#F2C14E")]
            )
        ),
        LabQuestion(
            id: 4,
            dimension: "Food",
            prompt: "How should the trip taste?",
            left: LabPole(
                title: "Casual local food",
                description: "Counters, markets, and everyday flavor",
                symbol: "takeoutbag.and.cup.and.straw.fill",
                beats: ["Follow the local queue", "Order at the counter", "Eat it while it is hot"],
                moment: "Eat at the busy counter locals keep returning to.",
                colors: [Color(hex: "#E27A3F"), Color(hex: "#F5C15D")]
            ),
            right: LabPole(
                title: "Occasion dining",
                description: "Book ahead, dress up, and linger",
                symbol: "fork.knife",
                beats: ["Choose the room", "Let dinner be the event", "Stay for another course"],
                moment: "Make one dressed-up dinner the main event.",
                colors: [Color(hex: "#315B73"), Color(hex: "#6EA3A3")]
            )
        ),
        LabQuestion(
            id: 5,
            dimension: "Time lens",
            prompt: "Which layer of a place pulls you in?",
            left: LabPole(
                title: "Historic layers",
                description: "Old streets, enduring craft, and stories",
                symbol: "building.columns.fill",
                beats: ["Trace an old street", "Notice what survived", "Hear the story behind it"],
                moment: "Trace the stories held in old streets and ruins.",
                colors: [Color(hex: "#A96F45"), Color(hex: "#D9B06F")]
            ),
            right: LabPole(
                title: "Contemporary scene",
                description: "New ideas, current culture, and living pulse",
                symbol: "square.3.layers.3d.top.filled",
                beats: ["Find the newest district", "See what people make now", "Catch the city changing"],
                moment: "Find the newest creative corner of the city.",
                colors: [Color(hex: "#3A6EA5"), Color(hex: "#63C5DA")]
            )
        ),
        LabQuestion(
            id: 6,
            dimension: "Evenings",
            prompt: "When the sun goes down?",
            left: LabPole(
                title: "Night energy",
                description: "Music, crowds, and one more place",
                symbol: "music.note",
                beats: ["Start with a busy bar", "Follow the music", "Stay out while it is good"],
                moment: "Stay out while the city is still dancing.",
                colors: [Color(hex: "#6A3FA0"), Color(hex: "#E05A9D")]
            ),
            right: LabPole(
                title: "Slow evenings",
                description: "Cozy places and unhurried plans",
                symbol: "moon.stars.fill",
                beats: ["Find a quiet table", "Let conversation stretch", "Walk home slowly"],
                moment: "End with a long dinner and an unhurried walk.",
                colors: [Color(hex: "#245C73"), Color(hex: "#6FA6A1")]
            )
        ),
        LabQuestion(
            id: 7,
            dimension: "Spending",
            prompt: "Where should the budget land?",
            left: LabPole(
                title: "Make it stretch",
                description: "Smart choices that leave room for more travel",
                symbol: "wallet.pass.fill",
                beats: ["Choose value over polish", "Save where it will not matter", "Keep the next trip possible"],
                moment: "Stretch the budget so the trip can keep going.",
                colors: [Color(hex: "#4D8A69"), Color(hex: "#A6C77D")]
            ),
            right: LabPole(
                title: "Spend for standout",
                description: "Pay more when an experience feels singular",
                symbol: "star.circle.fill",
                beats: ["Upgrade the memorable part", "Pay for the rare access", "Treat it as the occasion"],
                moment: "Pay more when the experience feels truly singular.",
                colors: [Color(hex: "#9B6A32"), Color(hex: "#E2B75B")]
            )
        ),
        LabQuestion(
            id: 8,
            dimension: "Popularity",
            prompt: "Which places deserve your time?",
            left: LabPole(
                title: "Must-see icons",
                description: "The landmarks that define the destination",
                symbol: "camera.fill",
                beats: ["See the famous silhouette", "Understand why it matters", "Take the classic photo"],
                moment: "See the landmark that defines the destination.",
                colors: [Color(hex: "#C65B52"), Color(hex: "#F0A76A")]
            ),
            right: LabPole(
                title: "Neighborhood secrets",
                description: "Lesser-known places with a local point of view",
                symbol: "map.fill",
                beats: ["Take the side street", "Ask what is nearby", "Find the place without a queue"],
                moment: "Trade the guidebook for a neighborhood secret.",
                colors: [Color(hex: "#347A78"), Color(hex: "#74B69B")]
            )
        )
    ]
}

@MainActor
private final class QuestionnaireLabSession: ObservableObject {
    @Published var currentIndex = 0
    @Published var answers: [Int: Int] = [:]
    @Published var history: [Int] = []

    var isComplete: Bool {
        currentIndex >= LabContent.questions.count
    }

    var currentQuestion: LabQuestion? {
        guard LabContent.questions.indices.contains(currentIndex) else { return nil }
        return LabContent.questions[currentIndex]
    }

    func record(_ value: Int) {
        guard let question = currentQuestion else { return }
        answers[question.id] = max(-2, min(2, value))
        history.append(question.id)
        currentIndex += 1
    }

    func undo() {
        guard currentIndex > 0, let questionID = history.popLast() else { return }
        currentIndex -= 1
        answers.removeValue(forKey: questionID)
    }

    func reset() {
        currentIndex = 0
        answers = [:]
        history = []
    }
}

private enum LabHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func commit() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

private struct LabBackdrop: View {
    var accent: Color = Color.appTint

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.97, blue: 1),
                    Color(red: 1, green: 0.97, blue: 0.90)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(accent.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 20)
                .offset(x: 150, y: -300)

            Circle()
                .fill(Color.orange.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -160, y: 330)
        }
        .ignoresSafeArea()
    }
}

private struct LabHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let completed: Int
    let total: Int
    var onUndo: (() -> Void)?
    var undoLabel = "Undo"

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(Color.appTint)

                Spacer()

                if completed > 0, let onUndo {
                    Button(action: onUndo) {
                        Label(undoLabel, systemImage: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(minHeight: 44)
                    }
                    .foregroundStyle(Color.appTint)
                }

                Text("\(min(completed + 1, total)) / \(total)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(title)
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.07))
                    Capsule()
                        .fill(Color.appTint)
                        .frame(width: proxy.size.width * CGFloat(completed) / CGFloat(max(total, 1)))
                }
            }
            .frame(height: 5)
        }
    }
}

private struct AnswerDots: View {
    let value: Int
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 7) {
            ForEach(-2...2, id: \.self) { dot in
                Circle()
                    .fill(dot == value ? Color.appTint : Color.black.opacity(0.10))
                    .frame(width: compact ? 7 : 10, height: compact ? 7 : 10)
                    .overlay {
                        if dot == 0 && dot != value {
                            Circle().stroke(Color.black.opacity(0.12), lineWidth: 1)
                        }
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct LabCompletionView: View {
    let concept: String
    let message: String
    let answers: [Int: Int]
    let onReset: () -> Void

    var body: some View {
        ZStack {
            LabBackdrop(accent: Color(hex: "#34A389"))

            ScrollView {
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#34A389").opacity(0.14))
                            .frame(width: 78, height: 78)
                        Image(systemName: "checkmark")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundStyle(Color(hex: "#23806C"))
                    }

                    VStack(spacing: 6) {
                        Text("Your travel mix")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text(message)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 0) {
                        ForEach(LabContent.questions) { question in
                            let value = answers[question.id] ?? 0
                            VStack(spacing: 9) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(question.dimension)
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                    Spacer()
                                    Text(answerLabel(for: question, value: value))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.appTint)
                                        .multilineTextAlignment(.trailing)
                                }

                                HStack {
                                    Text(question.left.title)
                                    Spacer()
                                    AnswerDots(value: value, compact: true)
                                    Spacer()
                                    Text(question.right.title)
                                }
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 12)

                            if question.id != LabContent.questions.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(.white.opacity(0.8), lineWidth: 1)
                    }

                    Button(action: onReset) {
                        Label("Experience \(concept) again", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.appTint)

                    Text("Prototype only · nothing was saved")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .padding(20)
            }
        }
        .onAppear(perform: LabHaptics.success)
    }

    private func answerLabel(for question: LabQuestion, value: Int) -> String {
        switch value {
        case -2: "Strong \(question.left.title)"
        case -1: "Lean \(question.left.title)"
        case 1: "Lean \(question.right.title)"
        case 2: "Strong \(question.right.title)"
        default: "A bit of both"
        }
    }
}

private struct FiveStopSelector: View {
    let question: LabQuestion
    @Binding var value: Int?
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 7 : 11) {
            HStack(alignment: .top) {
                Text(question.left.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(question.right.title)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: compact ? 11 : 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)

            GeometryReader { proxy in
                let inset: CGFloat = 14
                let available = max(1, proxy.size.width - inset * 2)
                let selected = value ?? 0
                let x = inset + available * CGFloat(selected + 2) / 4

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [question.left.colors[0], Color.white, question.right.colors[0]],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: compact ? 7 : 9)
                        .padding(.horizontal, inset)

                    ForEach(-2...2, id: \.self) { stop in
                        let stopX = inset + available * CGFloat(stop + 2) / 4
                        Circle()
                            .fill(.white)
                            .frame(width: compact ? 14 : 18, height: compact ? 14 : 18)
                            .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 1))
                            .position(x: stopX, y: proxy.size.height / 2)
                            .onTapGesture {
                                setValue(stop)
                            }
                    }

                    Circle()
                        .fill(value == nil ? Color.white.opacity(0.78) : Color.appTint)
                        .frame(width: compact ? 24 : 31, height: compact ? 24 : 31)
                        .overlay {
                            Circle()
                                .stroke(value == nil ? Color.appTint.opacity(0.35) : .white, lineWidth: 3)
                        }
                        .shadow(color: Color.appTint.opacity(0.22), radius: 8, y: 3)
                        .position(x: x, y: proxy.size.height / 2)
                        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: value)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            let normalized = (drag.location.x - inset) / available
                            let newValue = Int((normalized * 4).rounded()) - 2
                            setValue(max(-2, min(2, newValue)))
                        }
                )
            }
            .frame(height: compact ? 28 : 38)

            HStack {
                Text("Strong")
                Spacer()
                Text("Lean")
                Spacer()
                Text("Both")
                Spacer()
                Text("Lean")
                Spacer()
                Text("Strong")
            }
            .font(.system(size: compact ? 8 : 9, weight: .medium, design: .rounded))
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(question.dimension). \(question.left.title) to \(question.right.title)")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            let current = value ?? 0
            switch direction {
            case .increment: setValue(min(2, current + 1))
            case .decrement: setValue(max(-2, current - 1))
            @unknown default: break
            }
        }
    }

    private var accessibilityValue: String {
        guard let value else { return "Not set" }
        switch value {
        case -2: return "Strongly \(question.left.title)"
        case -1: return "Leaning \(question.left.title)"
        case 1: return "Leaning \(question.right.title)"
        case 2: return "Strongly \(question.right.title)"
        default: return "Both"
        }
    }

    private func setValue(_ newValue: Int) {
        guard newValue != value else { return }
        value = newValue
        LabHaptics.selection()
    }
}

// MARK: 1 — Very close, improved: Split Postcard 2.0

struct SplitPostcardPrototype: View {
    @StateObject private var session = QuestionnaireLabSession()
    @State private var drag: CGSize = .zero
    @State private var highlightedValue: Int?
    @State private var isCommitting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if session.isComplete {
                completionView
            } else if let question = session.currentQuestion {
                activeView(for: question)
            }
        }
        .navigationTitle("Concept 1")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var completionView: some View {
        LabCompletionView(
            concept: "Split Postcard",
            message: "The familiar deck, now with live content and five useful levels of preference.",
            answers: session.answers,
            onReset: session.reset
        )
    }

    private func activeView(for question: LabQuestion) -> some View {
        ZStack {
            LabBackdrop()

            ScrollView {
                VStack(spacing: 14) {
                    LabHeader(
                        eyebrow: "01 · Very close",
                        title: "Split Postcard",
                        subtitle: "Swipe toward a side. A short pull leans; a long pull chooses strongly. Swipe up for both.",
                        completed: session.currentIndex,
                        total: LabContent.questions.count,
                        onUndo: session.currentIndex > 0 && !isCommitting ? { undo() } : nil
                    )
                    .padding(.horizontal, 20)

                    cardStack(for: question)
                        .padding(.horizontal, 20)

                    quickChoices(for: question)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func cardStack(for question: LabQuestion) -> some View {
        ZStack {
            if LabContent.questions.indices.contains(session.currentIndex + 1) {
                SplitPostcard(
                    question: LabContent.questions[session.currentIndex + 1],
                    drag: .zero,
                    highlightedValue: nil
                )
                .scaleEffect(0.94)
                .offset(y: 13)
                .opacity(0.52)
            }

            SplitPostcard(
                question: question,
                drag: drag,
                highlightedValue: highlightedValue
            )
            .offset(drag)
            .rotationEffect(.degrees(Double(drag.width / 22)))
            .gesture(cardGesture)
            .allowsHitTesting(!isCommitting)
        }
    }

    private var cardGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !isCommitting else { return }
                drag = value.translation
                let newHighlight = candidate(for: value.translation)
                if newHighlight != highlightedValue {
                    highlightedValue = newHighlight
                    if newHighlight != nil { LabHaptics.selection() }
                }
            }
            .onEnded { value in
                if let choice = resolvedCandidate(
                    actual: value.translation,
                    predicted: value.predictedEndTranslation
                ) {
                    commit(choice)
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                        drag = .zero
                        highlightedValue = nil
                    }
                }
            }
    }

    private func candidate(for translation: CGSize) -> Int? {
        if translation.height < -80, abs(translation.width) < 95 { return 0 }
        guard abs(translation.width) > 48 else { return nil }
        let strength = abs(translation.width) > 150 ? 2 : 1
        return translation.width < 0 ? -strength : strength
    }

    private func resolvedCandidate(actual: CGSize, predicted: CGSize) -> Int? {
        if let actualChoice = candidate(for: actual) {
            return actualChoice
        }

        if predicted.height < -80, abs(predicted.width) < 95 {
            return 0
        }

        guard abs(predicted.width) > 48 else { return nil }
        return predicted.width < 0 ? -1 : 1
    }

    private func quickChoices(for question: LabQuestion) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                choiceButton("Strong", value: -2, symbol: "arrow.left")
                choiceButton("Lean", value: -1)
                choiceButton("Both", value: 0, symbol: "arrow.up")
                choiceButton("Lean", value: 1)
                choiceButton("Strong", value: 2, symbol: "arrow.right")
            }

            HStack {
                Text(question.left.title)
                Spacer()
                Text(question.right.title)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }

    private func choiceButton(_ title: String, value: Int, symbol: String? = nil) -> some View {
        Button {
            commit(value)
        } label: {
            VStack(spacing: 3) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choiceAccessibilityLabel(value))
    }

    private func choiceAccessibilityLabel(_ value: Int) -> String {
        guard let question = session.currentQuestion else { return "Choose" }
        switch value {
        case -2: return "Strongly \(question.left.title)"
        case -1: return "Lean \(question.left.title)"
        case 1: return "Lean \(question.right.title)"
        case 2: return "Strongly \(question.right.title)"
        default: return "Both"
        }
    }

    private func commit(_ value: Int) {
        guard !isCommitting else { return }
        isCommitting = true
        highlightedValue = value
        LabHaptics.commit()

        let exit: CGSize = switch value {
        case ..<0: CGSize(width: -520, height: -30)
        case 1...: CGSize(width: 520, height: -30)
        default: CGSize(width: 0, height: -720)
        }

        withAnimation(reduceMotion ? .linear(duration: 0.08) : .spring(response: 0.42, dampingFraction: 0.78)) {
            drag = exit
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.24)) {
            session.record(value)
            drag = .zero
            highlightedValue = nil
            isCommitting = false
        }
    }

    private func undo() {
        guard !isCommitting else { return }
        session.undo()
    }
}

private struct SplitPostcard: View {
    let question: LabQuestion
    let drag: CGSize
    let highlightedValue: Int?

    var body: some View {
        GeometryReader { proxy in
            let pull = max(-1, min(1, drag.width / max(proxy.size.width, 1)))
            let leftWidth = proxy.size.width * (0.5 + pull * 0.14)

            HStack(spacing: 0) {
                PostcardPolePanel(
                    pole: question.left,
                    alignment: .leading,
                    isHighlighted: (highlightedValue ?? 0) < 0
                )
                .frame(width: max(120, leftWidth))

                PostcardPolePanel(
                    pole: question.right,
                    alignment: .trailing,
                    isHighlighted: (highlightedValue ?? 0) > 0
                )
            }
            .overlay(alignment: .top) {
                Text(question.prompt)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.24), in: Capsule())
                    .padding(.top, 13)
            }
            .overlay {
                if highlightedValue == 0 {
                    VStack(spacing: 7) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 27, weight: .bold))
                        Text("A bit of both")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                    .background(.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 455)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(question.prompt). \(question.left.title), or \(question.right.title)")
        .accessibilityHint("Swipe left or right. Swipe up for both. Buttons are also available below.")
    }
}

private struct PostcardPolePanel: View {
    let pole: LabPole
    let alignment: HorizontalAlignment
    let isHighlighted: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: pole.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            DecorativeScene(symbol: pole.symbol)
                .opacity(isHighlighted ? 1 : 0.78)
                .scaleEffect(isHighlighted ? 1.08 : 1)

            LinearGradient(
                colors: [.clear, .black.opacity(0.66)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: alignment, spacing: 8) {
                Spacer()

                Image(systemName: pole.symbol)
                    .font(.system(size: 22, weight: .semibold))

                Text(pole.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)

                Text(pole.description)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            .foregroundStyle(.white)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        }
        .animation(.easeOut(duration: 0.16), value: isHighlighted)
    }
}

private struct DecorativeScene: View {
    let symbol: String

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: CGFloat(8 + index * 2), style: .continuous)
                        .stroke(.white.opacity(0.11), lineWidth: 1)
                        .frame(
                            width: proxy.size.width * CGFloat(0.48 + Double(index) * 0.11),
                            height: proxy.size.height * CGFloat(0.25 + Double(index) * 0.08)
                        )
                        .rotationEffect(.degrees(Double(index * 7 - 15)))
                        .offset(y: CGFloat(index * 14 - 48))
                }

                Image(systemName: symbol)
                    .font(.system(size: min(proxy.size.width, proxy.size.height) * 0.32, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.17))
                    .offset(y: -35)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: 2 — Close, evolved: A Day, Two Ways

struct DayTwoWaysPrototype: View {
    @StateObject private var session = QuestionnaireLabSession()
    @State private var draft: Int?

    var body: some View {
        Group {
            if session.isComplete {
                LabCompletionView(
                    concept: "A Day, Two Ways",
                    message: "Concrete moments make the tradeoff easier to answer than an abstract personality label.",
                    answers: session.answers,
                    onReset: {
                        draft = nil
                        session.reset()
                    }
                )
            } else if let question = session.currentQuestion {
                ZStack {
                    LabBackdrop(accent: question.right.colors[0])

                    ScrollView {
                        VStack(spacing: 15) {
                            LabHeader(
                                eyebrow: "02 · Close, evolved",
                                title: "A day, two ways",
                                subtitle: "Scrub between two tiny versions of the same travel day, then add your mix.",
                                completed: session.currentIndex,
                                total: LabContent.questions.count,
                                onUndo: session.currentIndex > 0 ? { undo() } : nil
                            )

                            VStack(spacing: 15) {
                                VStack(spacing: 4) {
                                    Text(question.dimension.uppercased())
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .tracking(1)
                                        .foregroundStyle(Color.appTint)
                                    Text(question.prompt)
                                        .font(.system(size: 22, weight: .bold, design: .rounded))
                                        .multilineTextAlignment(.center)
                                }

                                HStack(alignment: .top, spacing: 10) {
                                    MiniItinerary(
                                        pole: question.left,
                                        emphasis: emphasis(for: -1)
                                    )
                                    MiniItinerary(
                                        pole: question.right,
                                        emphasis: emphasis(for: 1)
                                    )
                                }

                                FiveStopSelector(question: question, value: $draft)
                                    .padding(.horizontal, 6)

                                if draft == 0 {
                                    Label("The two mini-days interleave", systemImage: "arrow.triangle.merge")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.appTint)
                                        .transition(.opacity)
                                }
                            }
                            .padding(16)
                            .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 26, style: .continuous)
                                    .stroke(.white.opacity(0.9), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.08), radius: 18, y: 8)

                            Button(action: commitDraft) {
                                Label(buttonLabel(for: question), systemImage: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.appTint)
                            .disabled(draft == nil)
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Concept 2")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.2), value: draft)
    }

    private func emphasis(for side: Int) -> Double {
        guard let draft else { return 0.78 }
        if draft == 0 { return 1 }
        return draft.signum() == side ? 1 : 0.36
    }

    private func buttonLabel(for question: LabQuestion) -> String {
        guard let draft else { return "Choose a mix" }
        switch draft {
        case -2: return "Add \(question.left.title)"
        case -1: return "Add a \(question.left.title) lean"
        case 1: return "Add a \(question.right.title) lean"
        case 2: return "Add \(question.right.title)"
        default: return "Blend both into the day"
        }
    }

    private func commitDraft() {
        guard let draft else { return }
        LabHaptics.commit()
        withAnimation(.easeInOut(duration: 0.2)) {
            session.record(draft)
            self.draft = nil
        }
    }

    private func undo() {
        session.undo()
        draft = nil
    }
}

private struct MiniItinerary: View {
    let pole: LabPole
    let emphasis: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LinearGradient(colors: pole.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: pole.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(height: 82)

            Text(pole.title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(pole.beats.enumerated()), id: \.offset) { index, beat in
                    HStack(alignment: .top, spacing: 7) {
                        ZStack {
                            Circle().fill(pole.colors[0].opacity(0.14))
                            Text("\(index + 1)")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(pole.colors[0])
                        }
                        .frame(width: 20, height: 20)

                        Text(beat)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(emphasis)
        .scaleEffect(emphasis == 1 ? 1 : 0.97)
    }
}

// MARK: 3 — Outside the box, still cards: The Moments Deck

private struct LabMoment: Identifiable {
    let id: Int
    let questionID: Int
    let poleValue: Int
    let text: String
    let symbol: String
    let colors: [Color]
}

private enum MomentRating: Int {
    case pass = 0
    case save = 1
    case love = 2
}

private enum LabMoments {
    static let order: [(Int, Int)] = [
        (0, -1), (4, 1), (1, 1), (5, -1),
        (2, -1), (6, 1), (3, 1), (7, -1),
        (0, 1), (4, -1), (1, -1), (5, 1),
        (2, 1), (6, -1), (3, -1), (7, 1)
    ]

    static let all: [LabMoment] = order.enumerated().map { sequence, item in
        let question = LabContent.questions[item.0]
        let pole = item.1 < 0 ? question.left : question.right
        return LabMoment(
            id: sequence,
            questionID: question.id,
            poleValue: item.1,
            text: pole.moment,
            symbol: pole.symbol,
            colors: pole.colors
        )
    }
}

struct MomentsDeckPrototype: View {
    @State private var currentIndex = 0
    @State private var ratings: [Int: MomentRating] = [:]
    @State private var history: [Int] = []
    @State private var drag: CGSize = .zero
    @State private var highlighted: MomentRating?
    @State private var isCommitting = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if currentIndex >= LabMoments.all.count {
                LabCompletionView(
                    concept: "Moments Deck",
                    message: "Instead of self-labels, your profile was inferred from the travel moments you saved, loved, or passed.",
                    answers: computedAnswers,
                    onReset: reset
                )
            } else {
                ZStack {
                    LabBackdrop(accent: currentMoment.colors[0])

                    ScrollView {
                        VStack(spacing: 14) {
                            LabHeader(
                                eyebrow: "03 · Cards, reimagined",
                                title: "Would you want this?",
                                subtitle: "Pass left, save right, or flick up for “absolutely.” Paired moments quietly cover all eight dimensions.",
                                completed: currentIndex,
                                total: LabMoments.all.count,
                                onUndo: currentIndex > 0 && !isCommitting ? { undo() } : nil
                            )
                            .padding(.horizontal, 20)

                            savedReel
                                .padding(.horizontal, 20)

                            GeometryReader { proxy in
                                ZStack {
                                    if LabMoments.all.indices.contains(currentIndex + 1) {
                                        MomentCard(moment: LabMoments.all[currentIndex + 1], highlighted: nil)
                                            .frame(width: proxy.size.width)
                                            .scaleEffect(0.94)
                                            .offset(y: 14)
                                            .opacity(0.45)
                                    }

                                    MomentCard(moment: currentMoment, highlighted: highlighted)
                                        .frame(width: proxy.size.width)
                                        .offset(drag)
                                        .rotationEffect(.degrees(Double(drag.width / 24)))
                                        .gesture(momentGesture)
                                        .allowsHitTesting(!isCommitting)
                                }
                                .frame(width: proxy.size.width, height: 445)
                            }
                            .frame(height: 445)
                            .padding(.horizontal, 22)

                            HStack(spacing: 12) {
                                momentButton("Pass", symbol: "xmark", rating: .pass, color: Color(hex: "#D45B64"))
                                momentButton("Love", symbol: "arrow.up", rating: .love, color: Color(hex: "#D08B35"))
                                momentButton("Save", symbol: "heart.fill", rating: .save, color: Color(hex: "#2B9A78"))
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("Concept 3")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentMoment: LabMoment {
        LabMoments.all[currentIndex]
    }

    private var savedReel: some View {
        let savedIDs = history.filter { id in
            guard let rating = ratings[id] else { return false }
            return rating != .pass
        }.suffix(7)

        return HStack(spacing: 6) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.appTint)

            Text("YOUR SAVED MOMENTS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.7)
                .foregroundStyle(.secondary)

            Spacer()

            ForEach(savedIDs, id: \.self) { id in
                if let rating = ratings[id], rating != .pass,
                   let moment = LabMoments.all.first(where: { $0.id == id }) {
                    Image(systemName: moment.symbol)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(moment.colors[0], in: Circle())
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(minHeight: 28)
    }

    private var momentGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                guard !isCommitting else { return }
                drag = value.translation
                let newHighlight = rating(for: value.translation)
                if newHighlight != highlighted {
                    highlighted = newHighlight
                    if newHighlight != nil { LabHaptics.selection() }
                }
            }
            .onEnded { value in
                if let rating = rating(for: value.predictedEndTranslation) ?? rating(for: value.translation) {
                    commit(rating)
                } else {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        drag = .zero
                        highlighted = nil
                    }
                }
            }
    }

    private func rating(for translation: CGSize) -> MomentRating? {
        if translation.height < -82, abs(translation.width) < 105 { return .love }
        if translation.width > 72 { return .save }
        if translation.width < -72 { return .pass }
        return nil
    }

    private func momentButton(
        _ title: String,
        symbol: String,
        rating: MomentRating,
        color: Color
    ) -> some View {
        Button { commit(rating) } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func commit(_ rating: MomentRating) {
        guard !isCommitting else { return }
        isCommitting = true
        highlighted = rating
        LabHaptics.commit()

        let exit: CGSize = switch rating {
        case .pass: CGSize(width: -520, height: -20)
        case .save: CGSize(width: 520, height: -20)
        case .love: CGSize(width: 0, height: -720)
        }

        withAnimation(reduceMotion ? .linear(duration: 0.08) : .spring(response: 0.42, dampingFraction: 0.76)) {
            drag = exit
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.08 : 0.23)) {
            ratings[currentMoment.id] = rating
            history.append(currentMoment.id)
            currentIndex += 1
            drag = .zero
            highlighted = nil
            isCommitting = false
        }
    }

    private func undo() {
        guard !isCommitting else { return }
        guard currentIndex > 0, let id = history.popLast() else { return }
        currentIndex -= 1
        ratings.removeValue(forKey: id)
        drag = .zero
        highlighted = nil
    }

    private var computedAnswers: [Int: Int] {
        Dictionary(uniqueKeysWithValues: LabContent.questions.map { question in
            let moments = LabMoments.all.filter { $0.questionID == question.id }
            let left = moments.first(where: { $0.poleValue < 0 }).flatMap { ratings[$0.id]?.rawValue } ?? 0
            let right = moments.first(where: { $0.poleValue > 0 }).flatMap { ratings[$0.id]?.rawValue } ?? 0
            return (question.id, max(-2, min(2, right - left)))
        })
    }

    private func reset() {
        currentIndex = 0
        ratings = [:]
        history = []
        drag = .zero
        highlighted = nil
        isCommitting = false
    }
}

private struct MomentCard: View {
    let moment: LabMoment
    let highlighted: MomentRating?

    var body: some View {
        ZStack {
            LinearGradient(colors: moment.colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            ForEach(0..<9, id: \.self) { index in
                Circle()
                    .stroke(.white.opacity(0.09), lineWidth: 1)
                    .frame(width: CGFloat(80 + index * 44), height: CGFloat(80 + index * 44))
                    .offset(x: CGFloat(index * 9 - 34), y: CGFloat(index * -8 + 16))
            }

            VStack(spacing: 20) {
                Text("A TRAVEL MOMENT")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.72))

                Spacer()

                Image(systemName: moment.symbol)
                    .font(.system(size: 54, weight: .light))
                    .foregroundStyle(.white.opacity(0.88))

                Text(moment.text)
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                HStack {
                    Label("Pass", systemImage: "arrow.left")
                    Spacer()
                    Label("Absolutely", systemImage: "arrow.up")
                    Spacer()
                    Label("Save", systemImage: "arrow.right")
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))
            }
            .padding(24)

            if let highlighted {
                ratingOverlay(highlighted)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 445)
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.60), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.17), radius: 20, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(moment.text)
        .accessibilityHint("Swipe left to pass, right to save, or up to love.")
    }

    @ViewBuilder
    private func ratingOverlay(_ rating: MomentRating) -> some View {
        let label: String = switch rating {
        case .pass: "PASS"
        case .save: "SAVE"
        case .love: "ABSOLUTELY"
        }
        let symbol: String = switch rating {
        case .pass: "xmark"
        case .save: "heart.fill"
        case .love: "sparkles"
        }

        VStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 29, weight: .bold))
            Text(label)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(1)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: 4 — Free spirit: The Forking Journey

struct ForkingJourneyPrototype: View {
    @StateObject private var session = QuestionnaireLabSession()
    @State private var draft: Int?

    var body: some View {
        Group {
            if session.isComplete {
                LabCompletionView(
                    concept: "Forking Journey",
                    message: "Each answer became a bend in one continuous route through your travel preferences.",
                    answers: session.answers,
                    onReset: {
                        draft = nil
                        session.reset()
                    }
                )
            } else if let question = session.currentQuestion {
                ZStack {
                    LabBackdrop(accent: question.left.colors[0])

                    ScrollView {
                        VStack(spacing: 13) {
                            LabHeader(
                                eyebrow: "04 · Free spirit",
                                title: "Take an imaginary trip",
                                subtitle: "At every fork, guide the compass toward the path that feels more like you.",
                                completed: session.currentIndex,
                                total: LabContent.questions.count,
                                onUndo: session.currentIndex > 0 ? { undo() } : nil
                            )
                            .padding(.horizontal, 20)

                            JourneyMap(
                                answers: session.answers,
                                currentQuestionID: question.id,
                                draft: draft
                            )
                            .frame(height: 205)
                            .padding(.horizontal, 20)

                            ForkChoiceCard(question: question, value: $draft)
                                .padding(.horizontal, 20)

                            Button(action: takePath) {
                                Label(draft == nil ? "Choose a path" : "Take this path", systemImage: "location.fill")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.appTint)
                            .disabled(draft == nil)
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 12)
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .navigationTitle("Concept 4")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func takePath() {
        guard let draft else { return }
        LabHaptics.commit()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            session.record(draft)
            self.draft = nil
        }
    }

    private func undo() {
        session.undo()
        draft = nil
    }
}

private struct JourneyMap: View {
    let answers: [Int: Int]
    let currentQuestionID: Int
    let draft: Int?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.white.opacity(0.62))

                Canvas { context, size in
                    var route = Path()
                    let values = routeValues

                    for index in values.indices {
                        let point = routePoint(index: index, value: values[index], size: size)
                        if index == 0 {
                            route.move(to: point)
                        } else {
                            route.addLine(to: point)
                        }
                    }

                    context.stroke(
                        route,
                        with: .color(Color.appTint.opacity(0.72)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [2, 8])
                    )

                    for index in values.indices {
                        let point = routePoint(index: index, value: values[index], size: size)
                        let rect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
                        context.fill(Path(ellipseIn: rect), with: .color(index == values.count - 1 ? Color.appTint : .white))
                        context.stroke(Path(ellipseIn: rect), with: .color(Color.appTint), lineWidth: 2)
                    }
                }

                VStack {
                    HStack {
                        Label("YOUR ROUTE", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(Color.appTint)
                        Spacer()
                        Text("\(answers.count) stops")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(15)

                Image(systemName: "location.north.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.appTint)
                    .rotationEffect(.degrees(18))
                    .position(compassPoint(in: proxy.size))
                    .animation(.spring(response: 0.35, dampingFraction: 0.72), value: draft)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(.white.opacity(0.9), lineWidth: 1)
            }
        }
    }

    private var routeValues: [Int] {
        var values = [0]
        for question in LabContent.questions where question.id < currentQuestionID {
            values.append(answers[question.id] ?? 0)
        }
        values.append(draft ?? 0)
        return values
    }

    private func compassPoint(in size: CGSize) -> CGPoint {
        routePoint(index: routeValues.count - 1, value: routeValues.last ?? 0, size: size)
    }

    private func routePoint(index: Int, value: Int, size: CGSize) -> CGPoint {
        let count = max(routeValues.count, 2)
        let x = size.width / 2 + CGFloat(value) / 2 * size.width * 0.32
        let y = 48 + CGFloat(index) * max(18, (size.height - 72) / CGFloat(count - 1))
        return CGPoint(x: x, y: min(size.height - 20, y))
    }
}

private struct ForkChoiceCard: View {
    let question: LabQuestion
    @Binding var value: Int?

    var body: some View {
        VStack(spacing: 11) {
            VStack(spacing: 3) {
                Text("FORK \(question.id)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1)
                    .foregroundStyle(Color.appTint)
                Text(question.prompt)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                branch(pole: question.left, isSelected: (value ?? 0) < 0)
                branch(pole: question.right, isSelected: (value ?? 0) > 0)
            }

            FiveStopSelector(question: question, value: $value, compact: true)
        }
        .padding(14)
        .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.9), lineWidth: 1)
        }
    }

    private func branch(pole: LabPole, isSelected: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: pole.symbol)
                .font(.system(size: 21, weight: .semibold))
            Text(pole.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(pole.description)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 98)
        .background(
            isSelected ? pole.colors[0].opacity(0.14) : Color.black.opacity(0.025),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .foregroundStyle(isSelected ? pole.colors[0] : .primary)
        .onTapGesture {
            value = pole.title == question.left.title ? -2 : 2
            LabHaptics.selection()
        }
    }
}

// MARK: 5 — Free spirit: The Vibe Mixer

struct VibeMixerPrototype: View {
    @State private var panel = 0
    @State private var answers: [Int: Int] = [:]
    @State private var showResult = false

    private var panelQuestions: ArraySlice<LabQuestion> {
        let start = panel * 2
        return LabContent.questions[start..<min(start + 2, LabContent.questions.count)]
    }

    var body: some View {
        Group {
            if showResult {
                LabCompletionView(
                    concept: "Vibe Mixer",
                    message: "Two channels at a time became a living, editable travel identity instead of a questionnaire.",
                    answers: answers,
                    onReset: reset
                )
            } else {
                ZStack {
                    LabBackdrop(accent: activeAccent)

                    ScrollView {
                        VStack(spacing: 14) {
                            LabHeader(
                                eyebrow: "05 · Free spirit",
                                title: "Mix your trip",
                                subtitle: "Set two channels, watch the travel poster react, then move to the next pair.",
                                completed: panel,
                                total: 4,
                                onUndo: panel > 0 ? { previousPanel() } : nil,
                                undoLabel: "Previous"
                            )

                            MixerVisual(
                                panel: panel,
                                firstValue: value(forOffset: 0),
                                secondValue: value(forOffset: 1)
                            )
                            .frame(height: 245)

                            VStack(spacing: 17) {
                                ForEach(Array(panelQuestions.enumerated()), id: \.element.id) { _, question in
                                    MixerChannel(
                                        question: question,
                                        value: binding(for: question.id)
                                    )
                                }
                            }
                            .padding(16)
                            .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(.white.opacity(0.9), lineWidth: 1)
                            }

                            Button(action: nextPanel) {
                                Label(
                                    panel == 3 ? "Play my trip" : "Next mix",
                                    systemImage: panel == 3 ? "play.fill" : "arrow.right"
                                )
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity, minHeight: 52)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.appTint)
                            .disabled(!panelIsSet)

                            Text("Every channel begins unset—even though its ghost thumb sits in the middle.")
                                .font(.system(size: 11, design: .rounded))
                                .foregroundStyle(.tertiary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle("Concept 5")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.28), value: panel)
    }

    private var activeAccent: Color {
        panelQuestions.last?.right.colors[0] ?? Color.appTint
    }

    private var panelIsSet: Bool {
        panelQuestions.allSatisfy { answers[$0.id] != nil }
    }

    private func value(forOffset offset: Int) -> Int? {
        let id = panel * 2 + offset + 1
        return answers[id]
    }

    private func binding(for questionID: Int) -> Binding<Int?> {
        Binding(
            get: { answers[questionID] },
            set: { newValue in
                if let newValue {
                    answers[questionID] = newValue
                } else {
                    answers.removeValue(forKey: questionID)
                }
            }
        )
    }

    private func nextPanel() {
        guard panelIsSet else { return }
        LabHaptics.commit()
        if panel < 3 {
            panel += 1
        } else {
            showResult = true
        }
    }

    private func previousPanel() {
        guard panel > 0 else { return }
        panel -= 1
    }

    private func reset() {
        panel = 0
        answers = [:]
        showResult = false
    }
}

private struct MixerChannel: View {
    let question: LabQuestion
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(question.dimension, systemImage: question.left.symbol)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Spacer()
                if value == nil {
                    Text("UNSET")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(Color.orange)
                } else {
                    AnswerDots(value: value ?? 0, compact: true)
                }
            }

            FiveStopSelector(question: question, value: $value, compact: true)
        }
    }
}

private struct MixerVisual: View {
    let panel: Int
    let firstValue: Int?
    let secondValue: Int?

    var body: some View {
        GeometryReader { _ in
            ZStack {
                backgroundLayer
                orbLayer
                waveLayer
                captionLayer
            }
            .shadow(color: palette[0].opacity(0.24), radius: 18, y: 9)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: firstValue)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: secondValue)
        .accessibilityHidden(true)
    }

    private var backgroundLayer: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(
                LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            )
    }

    private var orbLayer: some View {
        ForEach(0..<10, id: \.self) { index in
            orb(index: index)
        }
    }

    private func orb(index: Int) -> some View {
        let firstValue = firstValue ?? 0
        let secondValue = secondValue ?? 0
        let phase = Double(index) / 10
        let diameter = CGFloat(32 + index * 9 + abs(firstValue) * 5)
        let offsetX = CGFloat((index % 3) * 74 - 72 + firstValue * 8)
        let wobble = secondValue * (index.isMultiple(of: 2) ? 6 : -6)
        let offsetY = CGFloat((index % 4) * 48 - 70 + wobble)
        return Circle()
            .fill(.white.opacity(0.08 + phase * 0.06))
            .frame(width: diameter, height: diameter)
            .offset(x: offsetX, y: offsetY)
            .rotationEffect(.degrees(Double(secondValue * index * 2)))
    }

    private var waveLayer: some View {
        Canvas { context, size in
            let secondValue = secondValue ?? 0
            var path = Path()
            let amplitude = CGFloat(22 + abs(secondValue) * 12)
            let baseline = size.height * 0.58
            path.move(to: CGPoint(x: 0, y: baseline))
            for step in 0...20 {
                let x = size.width * CGFloat(step) / 20
                let wave = sin(CGFloat(step) * 0.7 + CGFloat(panel)) * amplitude
                path.addLine(to: CGPoint(x: x, y: baseline + wave))
            }
            context.stroke(
                path,
                with: .color(.white.opacity(0.55)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var captionLayer: some View {
        VStack {
            HStack {
                Text("LIVE TRAVEL MIX")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(1.2)
                Spacer()
                Image(systemName: panelSymbol)
                    .font(.system(size: 22, weight: .bold))
            }
            Spacer()
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(panelTitle)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Move a channel and the composition changes.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: panelSymbol)
                    .font(.system(size: 58, weight: .ultraLight))
                    .opacity(0.45)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
    }

    private var palette: [Color] {
        let questions = Array(LabContent.questions[(panel * 2)..<min(panel * 2 + 2, LabContent.questions.count)])
        guard questions.count == 2 else { return [Color.appTint, .orange] }
        let first = visualColor(for: questions[0], value: firstValue)
        let second = visualColor(for: questions[1], value: secondValue)
        return [first, second]
    }

    private func visualColor(for question: LabQuestion, value: Int?) -> Color {
        guard let value else { return Color(hex: "#7B849A") }
        if value < 0 { return question.left.colors[0] }
        if value > 0 { return question.right.colors[0] }
        return midpoint(question.left.colors[0], question.right.colors[0])
    }

    private func midpoint(_ first: Color, _ second: Color) -> Color {
        var firstRed: CGFloat = 0
        var firstGreen: CGFloat = 0
        var firstBlue: CGFloat = 0
        var firstAlpha: CGFloat = 0
        var secondRed: CGFloat = 0
        var secondGreen: CGFloat = 0
        var secondBlue: CGFloat = 0
        var secondAlpha: CGFloat = 0

        guard UIColor(first).getRed(&firstRed, green: &firstGreen, blue: &firstBlue, alpha: &firstAlpha),
              UIColor(second).getRed(&secondRed, green: &secondGreen, blue: &secondBlue, alpha: &secondAlpha) else {
            return Color.appTint
        }

        return Color(
            red: Double((firstRed + secondRed) / 2),
            green: Double((firstGreen + secondGreen) / 2),
            blue: Double((firstBlue + secondBlue) / 2),
            opacity: Double((firstAlpha + secondAlpha) / 2)
        )
    }

    private var panelTitle: String {
        ["Set the scene", "Shape the day", "Choose the texture", "Finish the signature"][panel]
    }

    private var panelSymbol: String {
        ["mountain.2.fill", "figure.hiking", "fork.knife", "sparkles"][panel]
    }
}

#endif
