//
//  HeartIcon.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 12/7/25.
//
 
import SwiftUI

struct HeartIcon: View {
    let size: CGFloat
    let isFavorited: Bool
    
    init(size: CGFloat = 20, isFavorited: Bool) {
        self.size = size
        self.isFavorited = isFavorited
    }
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size))
            .foregroundColor(isFavorited ? .red : .white)
            .overlay(
                Image(systemName: "heart")
                    .font(.system(size: size))
                    .foregroundColor(isFavorited ? .clear : .gray.opacity(0.4))
            )
    }
}
