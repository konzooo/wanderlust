//
//  DS.TabView.swift
//  DesignSystem
//
//  Created by Rodrigo Mato on 25/6/25.
//

import SwiftUI

// MARK: - Model
public enum OutputTab: Int, CaseIterable, Identifiable {
    case itinerary, suggestions, favourites
    
    public var id: Int { rawValue }
    
    public var title: String {
        switch self {
        case .itinerary:   return "Itinerary"
        case .suggestions: return "Suggestions"
        case .favourites:  return "Favourites"
        }
    }
    
    public var icon: String {
        switch self {
        case .itinerary:   return "doc.text"         // feel free to swap
        case .suggestions: return "square.grid.2x2"
        case .favourites:  return "heart.fill"
        }
    }
}

// MARK: - Tab Bar
extension DS {
    public struct ContentTabBar: View {
        @Binding var selection: OutputTab
        @Namespace private var underline   // for the matched-geometry animation
        
        /// Accent colour taken from Assets › "AccentColor" (or hard-code your own)
        private let accent = Color.appTint
        
        public  init(selection: Binding<OutputTab>) {
            self._selection = selection
        }
        
        public var body: some View {
            VStack(spacing: 0) {
                
                // --- Two tab buttons -------------------------------------------------
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(OutputTab.allCases) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selection = tab
                            }
                        } label: {
                            tabLabel(for: tab)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 12)   // little breathing-room like in screenshot
                
                // --- 1-pt grey divider under the bar --------------------------------
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
            }
            .background(Color(.systemBackground))
        }
        
        /// Builds the text+icon + (when selected) the blue underline
        @ViewBuilder
        private func tabLabel(for tab: OutputTab) -> some View {
            VStack(spacing: 6) {
                // Title
                HStack(spacing: 6) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 16, weight: .semibold))
                    Text(tab.title)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(selection == tab ? accent : Color(.systemGray))
                .padding(.top, 3)
                .padding(.bottom, 8)
                
                // Blue underline
                // - With matched-geometry underline
                if selection == tab {
                    Rectangle()
                        .fill(accent)
                        .matchedGeometryEffect(id: "underline", in: underline)
                        .frame(height: 3)
                        .alignmentGuide(.bottom) { d in d[.bottom] }
                } else {
                    // invisible spacer to keep both stacks equal height
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
    @State private var currentTab: OutputTab = .itinerary
    
    var body: some View {
        VStack(spacing: 0) {
            DS.ContentTabBar(selection: $currentTab)
            
            // replace with your real content
            if currentTab == .itinerary {
                Text("Itinerary page")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.green))
            } else {
                Text("Suggestions page")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }
}

#Preview {
    ContentTabBarPreview()
}
