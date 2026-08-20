import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

struct ProfileTabScreen: View {
    @ObservedObject private var library = TravellerProfileLibrary.shared
    @EnvironmentObject private var router: NavigationRouter
    @Environment(\.navigationTab) private var navigationTab
    @State private var createDNAPresented = false

    @AppStorage(ProfilePreferenceKey.introductionDismissed) private var introDismissed = false
    @State private var introPresented = false

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    travellerDNAEntry

                    settingsSection
                        .padding(.top, 28)

                    communitySection
                        .padding(.top, 25)

                    versionFooter
                        .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $createDNAPresented) {
            TravellerDNAEditorScreen(profile: nil, analyticsEntryPoint: "profile_tab") { _ in }
        }
        .sheet(isPresented: $introPresented) {
            TravellerDNAIntroScreen(
                onCreate: {
                    introDismissed = true
                    introPresented = false
                    createDNAPresented = true
                },
                // A deferral, not a decision: nothing is persisted, and the
                // launch-scoped guard below is what keeps "later" from meaning
                // "again the next time you open this tab".
                onMaybeLater: { introPresented = false },
                onDontShowAgain: {
                    introDismissed = true
                    introPresented = false
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onTabRootAppear(.profile, router: router) {
            AnalyticsTracker.shared.log(.screenViewed(.profileTab))
            library.syncAnalyticsState()
            presentIntroIfNeeded()
        }
    }

    /// The tab already shows `EmptyTravellerDNACard`, which is the affordance —
    /// this is the explanation, and only for someone who has never made a
    /// profile and has not turned it off.
    private func presentIntroIfNeeded() {
        let session = OnboardingSession.shared

        guard library.profiles.isEmpty,
              !introDismissed,
              !session.didShowDNAIntroThisLaunch
        else { return }

        session.didShowDNAIntroThisLaunch = true
        // Presented as a pop-up over the profile screen rather than the
        // instant it appears, so the traveller sees the tab itself first.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            introPresented = true
        }
        AnalyticsTracker.shared.log(.screenViewed(.travellerDNAIntro))
    }

    @ViewBuilder
    private var travellerDNAEntry: some View {
        if let profile = library.mainProfile {
            NavigationLink {
                ProfilesScreen(
                    analyticsEntryPoint: "profile_tab",
                    navigationTitle: "Traveller DNA",
                    showsDoneButton: false,
                    automaticallyPresentsOnboarding: false
                )
            } label: {
                TravellerDNACard(
                    profile: profile,
                    profileCount: library.profiles.count
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens your profile")
        } else {
            Button {
                createDNAPresented = true
            } label: {
                EmptyTravellerDNACard()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Create Traveller DNA")
            .accessibilityHint("Starts the Traveller DNA setup")
        }
    }

    private var settingsSection: some View {
        ProfileMenuSection(title: "Settings") {
            NavigationLink {
                NotificationsScreen()
            } label: {
                ProfileMenuRow(
                    symbol: "bell.badge",
                    title: "Notifications",
                    subtitle: "Choose when Wanderlust checks in",
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var communitySection: some View {
        ProfileMenuSection(title: "Community") {
            Button {
                router.goToFeedback(on: navigationTab)
            } label: {
                ProfileMenuRow(
                    symbol: "bubble.left.and.bubble.right",
                    title: "Give Feedback",
                    subtitle: "Help shape what Wanderlust becomes",
                    accessory: .chevron,
                    textColor: Color(hex: "#238636")
                )
            }
            .buttonStyle(.plain)

            ProfileMenuDivider()

            Link(destination: Self.writeReviewURL) {
                ProfileMenuRow(
                    symbol: "star",
                    title: "Rate Wanderlust",
                    subtitle: "Opens the App Store review sheet",
                    accessory: .chevron
                )
            }
            .buttonStyle(.plain)
        }
    }

    /// The version belongs wherever a traveller is asked to read it out in a
    /// bug report, so it sits at the end of the list rather than in a row.
    private var versionFooter: some View {
        Text("Wanderlust \(Self.versionString)")
            .font(.kanit(11))
            .foregroundStyle(Color.secondary.opacity(0.8))
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Wanderlust version \(Self.versionString)")
    }

    /// `action=write-review` opens the App Store on the review sheet rather
    /// than dropping the traveller on the product page.
    private static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id6746957492?action=write-review"
    )!

    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

private struct TravellerDNACard: View {
    let profile: TravellerProfile
    let profileCount: Int

    private var displayName: String {
        profile.name
    }

    private var archetype: String {
        profile.archetype
    }

    private var countLabel: String {
        return profileCount == 1 ? "1 profile" : "\(profileCount) profiles"
    }

    private var answers: [ProfileScaleAnswer] {
        profile.scaleAnswers
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#20274E"), Color(hex: "#3D4BA8"), Color.appTint],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            dnaDecoration

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("TRAVELLER DNA", systemImage: "sparkles")
                        .font(.kanit(10).weight(.semibold))
                        .tracking(1.45)
                        .foregroundStyle(.white.opacity(0.76))

                    Spacer()

                    Text("MAIN")
                        .font(.kanit(9).weight(.semibold))
                        .tracking(0.9)
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay { Capsule().stroke(.white.opacity(0.12), lineWidth: 1) }
                }

                HStack(spacing: 16) {
                    TravellerDNABlob(
                        answers: answers,
                        compact: true,
                        animated: false,
                        expressionText: displayName
                    )
                    .frame(width: 78, height: 78)
                    .padding(10)
                    .background(.white.opacity(0.95), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.82), lineWidth: 1)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName)
                            .font(.kanit(25).weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        Text(archetype)
                            .font(.kanit(13))
                            .foregroundStyle(.white.opacity(0.73))
                            .lineLimit(1)

                        Label(countLabel, systemImage: "person.2.fill")
                            .font(.kanit(10).weight(.medium))
                            .foregroundStyle(.white.opacity(0.58))
                            .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 20)

                Spacer(minLength: 14)

                Text("The more Wanderlust learns about you, the more personal your travel advice gets.")
                    .font(.kanit(11))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, 22)

                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)
                    .padding(.top, 12)

                HStack(spacing: 8) {
                    Text("Manage Profile")
                        .font(.kanit(13).weight(.medium))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.11), in: Circle())
                }
                .foregroundStyle(.white.opacity(0.90))
                .padding(.top, 10)
            }
            .padding(20)
        }
        .frame(height: 278)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: Color(hex: "#27336F").opacity(0.24), radius: 22, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var dnaDecoration: some View {
        GeometryReader { proxy in
            Image(systemName: "globe.europe.africa.fill")
                .font(.system(size: 128, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.035))
                .position(x: proxy.size.width - 52, y: proxy.size.height - 38)
        }
        .allowsHitTesting(false)
    }
}

