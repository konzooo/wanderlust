//
//  MySwipeableCardsView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 10.01.25.

import SwiftUI

struct SwipeCard: Identifiable {
    let id = UUID()
    let image: String?
    let text1: String?
    let text2: String?
}

struct MySwipeableCardsView: View {
    @ObservedObject var viewModel: UserInputViewModel
    @State private var currentIndex = 0
    @State private var gptResponse: String? = nil // Response from ChatGPT API
    @State private var isLoading = false // Loading state for button
    @State private var showSummary = false // Controls whether the summary is shown
    @State private var navigateToOutput = false // Controls navigation to GPT Output screen

    let cards = [
        SwipeCard(image: "TB - trusted favourites or unknown", text1: "Trusted favorites", text2: "Dive into the unknown"),
        SwipeCard(image: "TB - ancient ruins or futuristic city", text1: "Ancient ruins", text2: "Futuristic cityscapes"),
        SwipeCard(image: "TB - Chill evenings or dancing till sunrise", text1: "Dancing till sunrise", text2: "Chill evenings"),
        SwipeCard(image: "TB - on a budget or happy to spend", text1: "On a budget", text2: "Happy to spend"),
        SwipeCard(image: "TB - City or Nature", text1: "Culture of the City", text2: "Beauty of landscapes"),
        SwipeCard(image: "TB - classics vs secrets", text1: "Iconic landmarks", text2: "Off the beaten path"),
        SwipeCard(image: "TB - Disconnect or Adventure", text1: "Disconnect&Unwind", text2: "Excitement&Adventure"),
        SwipeCard(image: "TB - local streetfood or fine dining", text1: "Local street food", text2: "Fine Dining")
    ]

    let chatGPTService = OpenAIService()

    var body: some View {
        NavigationStack {
            VStack {
                if showSummary {
                    VStack(spacing: 20) {
                        // Summary Section
                        VStack {
                            HStack(alignment: .top, spacing: 20) {
                                // Column 1: Basic Information
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Basic Information")
                                        .font(.headline)
                                        .fontWeight(.semibold)

                                    Text("Destination: \(viewModel.destination)")
                                        .font(.caption)
                                    Text("Travel Mode: \(viewModel.travelMode)")
                                        .font(.caption)
                                    Text("Number of Days: \(viewModel.numberOfDays)")
                                        .font(.caption)
                                    Text("Start Month: \(viewModel.startMonthIndex + 1)")
                                        .font(.caption)
                                }

                                // Column 2: Responses
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Responses")
                                        .font(.headline)
                                        .fontWeight(.semibold)

                                    ForEach(viewModel.responses, id: \.self) { response in
                                        Text(response)
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(height: UIScreen.main.bounds.height * 0.25) // Top 25% of the screen
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)

                        // Submit Button
                        Button(action: { sendToGPT() }) {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text("Submit")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                        .disabled(isLoading) // Disable button while loading
                    }
                } else {
                    VStack {
                        Text("What's your style?")
                            .font(.title)
                            .fontWeight(.bold)
                            .padding(.bottom, 20)

                        if let image = cards[currentIndex].image, let text1 = cards[currentIndex].text1, let text2 = cards[currentIndex].text2 {
                            ZStack(alignment: .bottom) {
                                Image(image)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(20)
                                    .shadow(radius: 5)

                                HStack(spacing: 10) {
                                    EqualSizeTextBox(
                                        text: text1,
                                        backgroundColor: Color(red: 0.74, green: 0.91, blue: 0.93)
                                    )
                                    EqualSizeTextBox(
                                        text: text2,
                                        backgroundColor: Color(red: 0.99, green: 0.94, blue: 0.75)
                                    )
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 10)
                            }
                            .frame(maxWidth: .infinity, maxHeight: 400)
                        }

                        // Navigation and Both Button
                        HStack {
                            Button(action: { recordResponse("\(currentIndex + 1) Left") }) {
                                Image(systemName: "arrow.left.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(red: 0.74, green: 0.91, blue: 0.93))
                            }

                            Spacer()

                            Button(action: { recordResponse("\(currentIndex + 1) Right") }) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(red: 0.99, green: 0.94, blue: 0.75))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)

                        Button(action: { recordResponse("\(currentIndex + 1) Both") }) {
                            Text("Both")
                                .font(.system(size: 16))
                                .foregroundColor(Color.gray)
                                .padding(10)
                                .frame(width: 80)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(50)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                }
            }

            // Navigation to GPT Output Screen
            NavigationLink(destination: GPTOutputView(response: gptResponse ?? ""), isActive: $navigateToOutput) {
                EmptyView()
            }
        }
    }

    private func recordResponse(_ response: String) {
        viewModel.responses.append(response)

        if currentIndex < cards.count - 1 {
            currentIndex += 1
        } else {
            showSummary = true
        }
    }

    private func sendToGPT() {
        // Combine Basic Information and Responses into a single prompt
        let combinedPrompt = """
        Basic Information:
        - Destination: \(viewModel.destination)
        - Travel Mode: \(viewModel.travelMode)
        - Number of Days: \(viewModel.numberOfDays)
        - Start Month: \(viewModel.startMonthIndex + 1)

        Preferences:
        \(viewModel.responses.joined(separator: "\n"))
        """

        isLoading = true

        Task {
            do {
                let response = try await chatGPTService.processCompletions(data: combinedPrompt)
                DispatchQueue.main.async {
                    isLoading = false
                    self.gptResponse = response
                    self.navigateToOutput = true // Navigate to the output screen
                }
                print("Response: \(response)")
            } catch {
                isLoading = false
                print("Error from ChatGPT API: \(error.localizedDescription)")
            }
        }

    }
}

struct EqualSizeTextBox: View {
    let text: String
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.headline)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, minHeight: 28)
            .padding()
            .background(backgroundColor)
            .cornerRadius(10)
    }
}
