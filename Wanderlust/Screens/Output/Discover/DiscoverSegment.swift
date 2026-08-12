//
//  DiscoverSegment.swift
//  Wanderlust
//
//  The text navigation inside the Discover tab.
//

import DesignSystem
import SwiftUI

/// One band of content inside Discover.
///
/// The order is the product's order — what a friend would tell you first, then
/// the calls they'd argue with you about, then the day-by-day shape as an
/// example.
enum DiscoverSegment: Int, CaseIterable, Identifiable, Hashable {
    case suggestions
    case worthIt
    case itinerary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .suggestions: "Suggestions"
        case .worthIt: "Worth it vs. skip?"
        case .itinerary: "Itinerary"
        }
    }
}

/// Quiet secondary navigation: text plus one active underline. It stays outside
/// the selected section's scroll view, so the three destinations remain visible
/// while their content moves without looking like a second set of primary tabs.
struct DiscoverSectionNavigation: View {
    @Binding var selection: DiscoverSegment
    let segments: [DiscoverSegment]
    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(segments) { segment in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = segment
                    }
                } label: {
                    Text(segment.title)
                        .font(DS.Typography.tabLabel)
                        .foregroundStyle(
                            selection == segment ? Color.primary : Color.secondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 10)
                        .overlay(alignment: .bottom) {
                            if selection == segment {
                                Capsule()
                                    .fill(Color.appTint)
                                    .frame(height: 3)
                                    .matchedGeometryEffect(
                                        id: "discover-section-underline",
                                        in: underline
                                    )
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(
                    selection == segment ? [.isSelected, .isButton] : .isButton
                )
            }
        }
        .padding(.horizontal, .Padding.sm3)
        .overlay(alignment: .bottom) { Divider() }
        .onAppear(perform: normalizeSelection)
        .onChange(of: segments) { _, _ in normalizeSelection() }
    }

    /// The Worth-it pill only exists when there are cards behind it, so the
    /// selected segment can disappear out from under the traveller.
    private func normalizeSelection() {
        guard !segments.contains(selection), let first = segments.first else { return }
        selection = first
    }

}

#Preview {
    @Previewable @State var selection: DiscoverSegment = .suggestions
    return VStack {
        DiscoverSectionNavigation(selection: $selection, segments: DiscoverSegment.allCases)
        Spacer()
    }
    .gradientBackground()
}
