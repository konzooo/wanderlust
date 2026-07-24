//
//  LoadingScreenView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 25.02.25.
//
import SwiftUI

public struct LoadingView: View {
    @State private var progress: CGFloat
    @State private var currentFactIndex: Int
    @State private var showQuestion: Bool
    @State private var showAnswer: Bool
    @State private var rotateIcon: Bool
    let progressWidth: CGFloat = UIScreen.main.bounds.width * 0.8
    let animationDuration = 1.5

    public init(
        progress: CGFloat = 0.0,
        showQuestion1: Bool = false,
        showAnswer1: Bool = false,
        showQuestion2: Bool = false,
        showAnswer2: Bool = false,
        rotateIcon: Bool = false
    ) {
        self._progress = State(initialValue: progress)
        self._currentFactIndex = State(initialValue: showQuestion2 || showAnswer2 ? 1 : 0)
        self._showQuestion = State(initialValue: showQuestion1 || showQuestion2)
        self._showAnswer = State(initialValue: showAnswer1 || showAnswer2)
        self._rotateIcon = State(initialValue: rotateIcon)
    }

    public var body: some View {
        ZStack {
            // Background Image
            Image("map-background") // Ensure this matches the asset name in your project
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
                .opacity(0.3) // Adjust opacity for subtle effect

            VStack(spacing: 20) {
                HStack {
                    Button(action: {
                        print("Menu tapped")
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title)
                            .foregroundColor(Color(hex: "#586FF2"))
                    }
                    Text("Workspace")
                        .foregroundColor(Color(hex: "#586FF2"))
                        .font(.system(size: 18, weight: .medium))
                    Spacer()
                }
                .padding(.top, 20)
                .padding(.horizontal)

                Text("Let the magic happen ...")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                    .frame(width: progressWidth, height: 5)
                    .foregroundColor(Color.gray.opacity(0.3))

                    RoundedRectangle(cornerRadius: 5)
                        .frame(width: progress * progressWidth, height: 5)
                        .foregroundColor(Color(hex: "#586FF2"))
                        .animation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: true), value: progress)
                }
                .padding(.horizontal)

                // Animated Travel Icon
                Image(systemName: "airplane.circle.fill") // Travel-themed icon
                    .font(.system(size: 40))
                    .foregroundColor(Color(hex: "#586FF2"))
                    .rotationEffect(.degrees(rotateIcon ? 360 : 0))
                    .animation(Animation.linear(duration: 4).repeatForever(autoreverses: false), value: rotateIcon)
                    .onAppear {
                        rotateIcon = true
                    }

                Spacer()

                VStack(alignment: .center, spacing: 5) {
                    if showQuestion {
                        Text(currentFact.question)
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(.black)
                            .transition(.opacity)
                    }

                    if showAnswer {
                        Text(currentFact.answer)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#586FF2"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                            .transition(.opacity)
                    }
                }
                .padding(.top, -50)

                Spacer()
            }
            .padding()
        }
        .task {
            withAnimation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
                progress = 1.0
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.35)) {
                    showQuestion = true
                }

                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeIn(duration: 0.35)) {
                    showAnswer = true
                }

                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    showQuestion = false
                    showAnswer = false
                }
                currentFactIndex = (currentFactIndex + 1) % Self.facts.count
            }
        }
    }

    private var currentFact: TravelFact {
        Self.facts[currentFactIndex]
    }

    private struct TravelFact: Equatable {
        let question: String
        let answer: String
    }

    private static let facts: [TravelFact] = [
        .init(question: "How many time zones does China use?", answer: "Just one — the whole country follows China Standard Time."),
        .init(question: "Which country has the only non-rectangular flag?", answer: "Nepal — its flag is formed from two stacked pennants."),
        .init(question: "Can a commercial flight last under two minutes?", answer: "Yes — the hop between Westray and Papa Westray in Scotland can take about 90 seconds."),
        .init(question: "How many islands make up Venice?", answer: "More than 100 small islands, linked by hundreds of bridges."),
        .init(question: "Which city has the world’s longest urban cable-car network?", answer: "La Paz, Bolivia — its Mi Teleférico lines glide above the city."),
        .init(question: "Where can you find the world’s largest salt flat?", answer: "Bolivia’s Salar de Uyuni — it becomes a giant mirror after rain."),
        .init(question: "Why do Icelanders call their country the Land of Fire and Ice?", answer: "It has glaciers, volcanoes, geysers, and geothermal hot springs in one place."),
        .init(question: "Which continent has no permanent residents?", answer: "Antarctica — scientists and support teams rotate through research stations."),
        .init(question: "What is a passport’s most powerful feature?", answer: "It is your key to crossing borders, collecting stamps, and starting a new story."),
        .init(question: "Where does the sun rise first each day?", answer: "Among the first inhabited places to greet it are islands in the Pacific Ocean."),
        .init(question: "What makes Japan’s rail network famous?", answer: "Its high-speed trains are known for precision, comfort, and remarkable punctuality."),
        .init(question: "Why is the Great Barrier Reef visible from space?", answer: "It is the world’s largest coral reef system, stretching along Australia’s coast.")
    ]
}

struct LoadingScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
