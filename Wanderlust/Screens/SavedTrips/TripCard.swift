//
//  TripCard.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 4/7/25.
//

import SwiftUI
import CoreModels
import CoreArchitecture
import DesignSystem
import Networking

struct TripCard: View {
    let trip: Trip
    let onImageURLResolved: (URL) -> Void
    @State private var imageUrlState: AsyncValue<URL>

    private let imageService = UnsplashService()

    init(
        trip: Trip,
        onImageURLResolved: @escaping (URL) -> Void = { _ in }
    ) {
        self.trip = trip
        self.onImageURLResolved = onImageURLResolved
        if let rawURL = trip.imageUrl, let url = URL(string: rawURL) {
            _imageUrlState = State(initialValue: .loaded(url))
        } else {
            _imageUrlState = State(initialValue: .initial)
        }
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CacheDestinationImage(
                cacheKey: trip.destination,
                imageUrlState: imageUrlState
            )
            .frame(height: 184)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(trip.details.destination.name)
                    .font(DS.Typography.displayBold)
                    .foregroundColor(.white)
                    .shadow(radius: 4)

                HStack(spacing: 8) {
                    Text(trip.details.month.simplified.capitalized)
                        .font(.kanitMedium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial.opacity(0.6), in: Capsule())

                    Text(trip.details.members.groupType.rawValue.capitalized)
                        .font(.kanitMedium(14))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial.opacity(0.6), in: Capsule())
                }
            }
            .padding(16)
        }
        .frame(height: 184)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous))
        .shadow(color: Color.black.opacity(0.16), radius: 14, y: 8)
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        guard case .initial = imageUrlState else { return }
        imageUrlState = .loading
        Task {
            do {
                let url = try await imageService.fetchImageURL(
                    for: trip.itinerary.destination ?? trip.details.destination.name
                )
                await MainActor.run {
                    imageUrlState = .loaded(url)
                    onImageURLResolved(url)
                }
            } catch {
                await MainActor.run {
                    imageUrlState = .error(error)
                }
            }
        }
    }
}

#Preview {
    TripCard(trip: Trip.mockList.first!)
}
