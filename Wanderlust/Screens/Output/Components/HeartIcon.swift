//
//  HeartIcon.swift
//  Wanderlust
//
//  Created by Rodrigo Mato on 12/7/25.
//

import SwiftUI

/// Favorite toggle glyph. Sits on light / frosted cards, so it's a plain
/// outline when unfavorited and a solid red when favorited (no white fill,
/// which would vanish against a light surface).
struct HeartIcon: View {
    let size: CGFloat
    let isFavorited: Bool

    init(size: CGFloat = 20, isFavorited: Bool) {
        self.size = size
        self.isFavorited = isFavorited
    }

    var body: some View {
        Image(systemName: isFavorited ? "heart.fill" : "heart")
            .font(.system(size: size))
            .foregroundStyle(isFavorited ? Color.red : Color(.systemGray3))
    }
}
