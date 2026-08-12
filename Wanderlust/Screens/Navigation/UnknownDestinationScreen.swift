import DesignSystem
import SwiftUI

struct UnknownDestinationScreen: View {
    let message: String?

    var body: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 14) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.appTint)
                Text("We couldn't open that link")
                    .font(DS.Typography.displayLight)
                Text(message ?? "This destination is no longer available.")
                    .font(DS.Typography.subtitle)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
