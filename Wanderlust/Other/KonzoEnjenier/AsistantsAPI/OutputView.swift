//
//  OutputView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 08.01.25.
//

import SwiftUI

struct OutputView: View {
    let response: String
    
    var body: some View {
        VStack {
            Text("GPT Response")
                .font(.title)
                .fontWeight(.bold)
                .padding()
            
            Text(response.isEmpty ? "No response received." : response)
                .padding()
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
    }
}
