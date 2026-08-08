//
//  DS.TabView.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 25/6/25.
//

import SwiftUI

// MARK: - Model

/// The top-level sections of the trip output.
///
/// Favourites used to be the third tab. It is no longer a tab at all: it is a
/// pill in the header opening a full-screen sheet, because it is a *view of*
/// this trip's content rather than a fourth kind of content.
public enum OutputTab: Int, CaseIterable, Identifiable {
    /// Everything the model wrote about the destination: suggestions, the
    /// worth-it/skip cards, the sample itinerary.
    case discover
    /// Address-grounded picks around where the traveller is staying.
    case nearYou
    /// Destination-wide practical preparation.
    case knowBeforeYouGo

    public var id: Int { rawValue }

    public var title: String {
        switch self {
        case .discover: "Discover"
        case .nearYou: "Near You"
        case .knowBeforeYouGo: "Know Before You Go"
        }
    }

    public var icon: String {
        switch self {
        case .discover: "sparkles"
        case .nearYou: "location"
        case .knowBeforeYouGo: "lightbulb"
        }
    }
}

// MARK: - Tab Bar
extension DS {
    public struct ContentTabBar: View {
        @Binding var selection: OutputTab
        /// Which tabs this screen actually shows. Visibility is per-mode — a
        /// group trip has no personal layer, and a tab whose content is not
        /// wired up yet is simply not passed in — so the bar renders what it is
        /// given rather than every case of the enum.
        private let tabs: [OutputTab]
        @Namespace private var underline   // for the matched-geometry animation

        private let accent = Color.appTint

        public init(selection: Binding<OutputTab>, tabs: [OutputTab] = OutputTab.allCases) {
            self._selection = selection
            self.tabs = tabs
        }

        public var body: some View {
            VStack(spacing: 0) {
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(tabs) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selection = tab
                            }
                        } label: {
                            tabLabel(for: tab)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(selection == tab ? [.isSelected, .isButton] : .isButton)
                    }
                }
                .padding(.top, .Padding.sm2)

                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }
            .background(Color(.systemBackground))
            // A selection outside `tabs` would leave the bar with nothing
            // highlighted and the screen showing a tab the traveller cannot get
            // back to. Correcting it here means every caller gets the guarantee
            // rather than each one remembering it.
            .onAppear(perform: normalizeSelection)
            .onChange(of: tabs) { _, _ in normalizeSelection() }
        }

        private func normalizeSelection() {
            guard !tabs.contains(selection), let first = tabs.first else { return }
            selection = first
        }

        /// Icon stacked above the label, so "Know Before You Go" fits the same
        /// equal-width column as "Discover".
        @ViewBuilder
        private func tabLabel(for tab: OutputTab) -> some View {
            VStack(spacing: 5) {
                VStack(spacing: 3) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 16, weight: .semibold))

                    Text(tab.title)
                        .font(DS.Typography.tabLabel)
                        .lineLimit(1)
                        // Keep the chrome at one stable size. Content below the
                        // bar can change its ideal width (notably the wrapped
                        // Suggestions footer), but must never make tab labels
                        // participate in text scaling.
                        .fixedSize(horizontal: true, vertical: false)
                }
                .foregroundStyle(selection == tab ? accent : Color(.systemGray))
                .padding(.horizontal, 4)
                .padding(.top, 3)
                .padding(.bottom, 7)

                if selection == tab {
                    Rectangle()
                        .fill(accent)
                        .matchedGeometryEffect(id: "underline", in: underline)
                        .frame(height: 3)
                        .alignmentGuide(.bottom) { d in d[.bottom] }
                } else {
                    // invisible spacer to keep every stack the same height
                    Rectangle()
                        .fill(Color.clear)
                        .frame(height: 3)
                }
            }
        }
    }
}

// MARK: - Example usage / preview
struct ContentTabBarPreview: View {
    @State private var currentTab: OutputTab = .discover
    let tabs: [OutputTab]

    var body: some View {
        VStack(spacing: 0) {
            DS.ContentTabBar(selection: $currentTab, tabs: tabs)

            Text(currentTab.title)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

#Preview("All tabs") {
    ContentTabBarPreview(tabs: OutputTab.allCases)
}

#Preview("Near You hidden") {
    ContentTabBarPreview(tabs: [.discover, .knowBeforeYouGo])
}
