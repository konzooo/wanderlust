//
//  GPTOutputView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 12.01.25.
//

import SwiftUI

struct GPTOutputView: View {
    let response: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("ChatGPT Response")
                    .font(.title)
                    .fontWeight(.bold)

                Text(response)
                    .font(.body)
                    .foregroundColor(.gray)
                    .padding()

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Your Itinerary")
    }
}