private struct EmptyTravellerDNACard: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.92),
                    Color(hex: "#F1F1FF").opacity(0.94),
                    Color(hex: "#FFF8EC").opacity(0.92)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Label("PROFILE", systemImage: "atom")
                        .font(.kanit(10).weight(.semibold))
                        .tracking(1.45)
                        .foregroundStyle(Color.appTint)

                    Spacer()

                    Label("2 MIN", systemImage: "clock")
                        .font(.kanit(9).weight(.semibold))
                        .tracking(0.75)
                        .foregroundStyle(Color.appTint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.appTint.opacity(0.09), in: Capsule())
                }

                HStack(spacing: 15) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 29, weight: .light))
                        .foregroundStyle(Color.appTint)
                        .frame(width: 66, height: 66)
                        .background(.white.opacity(0.80), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.appTint.opacity(0.12), lineWidth: 1)
                        }

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Let’s personalize")
                            .font(.kanit(24).weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("Two minutes now, better advice on every trip.")
                            .font(.kanit(13).weight(.medium))
                            .foregroundStyle(Color.primary.opacity(0.72))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.top, 18)

                Text("The better we know you, the more personal the advice gets.")
                    .font(.kanit(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 15)

                HStack(spacing: 8) {
                    Text("Create Traveller DNA")
                        .font(.kanit(13).weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 15)
                .frame(height: 44)
                .background(Color.appTint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 17)
            }
            .padding(20)
        }
        .frame(height: 290)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.88), lineWidth: 1)
        }
        .shadow(color: Color.appTint.opacity(0.12), radius: 22, y: 12)
        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

}

