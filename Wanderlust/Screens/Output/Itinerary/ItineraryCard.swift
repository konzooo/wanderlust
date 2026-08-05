//
//  ItineraryCard.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 26/6/25.
//

import CoreModels
import SwiftUI
import CoreArchitecture
import DesignSystem

// MARK: - Card
struct ItineraryCard: View {
    @State private var currentPage = 0
    let tripItinerary: AsyncValue<Trip.Itinerary>
    @Binding var favorites: Trip.Favorites
    /// `nil` where there is nothing to re-request (read-only trips).
    let onRetry: (() -> Void)?

    init(
        tripItinerary: AsyncValue<Trip.Itinerary>,
        favorites: Binding<Trip.Favorites>,
        onRetry: (() -> Void)? = nil
    ) {
        self.tripItinerary = tripItinerary
        self._favorites = favorites
        self.onRetry = onRetry
    }

    var body: some View {
        ZStack {
            ComponentStateView(
                value: tripItinerary,
                subject: "your sample itinerary",
                onRetry: onRetry
            ) { itinerary in
                ZStack(alignment: .top) {
                    PageIndicator(currentPage: currentPage, totalPages: itinerary.segments.count)
                        .padding(.top, .Padding.md)
                        .padding(.bottom, .Padding.sm3)

                    TabView(selection: $currentPage) {
                        ForEach(itinerary.segments.indices, id: \ .self) { index in
                            let segment = itinerary.segments[index]
                            ScrollView {
                                SegmentItineraryView(segment: segment, topContentOffset: 52, favorites: $favorites)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    // Scrolled content dissolves under the page dots instead of being
                    // sliced in half by the card's top edge.
                    .mask(
                        VStack(spacing: 0) {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 40)
                            Color.black
                        }
                    )
                }
                .background(
                    RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                        .fill(.thinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                        .stroke(Color.white.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
                .frame(maxWidth: .infinity)
                .transition(
                    .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale)
                )
            }
        }
        .animation(.easeInOut(duration: 0.40), value: tripItinerary)
        .padding(.horizontal, .Padding.sm3)
        .padding(.top, 20)
    }
}

// MARK: - Page indicator
struct PageIndicator: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .frame(width: 6, height: 6)
                    .foregroundStyle(index == currentPage ? Color.appTint : Color.appTint.opacity(0.25))
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}

// MARK: - Preview
#Preview {
    ItineraryCard(tripItinerary: .mock, favorites: .constant(.init()))
}

extension AsyncValue where Value == Trip.Itinerary {
    static var mock: AsyncValue<Trip.Itinerary> { .loaded(.mock) }
}
