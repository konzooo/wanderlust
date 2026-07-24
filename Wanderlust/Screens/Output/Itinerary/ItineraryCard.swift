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

    init(tripItinerary: AsyncValue<Trip.Itinerary>, favorites: Binding<Trip.Favorites>) {
        self.tripItinerary = tripItinerary
        self._favorites = favorites
    }

    var body: some View {
        ZStack {
            switch tripItinerary {
            case .initial, .loading:
                ProgressView()
                    .padding(.top, 20)
                    .transition(.opacity)
                Spacer()
            case .error(let error):
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32))
                        .foregroundColor(.red)
                    Text("Failed to load itinerary.")
                        .font(.headline)
                    if let error = error as? LocalizedError {
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 20)
            case .loaded(let itinerary):
                ZStack(alignment: .top) {
                    PageIndicator(currentPage: currentPage, totalPages: itinerary.segments.count)
                        .padding(.top, .Padding.md)
                        .padding(.bottom, .Padding.sm3)

                    TabView(selection: $currentPage) {
                        ForEach(itinerary.segments.indices, id: \ .self) { index in
                            let segment = itinerary.segments[index]
                            ScrollView {
                                SegmentItineraryView(segment: segment, topContentOffset: 46, favorites: $favorites)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
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