private enum ProfileMenuAccessory {
    case chevron
    case comingSoon
}

private struct ProfileMenuSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.kanit(11).weight(.semibold))
                .tracking(1.55)
                .foregroundStyle(Color.secondary.opacity(0.86))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(.white.opacity(0.70), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.025), radius: 12, y: 6)
        }
    }
}

private struct ProfileMenuRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accessory: ProfileMenuAccessory
    var textColor: Color? = nil

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.appTint)
                .frame(width: 38, height: 38)
                .background(Color.appTint.opacity(0.09), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kanit(15).weight(.medium))
                    .foregroundStyle(textColor ?? Color.primary)
                Text(subtitle)
                    .font(.kanit(11))
                    .foregroundStyle(textColor ?? Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            switch accessory {
            case .chevron:
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.78))
            case .comingSoon:
                Text("COMING SOON")
                    .font(.kanit(8).weight(.semibold))
                    .tracking(0.55)
                    .foregroundStyle(Color.appTint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.appTint.opacity(0.09), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 67)
        .contentShape(Rectangle())
    }
}

private struct ProfileMenuDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 65)
            .opacity(0.46)
    }
}

private struct NotificationsScreen: View {
    @AppStorage("profile.notifications.enabled") private var notificationsEnabled = true
    @AppStorage("profile.notifications.inspiration") private var inspirationEnabled = true
    @AppStorage("profile.notifications.tripReminders") private var tripRemindersEnabled = true
    @AppStorage("profile.notifications.groupActivity") private var groupActivityEnabled = true

    var body: some View {
        ZStack {
            AuroraBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    notificationSection

                    Text("You can change these preferences at any time.")
                        .font(.kanit(11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Color.appTint)
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(
                    LinearGradient(
                        colors: [Color.appTint, Color(hex: "#8B6BF6")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: Color.appTint.opacity(0.24), radius: 16, y: 8)

            Text("Stay in the loop")
                .font(.kanit(24).weight(.semibold))

            Text("Choose the moments when you’d like Wanderlust to check in.")
                .font(.kanit(13))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("NOTIFICATIONS")
                .font(.kanit(11).weight(.semibold))
                .tracking(1.55)
                .foregroundStyle(Color.secondary.opacity(0.86))
                .padding(.leading, 4)

            VStack(spacing: 0) {
                NotificationToggleRow(
                    symbol: "bell.fill",
                    title: "Allow notifications",
                    subtitle: "Keep helpful updates switched on",
                    isOn: $notificationsEnabled,
                    isEmphasized: true
                )

                Group {
                    ProfileMenuDivider()

                    NotificationToggleRow(
                        symbol: "sparkles",
                        title: "Fresh inspiration",
                        subtitle: "Occasional ideas picked for you",
                        isOn: $inspirationEnabled
                    )

                    ProfileMenuDivider()

                    NotificationToggleRow(
                        symbol: "calendar.badge.clock",
                        title: "Trip reminders",
                        subtitle: "Helpful nudges before you go",
                        isOn: $tripRemindersEnabled
                    )

                    ProfileMenuDivider()

                    NotificationToggleRow(
                        symbol: "person.3.fill",
                        title: "Group trip activity",
                        subtitle: "Votes and updates from your group",
                        isOn: $groupActivityEnabled
                    )
                }
                .disabled(!notificationsEnabled)
                .opacity(notificationsEnabled ? 1 : 0.42)
            }
            .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .stroke(.white.opacity(0.76), lineWidth: 1)
            }
        }
    }
}

private struct NotificationToggleRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var isEmphasized = false

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isEmphasized ? .white : Color.appTint)
                .frame(width: 36, height: 36)
                .background(
                    isEmphasized ? Color.appTint : Color.appTint.opacity(0.09),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kanit(15).weight(.medium))
                Text(subtitle)
                    .font(.kanit(11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 70)
    }
}

#Preview {
    NavigationStack {
        ProfileTabScreen()
    }
    .environmentObject(NavigationRouter())
}
