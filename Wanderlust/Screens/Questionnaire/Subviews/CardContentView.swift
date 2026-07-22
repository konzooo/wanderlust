//
//  CardView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/1/25.
//

import DesignSystem
import SwiftUI

struct CardContentView: View {
    let imageName: String
    let rightText: String
    let leftText: String

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .cornerRadius(CGFloat.Radius.cardSmall)
                .shadow(radius: 5)

            VStack {
                Spacer() // Push everything down to the bottom

//                HStack {
//                    // Left text
//                    Text(leftText)
//                        .foregroundColor(Color(UIColor.systemGray5))
//                        .padding(4)
//                        .background(Color.black.opacity(0.7))
//                        .cornerRadius(4)
//
//                        .multilineTextAlignment(.center)
//                        .frame(maxWidth: .infinity)
//
//                    Spacer()
//
//                    // Right text
//                    Text(rightText)
//                        .foregroundColor(Color(UIColor.systemGray6))
//                        .padding(4)
//                        .background(Color.black.opacity(0.7))
//                        .cornerRadius(4)
//
//                        .multilineTextAlignment(.center)
//                        .frame(maxWidth: .infinity)
//                }
//                .padding(.horizontal, 5)
//                .padding(.bottom, 40)
            }

        }
    }
}
