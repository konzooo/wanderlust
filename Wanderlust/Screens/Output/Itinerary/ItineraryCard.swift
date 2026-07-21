//
//  ItineraryCard.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 26/6/25.
//

import CoreModels
import SwiftUI
import CoreArchitecture

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
                        .shadow(color: .black.opacity(0.5), radius: 4)
                        .scaleEffect(1.3)
                        .padding(.top, .Padding.md)
                        .padding(.bottom, .Padding.sm3)
                    
                    TabView(selection: $currentPage) {
                        ForEach(itinerary.segments.indices, id: \ .self) { index in
                            let segment = itinerary.segments[index]
                            ScrollView {
                                SegmentItineraryView(segment: segment, topContentOffset: 50, favorites: $favorites)
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.blue.opacity(0.12))
                        .shadow(radius: 4)
                )
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
                    .frame(width: 8, height: 8)
                    .foregroundColor(index == currentPage ? .appTint : .appTint.opacity(0.28))
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ItineraryCard(tripItinerary: .mock, favorites: .constant(.init()))
}

extension AsyncValue where Value == Trip.Itinerary {
    static var mock: AsyncValue<Trip.Itinerary> { .loaded(.mock) }
}
