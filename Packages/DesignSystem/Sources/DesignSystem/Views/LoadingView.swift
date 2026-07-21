//
//  LoadingScreenView.swift
//  Wanderlust
//
//  Created by Konstantin Kaschub on 25.02.25.
//
import SwiftUI

public struct LoadingView: View {
    @State private var progress: CGFloat
    @State private var showQuestion1: Bool
    @State private var showAnswer1: Bool
    @State private var showQuestion2: Bool
    @State private var showAnswer2: Bool
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
        self._showQuestion1 = State(initialValue: showQuestion1)
        self._showAnswer1 = State(initialValue: showAnswer1)
        self._showQuestion2 = State(initialValue: showQuestion2)
        self._showAnswer2 = State(initialValue: showAnswer2)
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
                    if showQuestion1 {
                        Text("The most visited country in the world?")
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(.black)
                            .transition(.opacity)
                    }

                    if showAnswer1 {
                        Text("France - with over 80 million visitors annually")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#586FF2"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                            .transition(.opacity)
                    }
                }
                .padding(.top, -50) // Moves the first fact even higher

                VStack(alignment: .center, spacing: 5) {
                    if showQuestion2 {
                        Text("How many time zones does China have?")
                            .font(.system(size: 14))
                            .italic()
                            .foregroundColor(.black)
                            .transition(.opacity)
                    }

                    if showAnswer2 {
                        Text("China only has one time zone - Beijing Time (UTC+8)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(hex: "#586FF2"))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: UIScreen.main.bounds.width * 0.8)
                            .transition(.opacity)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            withAnimation(Animation.linear(duration: animationDuration).repeatForever(autoreverses: true)) {
                progress = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeIn(duration: 1)) {
                    showQuestion1 = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeIn(duration: 1)) {
                    showAnswer1 = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
                withAnimation(.easeIn(duration: 1)) {
                    showQuestion2 = true
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 9) {
                withAnimation(.easeIn(duration: 1)) {
                    showAnswer2 = true
                }
            }
        }
    }
}

struct LoadingScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LoadingView()
    }
}
