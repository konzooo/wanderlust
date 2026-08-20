import CoreArchitecture
import CoreModels
import DesignSystem
import Foundation
import SwiftUI

enum ProfilePreferenceKey {
    static let introductionDismissed = "profiles.introduction.dismissed"
}

// MARK: - Local profile library

@MainActor
final class TravellerProfileLibrary: ObservableObject {
    static let shared = TravellerProfileLibrary()

    @Published private(set) var profiles: [TravellerProfile] = []
    @Published private(set) var mainProfileID: UUID?
    @Published private(set) var attachByDefault = false

    private struct PersistedLibrary: Codable {
        var profiles: [TravellerProfile]
        var mainProfileID: UUID?
        var attachByDefault: Bool
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let base = (try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )) ?? FileManager.default.temporaryDirectory
            let folder = base.appendingPathComponent("TravellerProfiles", isDirectory: true)
            try? FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
            )
            self.fileURL = folder.appendingPathComponent("profiles.json")
        }
        load()
        syncAnalyticsState()
    }

    var mainProfile: TravellerProfile? {
        profile(id: mainProfileID)
    }

    var defaultSelectionID: UUID? {
        attachByDefault ? mainProfileID : nil
    }

    func profile(id: UUID?) -> TravellerProfile? {
        guard let id else { return nil }
        return profiles.first(where: { $0.id == id })
    }

    func save(
        _ profile: TravellerProfile,
        analyticsEntryPoint: String = "profile_management"
    ) throws {
        let cleaned = try normalized(profile)
        let isFirst = profiles.isEmpty
        let wasExisting = profiles.contains(where: { $0.id == cleaned.id })
        if let index = profiles.firstIndex(where: { $0.id == cleaned.id }) {
            profiles[index] = cleaned
        } else {
            profiles.append(cleaned)
        }
        if isFirst {
            mainProfileID = cleaned.id
            attachByDefault = true
        }
        try persist()
        var properties = cleaned.analyticsProperties
        properties["entry_point"] = .string(analyticsEntryPoint)
        properties["operation"] = .string(wasExisting ? "edit" : "create")
        properties["profile_count"] = .integer(profiles.count)
        AnalyticsTracker.shared.log(
            .init(.travellerProfileSaved, properties: properties)
        )
        syncAnalyticsState()
    }

    func delete(_ id: UUID) {
        let deleted = profiles.first(where: { $0.id == id })
        profiles.removeAll(where: { $0.id == id })
        if mainProfileID == id {
            mainProfileID = profiles.first?.id
        }
        if profiles.isEmpty {
            attachByDefault = false
        }
        try? persist()
        if let deleted {
            var properties = deleted.analyticsProperties
            properties["profile_count"] = .integer(profiles.count)
            AnalyticsTracker.shared.log(
                .init(.travellerProfileDeleted, properties: properties)
            )
        }
        syncAnalyticsState()
    }

    func makeMain(_ id: UUID) {
        guard profile(id: id) != nil else { return }
        mainProfileID = id
        try? persist()
        syncAnalyticsState()
    }

    func setAttachByDefault(_ value: Bool) {
        attachByDefault = value && mainProfileID != nil
        try? persist()
        syncAnalyticsState()
    }

    func syncAnalyticsState() {
        AnalyticsTracker.shared.setUserProperties([
            "has_profile": .boolean(!profiles.isEmpty),
            "profile_count": .integer(profiles.count),
            "attach_profile_by_default": .boolean(attachByDefault)
        ])
    }

    func analyticsAttachmentSource(for profileID: UUID?) -> String {
        guard let profileID else { return "none" }
        return attachByDefault && profileID == mainProfileID ? "default" : "manual"
    }

#if DEBUG
    func resetForUITesting() {
        profiles = []
        mainProfileID = nil
        attachByDefault = false
        try? FileManager.default.removeItem(at: fileURL)
    }
