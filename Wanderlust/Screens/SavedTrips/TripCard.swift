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
    @State private var imageUrlState: AsyncValue<URL> = .initial

    private let imageService = UnsplashService()
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CacheDestinationImage(
                cacheKey: trip.destination,
                imageUrlState: imageUrlState
            )
            .frame(height: 160)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(
                LinearGradient(
                    colors: [Color.black.opacity(0.6), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .padding(.trailing, 60)
            )
            .cornerRadius(24)
            
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                Text(trip.details.destination.name)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
                
                HStack(spacing: 8) {
                    Text(trip.details.month.simplified.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                    
                    Text(trip.details.members.groupType.rawValue.capitalized)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                }
            }
            .padding(.leading, 20)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 160, alignment: .bottom)
            
//            Button(action: {
//                // TODO: Share trip action
//            }) {
//                Image(systemName: "square.and.arrow.up")
//                    .resizable()
//                    .frame(width: 15, height: 15)
//                    .foregroundColor(.white)
//                    .padding(6)
//                    .background(Color.black.opacity(0.25))
//                    .clipShape(Circle())
//            }
//            .padding(12)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.0001))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.appTint.opacity(0.4), lineWidth: 2)
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
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
