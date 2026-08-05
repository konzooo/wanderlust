//
//  SpecifyGroupView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/19/25.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import SwiftUI

struct SpecifyGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var averageAgeText    = ""
    @State private var genderSelection   = Trip.Details.Gender.male
    @State private var customDescription = ""

    var onSave: (Output) -> Void

    /// Return value for the parent on Save.
    struct Output {
        let averageAge: Int?
        let gender: Trip.Details.Gender
        let customDescription: String?
    }

    init(averageAgeText: String?,
         genderSelection: Trip.Details.Gender?,
         customDescription: String?,
         onSave: @escaping (Output) -> Void
    ) {
        self.averageAgeText = averageAgeText ?? ""
        self.genderSelection = genderSelection ?? .male
        self.customDescription = customDescription ?? ""
        self.onSave = onSave
    }

    // MARK: View
    var body: some View {
        NavigationStack {
            ZStack {
                SoftBackground()

                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .padding(.top, 4)
                            .padding(.bottom, 20)

                        formCard
                    }
                    .padding(.horizontal, .Padding.md3)
                    .padding(.bottom, .Padding.md3)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(
                            .init(
                                averageAge: Int(averageAgeText),
                                gender: genderSelection,
                                customDescription: customDescription
                            )
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .tint(Color.appTint)
        }
    }

    var header: some View {
        VStack(spacing: 4) {
            Text("Specify your group")
                .font(DS.Typography.sheetTitle)
            Text("Helps us tailor suggestions to your crew")
                .font(.kanitLight(13))
                .foregroundColor(Color(.systemGray))
        }
    }

    var formCard: some View {
        DS.GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                averageAgeView
                cardDivider
                genderView
                cardDivider
                customDescriptionView
            }
        }
    }

    var cardDivider: some View {
        Divider().overlay(Color.white.opacity(0.5))
    }

    func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.appTint)
            Text(text)
                .font(DS.Typography.fieldLabel)
        }
    }

    var averageAgeView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Average age", icon: "number.circle.fill")

            TextField("e.g. 35", text: $averageAgeText)
                .font(.kanit(17).weight(.medium))
                .keyboardType(.numberPad)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(Color.white.opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
        }
    }

    var genderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Gender", icon: "person.fill")

            Picker("Gender", selection: $genderSelection) {
                ForEach(Trip.Details.Gender.all, id: \.self) { gender in
                    Text(gender.rawValue)
                        .tag(gender)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.appTint)
            .frame(height: 40)
        }
    }

    var customDescriptionView: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Anything else?", icon: "text.bubble.fill")

            PlaceholderTextEditor(
                text: $customDescription,
                placeholder: "e.g. 4 girls in a bachelorette weekend!"
            )
            .frame(height: 100)
            .padding(8)
            .background(Color.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: CGFloat.Radius.field, style: .continuous))
            .scrollContentBackground(.hidden)
        }
    }
}

#Preview("SpecifyGroupView") {
    SpecifyGroupView(averageAgeText: "22", genderSelection: .male, customDescription: nil)
    { _ in }
}

struct PlaceholderTextEditor: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.kanitLight(17))
                .background(Color.clear)

            if text.isEmpty {
                Text(placeholder)
                    .font(.kanitLightItalic(17))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.top, 8)
                    .padding(.horizontal, 5)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Calmer, unblurred version of the app's blue/purple/yellow gradient family —
/// enough to tie this sheet visually to Next Trip without competing with the
/// small form for attention.
private struct SoftBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color.gradientTop, Color.white, Color.gradientBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