#endif

    func nameIsAvailable(_ rawName: String, excluding profileID: UUID? = nil) -> Bool {
        let candidate = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty, candidate.count <= 40 else { return false }
        return !profiles.contains {
            $0.id != profileID &&
            $0.name.compare(candidate, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    private func normalized(_ profile: TravellerProfile) throws -> TravellerProfile {
        let name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nameIsAvailable(name, excluding: profile.id) else {
            throw ProfileLibraryError.invalidOrDuplicateName
        }
        guard profile.snapshot.hasEveryScaleAnswer else {
            throw ProfileLibraryError.incompleteAnswers
        }

        var copy = profile
        copy.name = String(name.prefix(40))
        copy.usuallySkip = normalizeEntries(profile.usuallySkip)
        copy.mustHaves = normalizeEntries(profile.mustHaves)
        let notes = profile.additionalNotes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(500)
        copy.additionalNotes = notes.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
        copy.passport = profile.passport.flatMap { code in
            Country.all.contains(where: { $0.code == code }) ? code : nil
        }
        copy.updatedAt = Date()
        return copy
    }

    private func normalizeEntries(_ entries: [String]) -> [String] {
        Array(entries.prefix(5)).compactMap {
            let value = String(
                $0.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100)
            )
            return value.isEmpty ? nil : value
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(PersistedLibrary.self, from: data) else {
            return
        }
        profiles = decoded.profiles
        if let id = decoded.mainProfileID,
           decoded.profiles.contains(where: { $0.id == id }) {
            mainProfileID = id
        } else {
            mainProfileID = decoded.profiles.first?.id
        }
        attachByDefault = decoded.attachByDefault && mainProfileID != nil
    }

    private func persist() throws {
        let state = PersistedLibrary(
            profiles: profiles,
            mainProfileID: mainProfileID,
            attachByDefault: attachByDefault
        )
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}

enum ProfileLibraryError: LocalizedError {
    case invalidOrDuplicateName
    case incompleteAnswers

    var errorDescription: String? {
        switch self {
        case .invalidOrDuplicateName:
            "Use a unique profile name between 1 and 40 characters."
        case .incompleteAnswers:
            "Please answer all five Traveller DNA scales."
        }
    }
}

// MARK: - DNA blob

struct TravellerDNABlob: View {
    let answers: [ProfileScaleAnswer]
    var compact = false
    var animated = true
    var expressionText = ""
    var progress: Double? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var scores: [Double] {
        TravellerDNADimension.allCases.map { dimension in
            Double(answers.first(where: { $0.dimension == dimension })?.value ?? 3)
        }
    }

    private var expression: Double {
        guard !expressionText.isEmpty else { return 0.37 }
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in expressionText.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Double(hash % 10_000) / 9_999
    }

    private var shapeParameters: DNABlobParameters {
        DNABlobParameters(scores + [expression, min(max(progress ?? 1, 0), 1)])
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: (animated && !reduceMotion) ? 1 / 24 : 1,
            paused: !animated || reduceMotion
        )) { timeline in
            let phase = (animated && !reduceMotion)
                ? timeline.date.timeIntervalSinceReferenceDate
                : 0

            ZStack {
                if !compact {
                    Circle()
                        .stroke(Color.secondary.opacity(0.20), lineWidth: 9)
                        .padding(5)

                    if let progress {
                        Circle()
                            .trim(from: 0, to: min(max(progress, 0), 1))
                            .stroke(
                                Color.appTint,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(5)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.78),
                                value: progress
                            )
                    }
                }

                DNAOrganicShape(parameters: shapeParameters, phase: phase)
                    .fill(
                        AngularGradient(
                            colors: [
                                Color(hex: "#744FF3"),
                                Color(hex: "#B460EF"),
                                Color(hex: "#E27FAD"),
                                Color(hex: "#5F87EA"),
                                Color(hex: "#744FF3")
                            ],
                            center: .center
                        )
                    )
                    .overlay {
                        DNAOrganicShape(parameters: shapeParameters, phase: phase)
                            .fill(
                                RadialGradient(
                                    colors: [
                                        .white.opacity(compact ? 0.26 : 0.58),
                                        Color(hex: "#7B68EE").opacity(0.22),
                                        .clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: compact ? 26 : 96
                                )
                            )
                    }
                    .overlay {
                        DNAOrganicShape(parameters: shapeParameters, phase: phase)
                            .stroke(.white.opacity(0.32), lineWidth: compact ? 0.8 : 1.5)
                    }
                    .padding(compact ? 1 : 17)
                    .shadow(
                        color: Color.appTint.opacity(compact ? 0.22 : 0.42),
                        radius: compact ? 4 : 19,
                        y: compact ? 1 : 5
                    )
            }
            .animation(
                reduceMotion ? nil : .spring(response: 0.72, dampingFraction: 0.72),
                value: shapeParameters
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private struct DNABlobParameters: VectorArithmetic, Equatable {
    var values: [Double]

    init(_ values: [Double]) {
        self.values = values
    }

    static var zero: Self { Self(Array(repeating: 0, count: 7)) }

    static func + (lhs: Self, rhs: Self) -> Self {
        let count = max(lhs.values.count, rhs.values.count)
        return Self((0..<count).map { index in
            lhs.value(at: index) + rhs.value(at: index)
        })
    }

    static func - (lhs: Self, rhs: Self) -> Self {
        let count = max(lhs.values.count, rhs.values.count)
        return Self((0..<count).map { index in
            lhs.value(at: index) - rhs.value(at: index)
        })
    }

    mutating func scale(by rhs: Double) {
        values = values.map { $0 * rhs }
    }

    var magnitudeSquared: Double {
        values.reduce(0) { $0 + $1 * $1 }
    }

    func value(at index: Int, fallback: Double = 0) -> Double {
        values.indices.contains(index) ? values[index] : fallback
    }
}

private struct DNAOrganicShape: Shape {
    var parameters: DNABlobParameters
    let phase: Double

    var animatableData: DNABlobParameters {
        get { parameters }
        set { parameters = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let count = 14
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.37
        let expression = parameters.value(at: 5, fallback: 0.37)
        let formation = parameters.value(at: 6, fallback: 1)
        let baseline: [CGFloat] = [
            1.16, 0.78, 1.08, 0.73, 1.19, 0.82, 1.05,
            0.76, 1.17, 0.81, 1.10, 0.74, 1.20, 0.84
        ]

        var points: [CGPoint] = []
        points.reserveCapacity(count)
        for index in 0..<count {
            let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / CGFloat(count)
            var tendencyInfluence: CGFloat = 0
            for dimension in 0..<5 {
                let score = parameters.value(at: dimension, fallback: 3)
                let tendency = CGFloat((score - 3) / 2)
                let axis = -CGFloat.pi / 2 + CGFloat(dimension) * 2 * .pi / 5
                tendencyInfluence += tendency * cos(angle - axis) * 0.105
            }

            let expressionPhase = expression * 19.7 + Double(index) * 2.31
            let expressionStrength = 0.035 + CGFloat(formation) * 0.075
            let personalizedRipple = CGFloat(sin(expressionPhase)) * expressionStrength
            let breathingSpeed = 1.32 + Double(index % 4) * 0.15
            let breathingPhase = phase * breathingSpeed + Double(index) * 1.43
            let breath = CGFloat(sin(breathingPhase)) * 0.052
            let pulsePhase = phase * 0.96 + Double(index) * 0.87
            let lobePulse = CGFloat(cos(pulsePhase)) * 0.030
            let radiusScale = baseline[index]
                + tendencyInfluence
                + personalizedRipple
                + breath
                + lobePulse
            let clampedRadiusScale = max(CGFloat(0.54), min(radiusScale, CGFloat(1.42)))
            let radius = baseRadius * clampedRadiusScale
            let driftPhase = phase * 0.82 + Double(index) * 1.11
            let angleDrift = CGFloat(sin(driftPhase)) * 0.026
            let point = CGPoint(
                x: center.x + cos(angle + angleDrift) * radius,
                y: center.y + sin(angle + angleDrift) * radius
            )
            points.append(point)
        }

        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: midpoint(points[count - 1], first))
        for index in 0..<count {
            let current = points[index]
            let next = points[(index + 1) % count]
            path.addQuadCurve(to: midpoint(current, next), control: current)
        }
        path.closeSubpath()
        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}

private extension TravellerProfile {
    var dnaExpressionText: String {
        ([name] + usuallySkip + mustHaves + [additionalNotes ?? ""]).joined(separator: "|")
    }
}

// MARK: - Quick trip selector

struct ProfileSelectionButton: View {
    @Binding var selection: UUID?
    let entryPoint: String
    @EnvironmentObject private var router: NavigationRouter
    @ObservedObject private var library = TravellerProfileLibrary.shared
    @AppStorage(ProfilePreferenceKey.introductionDismissed) private var onboardingDismissed = false
    @State private var profilesPresented = false
    @State private var startCreating = false
    @State private var pickerPresented = false
    @State private var introPresented = false
    @State private var editorPresented = false
    // "Maybe later" is a deferral, not a decision, so nothing persists to
    // `onboardingDismissed` — but re-showing the popup on every single tap
    // of this same visit reads as broken, not patient. Suppress it until the
    // traveller leaves and returns to this tab.
    @State private var introSuppressedForTab = false

    init(selection: Binding<UUID?>, entryPoint: String = "profile_management") {
        _selection = selection
        self.entryPoint = entryPoint
    }

    var body: some View {
        Button {
            if library.profiles.isEmpty, !onboardingDismissed, !introSuppressedForTab {
                introPresented = true
            } else {
                pickerPresented = true
            }
        } label: {
            Group {
                if let selected = library.profile(id: selection) {
                    TravellerDNABlob(
                        answers: selected.scaleAnswers,
                        compact: true,
                        animated: false,
                        expressionText: selected.dnaExpressionText
                    )
                } else {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.black.opacity(0.62))
                }
            }
            .frame(width: 28, height: 28)
            .frame(width: 42, height: 42)
            .background(.white.opacity(0.88), in: Circle())
            .overlay {
                Circle()
                    .stroke(Color.black.opacity(0.11), lineWidth: 1)
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .buttonBorderShape(.circle)
        .accessibilityLabel(selectedAccessibilityLabel)
        .accessibilityIdentifier("profile-selection-button")
        .popover(isPresented: $pickerPresented, arrowEdge: .top) {
            VStack(spacing: 0) {
                quickPickerRow(
                    title: "No profile",
                    profile: nil,
                    isMain: false,
                    isSelected: selection == nil
                ) {
                    selection = nil
                    AnalyticsTracker.shared.log(
                        .init(.travellerProfileSelected, properties: [
                            "selection": .string("none"),
                            "profile_count": .integer(library.profiles.count),
                            "entry_point": .string(entryPoint)
                        ])
                    )
                    pickerPresented = false
                }

                if !library.profiles.isEmpty {
                    Divider().padding(.horizontal, 12)
                    ForEach(orderedProfiles) { profile in
                        quickPickerRow(
                            title: profile.name,
                            profile: profile,
                            isMain: profile.id == library.mainProfileID,
                            isSelected: selection == profile.id
                        ) {
                            selection = profile.id
                            AnalyticsTracker.shared.log(
                                .init(.travellerProfileSelected, properties: [
                                    "selection": .string("profile"),
                                    "profile_count": .integer(library.profiles.count),
                                    "entry_point": .string(entryPoint)
                                ])
                            )
                            pickerPresented = false
                        }
                    }
                }

                Divider().padding(.horizontal, 12)
                Button {
                    // Lands on the static "Create your Traveller DNA" screen
                    // rather than jumping straight into the name field — the
                    // traveller decides when to actually start the flow.
                    openProfiles(startsCreating: false)
                } label: {
                    Label(
                        library.profiles.isEmpty ? "Create Traveller DNA" : "Manage Profile",
                        systemImage: library.profiles.isEmpty ? "plus" : "slider.horizontal.3"
                    )
                    .font(.kanit(15).weight(.medium))
                    .foregroundStyle(Color.appTint)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 286)
            .presentationCompactAdaptation(.popover)
        }
        .fullScreenCover(isPresented: $profilesPresented) {
            NavigationStack {
                ProfilesScreen(
                    startsCreating: startCreating,
                    analyticsEntryPoint: entryPoint,
                    onProfileCreated: { profile in
                        selection = profile.id
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $introPresented) {
            TravellerDNAIntroScreen(
                onCreate: {
                    onboardingDismissed = true
                    introPresented = false
                    editorPresented = true
                },
                onMaybeLater: {
                    introPresented = false
                    introSuppressedForTab = true
                },
                onDontShowAgain: {
                    onboardingDismissed = true
                    introPresented = false
                }
            )
        }
        .fullScreenCover(isPresented: $editorPresented) {
            TravellerDNAEditorScreen(profile: nil, analyticsEntryPoint: entryPoint) { profile in
                selection = profile.id
            }
        }
        .onChange(of: router.selectedTab) { _, _ in
            introSuppressedForTab = false
        }
        .onChange(of: library.profiles) { _, profiles in
            if let selection, !profiles.contains(where: { $0.id == selection }) {
                self.selection = nil
            }
        }
    }

    private func quickPickerRow(
        title: String,
        profile: TravellerProfile?,
        isMain: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                if let profile {
                    TravellerDNABlob(
                        answers: profile.scaleAnswers,
                        compact: true,
                        animated: false,
                        expressionText: profile.dnaExpressionText
                    )
                        .frame(width: 34, height: 34)
                } else {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                }
                Text(title)
                    .font(.kanit(15))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if isMain {
                    Text("Main")
                        .font(.kanit(9))
                        .foregroundStyle(Color.appTint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.appTint.opacity(0.12), in: Capsule())
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.appTint)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func openProfiles(startsCreating: Bool) {
        pickerPresented = false
        startCreating = startsCreating
        Task { @MainActor in
            await Task.yield()
            profilesPresented = true
        }
    }

    private var orderedProfiles: [TravellerProfile] {
        library.profiles.sorted {
            if $0.id == library.mainProfileID { return true }
            if $1.id == library.mainProfileID { return false }
            return $0.createdAt < $1.createdAt
        }
    }

    private var selectedAccessibilityLabel: String {
        library.profile(id: selection).map { "Traveller profile: \($0.name)" }
            ?? "No Traveller profile selected"
    }
}

// MARK: - Profile management

/// What the editor cover is opened for.
///
/// This is one `Identifiable` value rather than a `Bool` plus a separate
/// profile: driving `fullScreenCover(isPresented:)` from two pieces of state
/// let the cover read a stale profile, so "Recalibrate" opened a blank
/// editor. With `fullScreenCover(item:)` the profile is part of what is
/// presented and cannot lag behind it.
private enum EditorTarget: Identifiable {
    case create
    case edit(TravellerProfile)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let profile): profile.id.uuidString
        }
    }

    var profile: TravellerProfile? {
        switch self {
        case .create: nil
        case .edit(let profile): profile
        }
    }
}

struct ProfilesScreen: View {
    var startsCreating = false
    var analyticsEntryPoint = "profile_management"
    var onProfileCreated: ((TravellerProfile) -> Void)?
    var navigationTitle = "Profiles"
    var showsDoneButton = true
    var showsInfoButton = true
    var automaticallyPresentsOnboarding = true
    var logsScreenViewOnAppear = true

    @ObservedObject private var library = TravellerProfileLibrary.shared
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ProfilePreferenceKey.introductionDismissed) private var onboardingDismissed = false
    @State private var editorTarget: EditorTarget?
    @State private var onboardingPresented = false
    @State private var onboardingStartsEditor = false
    @State private var dismissAfterOnboarding = false
    @State private var deleteCandidate: TravellerProfile?
    @State private var showInfo = false
    @State private var didHandleInitialAction = false

    var body: some View {
        ZStack {
            AuroraBackground()
            ScrollView {
                if let profile = library.mainProfile {
                    profileContent(profile)
                } else {
                    emptyState
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            if showsInfoButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showInfo = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("About Traveller DNA")
                }
            }
        }
        .onAppear {
            if logsScreenViewOnAppear {
                AnalyticsTracker.shared.log(
                    .screenViewed(.profileManagement, entryPoint: analyticsEntryPoint)
                )
            }
            guard !didHandleInitialAction else { return }
            didHandleInitialAction = true
            if automaticallyPresentsOnboarding,
               library.profiles.isEmpty,
               !onboardingDismissed {
                onboardingPresented = true
            } else if startsCreating {
                editorTarget = .create
            }
        }
        .fullScreenCover(
            isPresented: $onboardingPresented,
            onDismiss: {
                onboardingStartsEditor = false
                if dismissAfterOnboarding {
                    dismissAfterOnboarding = false
                    dismiss()
                }
            }
        ) {
            if onboardingStartsEditor {
                TravellerDNAEditorScreen(
                    profile: nil,
                    analyticsEntryPoint: analyticsEntryPoint
                ) { saved in
                    onProfileCreated?(saved)
                }
            } else {
                TravellerDNAIntroScreen(
                    onCreate: {
                        onboardingDismissed = true
                        onboardingStartsEditor = true
                    },
                    onMaybeLater: {
                        dismissAfterOnboarding = startsCreating
                        onboardingPresented = false
                    },
                    onDontShowAgain: {
                        onboardingDismissed = true
                        onboardingPresented = false
                    }
                )
            }
        }
        .fullScreenCover(item: $editorTarget) { target in
            TravellerDNAEditorScreen(
                profile: target.profile,
                analyticsEntryPoint: analyticsEntryPoint
            ) { saved in
                onProfileCreated?(saved)
            }
        }
        .alert("How profiles work", isPresented: $showInfo) {
            Button("Got it", role: .cancel) {}
        } message: {
            Text("A profile stores your lasting travel preferences. When attached, it adds your Traveller DNA to this trip. You can always choose No profile, and your trip-specific answers take priority.")
        }
        .alert(
            "Delete \(deleteCandidate?.name ?? "profile")?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            )
        ) {
            Button("Delete", role: .destructive) {
                guard let id = deleteCandidate?.id else { return }
                library.delete(id)
                deleteCandidate = nil
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            if deleteCandidate?.id == library.mainProfileID, library.profiles.count > 1 {
                Text("The next profile will become Main.")
            } else {
                Text("This cannot be undone.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 54))
                .foregroundStyle(Color.appTint)
            Text("Create your Traveller DNA")
                .font(DS.Typography.displayRegular)
            Text("Save the preferences that stay with you across trips. You can always travel without a profile.")
                .font(DS.Typography.subtitle)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Create Traveller DNA") {
                editorTarget = .create
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        }
        .padding(24)
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func profileContent(_ profile: TravellerProfile) -> some View {
        VStack(spacing: 18) {
            VStack(spacing: 10) {
                TravellerDNABlob(
                    answers: profile.scaleAnswers,
                    expressionText: profile.dnaExpressionText
                )
                    .frame(width: 250, height: 250)

                HStack(spacing: 7) {
                    Text(profile.name)
                        .font(DS.Typography.displayRegular)
                    if profile.id == library.mainProfileID {
                        Text("MAIN")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.appTint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.appTint.opacity(0.12), in: Capsule())
                    }
                }

                Text(profile.archetype)
                    .font(DS.Typography.subtitle)
                    .foregroundStyle(.secondary)

                Button {
                    editorTarget = .edit(profile)
                } label: {
                    Label("Recalibrate DNA", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.appTint)
            }
            .padding(.top, 20)

            DS.GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(
                        "Attach Main profile to new trips",
                        isOn: Binding(
                            get: { library.attachByDefault },
                            set: { library.setAttachByDefault($0) }
                        )
                    )
                    .tint(Color.appTint)
                    Text("This controls only the starting selection. You can remove or switch profiles on every trip.")
                        .font(.kanit(12))
                        .foregroundStyle(.secondary)
                }
            }

            if !library.profiles.filter({ $0.id != profile.id }).isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Other profiles")
                        .font(DS.Typography.fieldLabel)
                    ForEach(library.profiles.filter { $0.id != profile.id }) { other in
                        profileRow(other)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                editorTarget = .create
            } label: {
                Label("Add another profile", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(Color.appTint)

            Menu {
                if profile.id != library.mainProfileID {
                    Button("Make Main") {
                        library.makeMain(profile.id)
                    }
                }
                Button("Delete Profile", role: .destructive) {
                    deleteCandidate = profile
                }
            } label: {
                Text("Profile options")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 20)
    }

    private func profileRow(_ profile: TravellerProfile) -> some View {
        HStack(spacing: 12) {
            TravellerDNABlob(
                answers: profile.scaleAnswers,
                compact: true,
                animated: false,
                expressionText: profile.dnaExpressionText
            )
                .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.kanit(16))
                    .foregroundStyle(.primary)
                Text(profile.archetype)
                    .font(.kanit(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Menu {
                Button("View and edit") {
                    editorTarget = .edit(profile)
                }
                Button("Make Main") {
                    library.makeMain(profile.id)
                }
                Button("Delete", role: .destructive) {
                    deleteCandidate = profile
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
        }
        .padding(12)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 16))
    }
}

private extension TravellerProfile {
    var analyticsProperties: [String: AnalyticsValue] {
        var properties: [String: AnalyticsValue] = [
            "skip_count": .integer(usuallySkip.count),
            "must_have_count": .integer(mustHaves.count),
            "has_notes": .boolean(
                !(additionalNotes?
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            ),
            "has_age": .boolean(age != nil),
            "has_passport": .boolean(passport != nil)
        ]
        for dimension in TravellerDNADimension.allCases {
            if let score = score(for: dimension) {
                properties["dna_\(dimension.rawValue)"] = .integer(score)
            }
        }
        return properties
    }
}

// MARK: - Eight-step questionnaire

private struct DNAQuestion {
    let dimension: TravellerDNADimension
    let title: String
}

private let dnaQuestions: [DNAQuestion] = [
    .init(dimension: .adviceDetail, title: "How do you like your travel advice?"),
    .init(dimension: .physicalEnergy, title: "How much physical effort feels good on a typical travel day?"),
    .init(dimension: .experienceBreadth, title: "What leaves you more satisfied?"),
    .init(dimension: .dayRhythm, title: "When do you naturally want a travel day to get going?"),
    .init(dimension: .structure, title: "How much structure helps you enjoy a trip?")
]

struct TravellerDNAEditorScreen: View {
    let profile: TravellerProfile?
    let analyticsEntryPoint: String
    let onSave: (TravellerProfile) -> Void

    @ObservedObject private var library = TravellerProfileLibrary.shared
    @Environment(\.dismiss) private var dismiss

    @State private var page = -1
    @State private var name: String
    @State private var scores: [TravellerDNADimension: Int]
    @State private var usuallySkip: [String]
    @State private var mustHaves: [String]
    @State private var additionalNotes: String
    @State private var age: String
    @State private var passport: String?
    @State private var saveError: String?
    @State private var didLogFlowStart = false
    @State private var loggedPages: Set<Int> = []
    @FocusState private var nameFocused: Bool

    init(
        profile: TravellerProfile?,
        analyticsEntryPoint: String = "profile_management",
        onSave: @escaping (TravellerProfile) -> Void
    ) {
        self.profile = profile
        self.analyticsEntryPoint = analyticsEntryPoint
        self.onSave = onSave
        _name = State(initialValue: profile?.name ?? "")
        _scores = State(initialValue: Dictionary(
            uniqueKeysWithValues: (profile?.scaleAnswers ?? []).map { ($0.dimension, $0.value) }
        ))
        _usuallySkip = State(initialValue: profile?.usuallySkip ?? [])
        _mustHaves = State(initialValue: profile?.mustHaves ?? [])
        _additionalNotes = State(initialValue: profile?.additionalNotes ?? "")
        _age = State(initialValue: profile?.age.map(String.init) ?? "")
        _passport = State(initialValue: profile?.passport)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AuroraBackground()
                questionnaire
            }
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if page > -1 {
                            page -= 1
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: page > -1 ? "chevron.left" : "xmark")
                    }
                    .accessibilityLabel(page > -1 ? "Previous step" : "Cancel")
                }
            }
            .task(id: page) {
                logAnalyticsIfNeeded()
                guard page == -1 else {
                    nameFocused = false
                    return
                }
                await Task.yield()
                guard !Task.isCancelled else { return }
                nameFocused = true
            }
        }
    }

    private var questionnaire: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    pageContent
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            footerButton
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
        }
    }

    private var header: some View {
        VStack(spacing: page >= 0 ? 7 : 9) {
            if page >= 0 {
                Text("Shape your Traveller DNA")
                    .font(.kanit(26).weight(.semibold))
                Text("Watch it come alive as you choose")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
            }

            TravellerDNABlob(
                answers: currentAnswers,
                expressionText: blobExpressionText,
                progress: blobProgress
            )
                .frame(
                    width: editorBlobSize,
                    height: editorBlobSize
                )
                .overlay {
                    if page >= 0 {
                        Text("\(completedStepCount) / 8")
                            .font(.kanit(12).weight(.medium))
                            .foregroundStyle(Color.secondary.opacity(0.78))
                    }
                }

            Text(pageTitle)
                .font(page == -1 ? DS.Typography.displayRegular : .kanit(24).weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(page == -1 ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
                .padding(.horizontal, 24)
        }
        .padding(.top, page >= 5 ? 2 : 8)
        .padding(.bottom, page >= 5 ? 10 : 14)
    }

    private var editorBlobSize: CGFloat {
        if page == -1 { return 140 }
        if page >= 5 { return 155 }
        return 200
    }

    @ViewBuilder
    private var pageContent: some View {
        if page == -1 {
            VStack(alignment: .leading, spacing: 10) {
                Text("Who is this profile for?")
                    .font(DS.Typography.fieldLabel)
                TextField("", text: $name)
                    .accessibilityIdentifier("profile-name-field")
                    .textInputAutocapitalization(.words)
                    .focused($nameFocused)
                    .submitLabel(.next)
                    .doubleTapToSelectAll()
                    .padding(14)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                    .onChange(of: name) { _, value in
                        name = String(value.prefix(40))
                    }
                    .onSubmit {
                        guard canContinue else { return }
                        nameFocused = false
                        page = 0
                    }
                PassportAgeRow(passport: $passport, age: $age)
                    .padding(.top, 2)
                Text("You can create additional profiles later.")
                    .font(.kanit(12))
                    .foregroundStyle(.secondary)
            }
        } else if page < 5 {
            scaleQuestion(dnaQuestions[page])
        } else if page == 5 {
            EntryListEditor(
                entries: $usuallySkip,
                placeholder: "e.g. crowded viewpoints",
                helper: "Add up to five. This step is optional."
            )
        } else if page == 6 {
            EntryListEditor(
                entries: $mustHaves,
                placeholder: "e.g. good coffee every morning",
                helper: "Add up to five. This step is optional."
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Optional")
                    .font(DS.Typography.fieldLabel)
                TextEditor(text: $additionalNotes)
                    .frame(minHeight: 170)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
                    .onChange(of: additionalNotes) { _, value in
                        additionalNotes = String(value.prefix(500))
                    }
                Text("\(additionalNotes.count) / 500")
                    .font(.kanit(11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func scaleQuestion(_ question: DNAQuestion) -> some View {
        VStack(spacing: 18) {
            HStack(alignment: .top) {
                Text(question.dimension.leftLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(question.dimension.rightLabel)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
            }
            .font(.kanit(13).weight(.medium))

            Slider(
                value: Binding(
                    get: { Double(scores[question.dimension] ?? 3) },
                    set: { scores[question.dimension] = Int($0.rounded()) }
                ),
                in: 1...5,
                step: 1
            )
            .tint(Color.appTint)
            .opacity(scores[question.dimension] == nil ? 0.62 : 1)
            .accessibilityLabel(question.title)
            .accessibilityValue(scaleAccessibilityValue(question.dimension))

            HStack {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        scores[question.dimension] = value
                    } label: {
                        Circle()
                            .fill(scores[question.dimension] == value ? Color.appTint : Color.white.opacity(0.85))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().stroke(Color.appTint.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        value == 1 ? question.dimension.leftLabel :
                        value == 5 ? question.dimension.rightLabel :
                        "Position \(value) of 5"
                    )
                    .accessibilityAddTraits(
                        scores[question.dimension] == value ? .isSelected : []
                    )
                    if value < 5 { Spacer() }
                }
            }
            Text(scores[question.dimension] == nil ? "Choose what feels closest" : scaleAccessibilityValue(question.dimension))
                .font(.kanit(13))
                .foregroundStyle(scores[question.dimension] == nil ? .secondary : Color.appTint)
        }
        .padding(18)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 22))
    }

    private var footerButton: some View {
        Button(footerTitle) {
            if page == 7 {
                save()
            } else {
                nameFocused = false
                page += 1
            }
        }
        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
        .disabled(!canContinue)
        .alert("Couldn't save profile", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var footerTitle: String {
        if page == 7 { return "Complete my DNA" }
        if page == 5, usuallySkip.isEmpty { return "Skip" }
        if page == 6, mustHaves.isEmpty { return "Skip" }
        return "Next"
    }

    private var pageTitle: String {
        if page == -1 { return profile == nil ? "Name your profile" : "Recalibrate \(profile?.name ?? "profile")" }
        if page < 5 { return dnaQuestions[page].title }
        if page == 5 { return "What is something other tourists enjoy that you usually do not?" }
        if page == 6 { return "What makes a trip feel right for you?" }
        return "Anything else that would help us travel like you?"
    }

    private var canContinue: Bool {
        if page == -1 {
            return library.nameIsAvailable(name, excluding: profile?.id)
        }
        if page < 5 {
            return scores[dnaQuestions[page].dimension] != nil
        }
        return true
    }

    private var currentAnswers: [ProfileScaleAnswer] {
        TravellerDNADimension.allCases.map {
            ProfileScaleAnswer(dimension: $0, value: scores[$0] ?? 3)
        }
    }

    private var completedStepCount: Int {
        let scaleSteps = scores.count
        let skipStep = page > 5 || !usuallySkip.isEmpty ? 1 : 0
        let mustHaveStep = page > 6 || !mustHaves.isEmpty ? 1 : 0
        let notesStep = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1
        return min(8, scaleSteps + skipStep + mustHaveStep + notesStep)
    }

    private var blobProgress: Double {
        Double(completedStepCount) / 8
    }

    private var blobExpressionText: String {
        let scoreSignature = TravellerDNADimension.allCases.map {
            "\($0.rawValue):\(scores[$0] ?? 0)"
        }
        return (scoreSignature + usuallySkip + mustHaves + [additionalNotes])
            .joined(separator: "|")
    }

    private func scaleAccessibilityValue(_ dimension: TravellerDNADimension) -> String {
        guard let score = scores[dimension] else { return "Not answered" }
        return switch score {
        case 1: "Strongly \(dimension.leftLabel)"
        case 2: "Leaning \(dimension.leftLabel)"
        case 4: "Leaning \(dimension.rightLabel)"
        case 5: "Strongly \(dimension.rightLabel)"
        default: "A balance of both"
        }
    }

    private func save() {
        let now = Date()
        let saved = TravellerProfile(
            id: profile?.id ?? UUID(),
            name: name,
            scaleAnswers: TravellerDNADimension.allCases.compactMap { dimension in
                scores[dimension].map { ProfileScaleAnswer(dimension: dimension, value: $0) }
            },
            usuallySkip: usuallySkip,
            mustHaves: mustHaves,
            additionalNotes: additionalNotes,
            age: Int(age).flatMap { (1...120).contains($0) ? $0 : nil },
            passport: passport,
            createdAt: profile?.createdAt ?? now,
            updatedAt: now
        )
        do {
            try library.save(saved, analyticsEntryPoint: analyticsEntryPoint)
            onSave(library.profile(id: saved.id) ?? saved)
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var analyticsOperation: String { profile == nil ? "create" : "edit" }

    private var analyticsStepName: String {
        switch page {
        case -1: "identity"
        case 0...4: dnaQuestions[page].dimension.rawValue
        case 5: "usually_skip"
        case 6: "must_haves"
        default: "additional_notes"
        }
    }

    private func logAnalyticsIfNeeded() {
        if !didLogFlowStart {
            didLogFlowStart = true
            AnalyticsTracker.shared.log(
                .screenViewed(.profileEditor, entryPoint: analyticsEntryPoint)
            )
            AnalyticsTracker.shared.log(
                .init(.profileFlowStarted, properties: [
                    "entry_point": .string(analyticsEntryPoint),
                    "operation": .string(analyticsOperation)
                ])
            )
        }
        guard loggedPages.insert(page).inserted else { return }
        AnalyticsTracker.shared.log(
            .init(.profileStepViewed, properties: [
                "entry_point": .string(analyticsEntryPoint),
                "operation": .string(analyticsOperation),
                "step_name": .string(analyticsStepName),
                "step_index": .integer(page + 1)
            ])
        )
    }
}

private struct EntryListEditor: View {
    @Binding var entries: [String]
    let placeholder: String
    let helper: String
    @State private var draft = ""
    @FocusState private var draftFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                HStack {
                    Text(entry)
                        .font(.kanit(15))
                    Spacer()
                    Button {
                        entries.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Remove \(entry)")
                }
                .padding(12)
                .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 12))
            }

            if entries.count < 5 {
                HStack {
                    TextField(placeholder, text: $draft)
                        .focused($draftFocused)
                        .onChange(of: draft) { _, value in
                            draft = String(value.prefix(100))
                        }
                        .onSubmit(add)
                        .doubleTapToSelectAll()
                    Button(action: add) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.appTint)
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Add entry")
                }
                .padding(12)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            }

            Text(helper)
                .font(.kanit(12))
                .foregroundStyle(.secondary)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    draftFocused = false
                }
            }
        }
    }

    private func add() {
        let value = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, entries.count < 5 else { return }
        entries.append(String(value.prefix(100)))
        draft = ""
    }
}
