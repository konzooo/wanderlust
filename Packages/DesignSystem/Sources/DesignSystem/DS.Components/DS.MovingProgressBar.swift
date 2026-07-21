//
//  MovingProgressBar.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/7/25.
//

import Foundation
import SwiftUI

/// A static background, with a moving rounded rectangle on top.
/// The moving part is set to a fraction of the total width via parameter.
/// The x offset is controlled with an animation, so the top part moves back and forth along the x-axis.
public extension DS {
    public struct MovingProgressBar: View {
        @State private var offsetX: CGFloat = 0
        @State private var totalWidth: CGFloat = 0
        private let progressWidthFraction: CGFloat
        private let height: CGFloat

        public init(
            progressWidthFraction: CGFloat = 0.25,
            height: CGFloat = 10
        ) {
            self.progressWidthFraction = progressWidthFraction
            self.height = height
        }

        public var body: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: height)

                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(hex: "#586FF2"))
                        .frame(width: totalWidth * progressWidthFraction, height: height)
                        .offset(x: offsetX)
                        .animation(.easeInOut(duration: 1), value: offsetX)
                }
                .onAppear {
                    DispatchQueue.main.async {
                        totalWidth = geometry.size.width
                        startAnimation()
                    }
                }
            }
            .frame(height: height)
        }

        private func startAnimation() {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                // Dispatching on main queue given totalWidth is @State and is implicitly isolated into main actor
                DispatchQueue.main.async {
                    withAnimation {
                        let maxOffset = totalWidth - (totalWidth * progressWidthFraction)
                        offsetX = (offsetX == 0) ? maxOffset : 0
                    }
                }
            }
        }
    }
}

#Preview {
    DS.MovingProgressBar(progressWidthFraction: 0.5)
        .padding()
}
