//
//  FullScreenBackgroundImage.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/4/25.
//

import SwiftUI

/// View Modifier that places a resizable, scaled‐to‐fill background image behind the view.
struct FullScreenBackgroundImage: ViewModifier {
    let imageName: String

    func body(content: Content) -> some View {
        content
            .background(
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            )
    }
}

public extension View {
    /// Applies a “full‐screen” background image behind the view.
    func fullScreenBackground(_ imageName: String) -> some View {
        self.modifier(FullScreenBackgroundImage(imageName: imageName))
    }
}
