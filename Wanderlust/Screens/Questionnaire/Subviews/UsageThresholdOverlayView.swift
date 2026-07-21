import CoreArchitecture
import DesignSystem
import SwiftUI

struct UsageThresholdOverlayView: View {
    let metricKey: MetricKey
    let threshold: Int
    var onGoBack: () -> Void

    var body: some View {
        VStack(spacing: .Padding.md3) {

            Text("You've reached your\ndaily limit :(")
                .font(.kanit(24).weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, .Padding.md3)

            Text("You can explore \(threshold) unique journeys every day.\nCome back tomorrow for more!")
                .font(.kanit(16))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, .Padding.md3)

            Spacer()

            Button("Go back") {
                onGoBack()
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .padding(.horizontal, .Padding.md3)
            .padding(.bottom, .Padding.lg)
        }
        .fullScreenBackground("gradient")
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("UsageThresholdOverlayView") {
    UsageThresholdOverlayView(
        metricKey: .dailyItineraries,
        threshold: 5,
        onGoBack: {}
    )
}
