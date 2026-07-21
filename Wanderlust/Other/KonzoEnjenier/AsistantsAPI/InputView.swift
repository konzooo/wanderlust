//
//  InputView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 08.01.25.
//

import SwiftUI

struct InputView: View {
    @ObservedObject var viewModel: GPTManager

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Your Message")
                .font(.title)
                .padding()
            
            TextField("Type something...", text: $viewModel.userInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            Button(action: {
                viewModel.sendMessageToGPT()
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
            .disabled(viewModel.isLoading || viewModel.userInput.isEmpty)
            
            if viewModel.isLoading {
                ProgressView("Loading...")
                    .padding()
            }
            
            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
            }
            
            NavigationLink(
                destination: OutputView(response: viewModel.gptResponse),
                isActive: .constant(!viewModel.gptResponse.isEmpty)
            ) {
                EmptyView()
            }
        }
        .padding()
    }
}
