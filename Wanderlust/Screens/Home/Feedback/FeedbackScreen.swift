//
//  FeedbackView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 5/28/25.
//

import CoreArchitecture
import SwiftUI
import DesignSystem
import CoreArchitecture
import SwiftUI
import DesignSystem

// TODO: Cleanup this View
struct FeedbackScreen: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: FeedbackStore

    // 1️⃣ Which editor has focus?
    @FocusState private var focusedField: Field?
    private enum Field { case likes, suggestions }

    var body: some View {
        ScrollView {               // 2️⃣ Scroll when keyboard is up
            VStack(spacing: 20) {

                header

                VStack(alignment: .leading, spacing: 8) {
                    likesDislikes
                    suggestions
                }
                .padding(.horizontal, .Padding.md4)

                Spacer(minLength: 20)   // keeps distance from the inset button
            }
        }
        // 3️⃣ Pull-down to dismiss (iOS 17) – falls back gracefully
        .scrollDismissesKeyboard(.interactively)

        // 4️⃣ Action button stays visible
        .safeAreaInset(edge: .bottom) {
            Button("Submit") {
                AnalyticsTracker.shared.log(.buttonTapped("submit_feedback", screen: .feedback))
                store.send(.submit)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))
            .disabled(store.state.isSubmitButtonDisabled)
            .padding(.horizontal, .Padding.md)
            .padding(.bottom, .Padding.md)
        }

        // 5️⃣ Tap the gradient to hide the keyboard
        .onTapGesture { focusedField = nil }

        // Same gradient you already had
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.init(red: 0.9, green: 0.95, blue: 1.0),
                                            .init(red: 1.0, green: 0.94, blue: 0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )

        // 6️⃣ “Done” button above the keyboard
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focusedField = nil }
            }
        }
        .onAppear {
            AnalyticsTracker.shared.log(.screenViewed(.feedback))
        }
    }

    // MARK: - Subviews --------------------------------------------------------

    private var header: some View {
        VStack(spacing: 8) {
            Text("Help shape the App")
                .font(.kanitBold(24))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.darkGray)
                .padding(.bottom, .Padding.md)

            (
                Text("We are just at the start and want to build this app together ")
                + Text("with you!").bold()
                + Text(" Let us know what you like, what you dislike, and suggestions you might have.")
            )
            .font(.kanitItalic(16))
            .foregroundStyle(Color.darkGray)
            .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, .Padding.md4)
        .padding(.bottom, .Padding.md4)
    }

    private var likesDislikes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What do you like/ dislike?")
                .font(.kanit(16))

            TextEditor(text: $store.state.likesDislikes)
                .focused($focusedField, equals: .likes)       // 🔑
                .font(.kanit(14))
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    Text(store.state.likesDislikes.isEmpty ? "Tell us why…" : "")
                        .font(.kanitItalic(14))
                        .foregroundColor(.gray)
                        .opacity(0.6)
                        .padding(8),
                    alignment: .topLeading
                )
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anything you would add or change?")
                .font(.kanit(16))

            TextEditor(text: $store.state.suggestions)
                .focused($focusedField, equals: .suggestions) // 🔑
                .font(.kanit(14))
                .frame(height: 120)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.5)))
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    Text(store.state.suggestions.isEmpty ? "Tell us why…" : "")
                        .font(.kanitItalic(14))
                        .foregroundColor(.gray)
                        .opacity(0.6)
                        .padding(8),
                    alignment: .topLeading
                )
        }
    }
}


#Preview {
    NavigationStack {
        FeedbackScreen(store: FeedbackStore())
    }
}
