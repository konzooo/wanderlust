//
//  DiscoverSegment.swift
//  Wanderlust
//
//  The pill selector inside the Discover tab.
//

import DesignSystem
import SwiftUI

/// One band of content inside Discover.
///
/// These are pills rather than a second tab bar on purpose: they are three
/// readings of the same destination, not three destinations. The order is the
/// product's order — what a friend would tell you first, then the calls they'd
/// argue with you about, then the day-by-day shape as an example.
enum DiscoverSegment: Int, CaseIterable, Identifiable, Hashable {
    case suggestions
    case worthIt
    case itinerary

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .suggestions: "Suggestions for you"
        case .worthIt: "Worth it or skip"
        case .itinerary: "Sample itinerary"
        }
    }
}

/// Sticky pill row. Lives above the content rather than inside its scroll view,
/// so it stays put while the feed moves under it.
struct DiscoverPillBar: View {
    @Binding var selection: DiscoverSegment
    let segments: [DiscoverSegment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .Padding.sm2) {
                ForEach(segments) { segment in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selection = segment
                        }
                    } label: {
                        pill(for: segment)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        selection == segment ? [.isSelected, .isButton] : .isButton
                    )
                }
            }
            .padding(.horizontal, .Padding.sm3)
            .padding(.vertical, .Padding.sm2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
        .onAppear(perform: normalizeSelection)
        .onChange(of: segments) { _, _ in normalizeSelection() }
    }

    /// The Worth-it pill only exists when there are cards behind it, so the
    /// selected segment can disappear out from under the traveller.
    private func normalizeSelection() {
        guard !segments.contains(selection), let first = segments.first else { return }
        selection = first
    }

    @ViewBuilder
    private func pill(for segment: DiscoverSegment) -> some View {
        let isSelected = selection == segment
        Text(segment.title)
            .font(DS.Typography.tabLabel)
            .foregroundStyle(isSelected ? Color.white : Color.appTint)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(
                    isSelected ? AnyShapeStyle(Color.appTint)
                               : AnyShapeStyle(Color.appTint.opacity(0.07))
                )
            )
            .overlay(
                Capsule().stroke(
                    isSelected ? Color.clear : Color.appTint.opacity(0.18),
                    lineWidth: 1
                )
            )
    }
}

#Preview {
    @Previewable @State var selection: DiscoverSegment = .suggestions
    return VStack {
        DiscoverPillBar(selection: $selection, segments: DiscoverSegment.allCases)
        Spacer()
    }
    .gradientBackground()
}
