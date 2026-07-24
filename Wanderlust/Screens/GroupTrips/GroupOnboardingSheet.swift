import DesignSystem
import SwiftUI

/// The "What's your style?" explainer shown before a member swipes for a group.
/// A centered modal card (not a bottom sheet), matching the app's onboarding
/// style with colored icon chips. "Got it" dismisses for this visit; "Don't
/// show again" persists via `@AppStorage`. Separate from the solo card tutorial
/// (which the group flow suppresses) so the two never stack.
struct GroupOnboardingOverlay: View {
    let onGotIt: () -> Void
    let onDontShowAgain: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.52)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("What's your style?")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.darkGray)
                    Text("Tap right or left to choose")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 26)

                VStack(alignment: .leading, spacing: 24) {
                    row(
                        icon: "person.fill",
                        tint: Color.appTint,
                        title: "Your personal preferences",
                        subtitle: "Swipe according to your own personal preferences. Others will swipe for theirs."
                    )
                    row(
                        icon: "clock.fill",
                        tint: Color(hex: "#68C86A"),
                        title: "Wait for others to finish",
                        subtitle: "Once everyone has swiped, you'll find the result in My Group Trips."
                    )
                    row(
                        icon: "person.3.fill",
                        tint: Color(hex: "#5B5BD6"),
                        title: "One joint trip",
                        subtitle: "We'll find the best mix of suggestions for your group."
                    )
                }

                Spacer(minLength: 30)

                VStack(spacing: 12) {
                    Button(action: onGotIt) {
                        Text("Got it")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.appTint)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    Button(action: onDontShowAgain) {
                        Text("Don't show again")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityHint("Hides this introduction permanently")
                }
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 28)
            .frame(maxWidth: 360)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 8)
            .padding(.horizontal, 28)
        }
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.14))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.darkGray)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

enum GroupOnboardingPreferenceKey {
    static let dismissed = "onboarding.groupQuestionnaire.dismissed"
}
