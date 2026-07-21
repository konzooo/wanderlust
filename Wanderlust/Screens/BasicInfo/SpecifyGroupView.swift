//
//  SpecifyGroupView.swift
//  Wanderlust
//
//  Created by Rodrigo Mato Castellano on 4/19/25.
//

import CoreArchitecture
import CoreModels
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
            ScrollView {
                VStack(spacing: 0) {
                    Text("Specify your group")
                        .font(.kanitItalic(22))
                        .frame(alignment: .center)
                        .padding(.bottom, .Padding.md3)

                    formView

                    Spacer()
                }
            }
            .background(Color.popoverBackground)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        AnalyticsTracker.shared.log(.buttonTapped("specify_group_save", screen: .basicInfo))
                        onSave(
                            .init(
                                averageAge: Int(averageAgeText),
                                gender: genderSelection,
                                customDescription: customDescription
                            )
                        )
                        dismiss()
                    }
                }
            }
            .tint(Color.appTint)
        }
    }

    var formView: some View {
        VStack(alignment: .leading, spacing: .Padding.md2) {
            averageAgeView

            genderView

            customDescriptionView
        }
        .padding(.horizontal, .Padding.md3)
    }

    var averageAgeView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Average Age")
                .font(.kanitLight(18))

            TextField("e.g. 35", text: $averageAgeText)
                .font(.kanitLightItalic(17))
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
        }
    }

    var genderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gender")
                .font(.kanitLight(18))

            Picker("Gender", selection: $genderSelection) {
                ForEach(Trip.Details.Gender.all, id: \.self) { gender in
                    Text(gender.rawValue)
                        .tag(gender)
                }
            }
            .pickerStyle(.segmented)
            .tint(Color.appTint)
        }
    }

    var customDescriptionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Custom")
                .font(.kanitLight(18))

            PlaceholderTextEditor(
                text: $customDescription,
                placeholder: "e.g. 4 girls in a bachelorette weekend!"
            )
            .frame(height: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.5))
            )
            .background(Color.white)
            .cornerRadius(8)
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
                .background(Color.white)
                .padding(4)

            if text.isEmpty {
                Text(placeholder)
                    .font(.kanitLightItalic(17))
                    .foregroundColor(.gray.opacity(0.5))
                    .padding(.top, 12)
                    .padding(.horizontal, 12)
            }
        }
    }
}
