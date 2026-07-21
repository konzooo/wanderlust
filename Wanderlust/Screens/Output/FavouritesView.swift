//
//  FavouritesView.swift
//  Wanderlust
//
//  Created by Assistant on 5/7/25.
//

import SwiftUI

struct FavouritesView: View {
    var body: some View {
        // Simple empty state for now
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "heart")
                .font(.system(size: 64))
                .foregroundColor(.gray.opacity(0.4))
            
            Text("No favourites yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("Tap the heart icon on items you like!")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    FavouritesView()
} 