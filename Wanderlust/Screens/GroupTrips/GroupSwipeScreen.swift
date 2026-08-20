import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

/// Wraps the shared questionnaire in group mode: shows the group onboarding
/// (centered modal) first, then on completion uploads the member's preferences
/// and moves to the dashboard.
///
/// Resilience: swipes are saved to a local draft before upload. If the upload
/// fails (or the member leaves and returns), we detect the pending draft and
/// resume by re-submitting it — the member never has to swipe again.
struct GroupSwipeScreen: View {
    let groupId: String
    @EnvironmentObject var router: NavigationRouter
    @AppStorage(GroupOnboardingPreferenceKey.dismissed) private var onboardingDismissed = false
    @State private var showOnboarding = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var pendingDraft: MemberPreferences?
    @State private var didStartResume = false
    @State private var selectedProfileID: UUID?

    private let credentials: GroupTripCredentials?
    private let service: GroupTripService

    init(
        groupId: String,
        initialProfileSelection: ProfileTripSelection = .useDefault,
        service: GroupTripService = .shared
    ) {
        self.groupId = groupId
        self.service = service
        self.credentials = GroupTripCredentialsStore.load(groupId: groupId)
        let resolvedProfileID: UUID?
        switch initialProfileSelection {
        case .useDefault:
            resolvedProfileID = TravellerProfileLibrary.shared.defaultSelectionID
        case .none:
            resolvedProfileID = nil
        case let .profile(id):
            resolvedProfileID = id
        }
        _selectedProfileID = State(initialValue: resolvedProfileID)
    }

    var body: some View {
        ZStack {
            if let credentials {
                if let draft = pendingDraft {
                    resumeView(draft: draft, credentials: credentials)
                } else {
                    QuestionnaireScreen(
                        mode: .group(groupID: groupId, memberID: credentials.memberId),
                        profileSelection: $selectedProfileID,
                        onGroupCompletion: { preferences in
                            submit(preferences, credentials: credentials)
                        }
                    )
                    if showOnboarding {
                        GroupOnboardingOverlay(
                            onGotIt: { showOnboarding = false },
                            onDontShowAgain: {
                                onboardingDismissed = true
                                showOnboarding = false
                            }
                        )
                        .transition(.opacity)
                    }
                }

                if isSubmitting {
                    submittingOverlay
                }
            } else {
                missingCredentialsView
            }
        }
        .animation(.easeOut(duration: 0.2), value: showOnboarding)
        .onAppear {
            // A saved draft means a previous run swiped but didn't confirm the
            // upload — resume it instead of making the member swipe again.
            if let credentials, pendingDraft == nil {
                pendingDraft = GroupQuestionnaireDraftStore.load(memberID: credentials.memberId)
            }
            if pendingDraft == nil && !onboardingDismissed {
                showOnboarding = true
            }
        }
        .alert("Couldn't submit", isPresented: Binding(
            get: { submitError != nil },
            set: { if !$0 { submitError = nil } }
        )) {
            Button("Try again") {
                submitError = nil
                if let credentials, let draft = pendingDraft ?? GroupQuestionnaireDraftStore.load(memberID: credentials.memberId) {
                    submit(draft, credentials: credentials)
                }
            }
            Button("Back", role: .cancel) { submitError = nil; router.popToRoot() }
        } message: {
            Text(submitError ?? "")
        }
    }

    private func resumeView(draft: MemberPreferences, credentials: GroupTripCredentials) -> some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 12) {
                ProgressView().tint(Color.appTint)
                Text("Finishing up your submission…")
                    .font(DS.Typography.subtitle)
                    .foregroundColor(Color(.systemGray))
            }
        }
        .cleanTopInsets()
        .onAppear {
            guard !didStartResume else { return }
            didStartResume = true
            submit(draft, credentials: credentials)
        }
    }

    private func submit(_ preferences: MemberPreferences, credentials: GroupTripCredentials) {
        // Persist locally first so a failed upload never loses the swipes.
        GroupQuestionnaireDraftStore.save(preferences, memberID: credentials.memberId)
        isSubmitting = true
        submitError = nil

        Task { @MainActor in
            do {
                try await service.submitPreferences(
                    groupId: groupId,
                    memberId: credentials.memberId,
                    memberToken: credentials.memberToken,
                    preferences: preferences
                )
                GroupQuestionnaireDraftStore.clear(memberID: credentials.memberId)
                isSubmitting = false
                AnalyticsTracker.shared.log(
                    .outcome(
                        .groupPreferencesSubmitted,
                        outcome: "success",
                        properties: analyticsProperties(for: preferences)
                    )
                )
                router.goToGroupDashboard(groupId, resetStack: true)
            } catch {
                isSubmitting = false
                // If the member already submitted (e.g. a retry after the write
                // actually landed), treat it as done rather than looping.
                if "\(error)".contains("Not authorized") == false,
                   "\(error)".contains("already") {
                    GroupQuestionnaireDraftStore.clear(memberID: credentials.memberId)
                    router.goToGroupDashboard(groupId, resetStack: true)
                    return
                }
                submitError = "We couldn't upload your preferences. Your choices are saved — check your connection and try again."
                AnalyticsTracker.shared.log(
                    .outcome(
                        .groupPreferencesSubmitted,
                        outcome: "failure",
                        error: error,
                        properties: analyticsProperties(for: preferences)
                    )
                )
            }
        }
    }

    private func analyticsProperties(
        for preferences: MemberPreferences
    ) -> [String: AnalyticsValue] {
        var properties: [String: AnalyticsValue] = [
            "questionnaire_version": .integer(preferences.questionnaireVersion),
            "question_count": .integer(preferences.answers.count),
            "has_profile": .boolean(preferences.profile != nil),
            "profile_attached": .boolean(preferences.profile != nil),
            "profile_count": .integer(TravellerProfileLibrary.shared.profiles.count),
            "profile_attachment_source": .string(
                TravellerProfileLibrary.shared.analyticsAttachmentSource(
                    for: selectedProfileID
                )
            )
        ]
        for answer in preferences.answers {
            let paddedID = answer.questionID.count == 1
                ? "0\(answer.questionID)"
                : answer.questionID
            properties["q\(paddedID)_choice"] = .string(answer.choice.rawValue)
        }
        if let profile = preferences.profile {
            for dimension in TravellerDNADimension.allCases {
                if let score = profile.score(for: dimension) {
                    properties["dna_\(dimension.rawValue)"] = .integer(score)
                }
            }
            properties["profile_skip_count"] = .integer(profile.usuallySkip.count)
            properties["profile_must_have_count"] = .integer(profile.mustHaves.count)
            properties["profile_has_notes"] = .boolean(
                !(profile.additionalNotes?
                    .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
            )
        }
        return properties
    }

    private var submittingOverlay: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Submitting…").font(.kanit(15)).foregroundColor(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var missingCredentialsView: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle").font(.system(size: 32)).foregroundStyle(Color(.systemGray2))
                Text("Couldn't find your group membership.").font(DS.Typography.subtitle).foregroundColor(Color(.systemGray))
            }
        }
        .cleanTopInsets()
    }
}
