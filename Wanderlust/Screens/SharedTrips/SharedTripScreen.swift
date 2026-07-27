import CoreArchitecture
import DesignSystem
import SwiftUI

/// A single-screen resolver for a shared-trip link: shows a loader while
/// `SharedTripStore` resolves the code, then renders `TripOutputScreen`
/// inline once loaded — never as a separate pushed destination, so the back
/// button never pops to a stale loading screen.
struct SharedTripScreen: View {
    @StateObject private var store: SharedTripStore
    @EnvironmentObject var router: NavigationRouter

    init(code: String) {
        _store = StateObject(wrappedValue: SharedTripStore(code: code))
    }

    var body: some View {
        switch store.state.resolved {
        case .loading:
            ZStack {
                AuroraBackground()
                ProgressView().tint(Color.appTint)
            }
            .cleanTopInsets()
        case .failed:
            unavailableState
        case let .loaded(outputState):
            TripOutputScreen(initialState: outputState)
        }
    }

    private var unavailableState: some View {
        ZStack {
            AuroraBackground()
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(.systemGray2))
                Text("This trip link isn't available")
                    .font(DS.Typography.displayLight)
                Text("It may have been shared incorrectly, or you're offline.")
                    .font(DS.Typography.subtitle)
                    .foregroundColor(Color(.systemGray))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    router.popToRoot()
                } label: {
                    Text("Back to Trips")
                }
                .buttonStyle(PrimaryButtonStyle(fullWidth: false))
                .padding(.top, 6)
            }
        }
        .cleanTopInsets()
    }
}
