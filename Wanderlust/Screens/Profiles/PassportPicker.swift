//
//  PassportPicker.swift
//  Wanderlust
//
//  A compact passport + age row, and the country search it opens. Both sit
//  on one line under the profile name, so the first DNA step stays a single
//  question with a quiet pair of extras below it.
//

import CoreModels
import DesignSystem
import SwiftUI

/// Passport and age, side by side, sized to sit under a text field without
/// claiming a section of its own.
struct PassportAgeRow: View {
    @Binding var passport: String?
    @Binding var age: String

    @FocusState private var ageFocused: Bool
    @State private var pickerPresented = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                ageFocused = false
                pickerPresented = true
            } label: {
                HStack(spacing: 8) {
                    if let passport {
                        Text(Country.flag(for: passport))
                            .font(.system(size: 17))
                        Text(Country.displayName(for: passport) ?? passport)
                            .font(.kanit(15))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    } else {
                        Text("Passport")
                            .font(.kanit(15))
                            .foregroundStyle(Color.secondary.opacity(0.7))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Passport")
            .accessibilityValue(
                passport.flatMap(Country.displayName(for:)) ?? "Not set"
            )

            TextField("Age", text: $age)
                .keyboardType(.numberPad)
                .focused($ageFocused)
                .multilineTextAlignment(.leading)
                .font(.kanit(15))
                .frame(width: 62)
                .onChange(of: age) { _, value in
                    age = String(value.filter(\.isNumber).prefix(3))
                }
                .accessibilityLabel("Age")
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 14))
        }
        .sheet(isPresented: $pickerPresented) {
            PassportPickerSheet(selection: $passport)
        }
        .toolbar {
            // Only while the number pad is up: it has no return key, and the
            // name field above has its own.
            if ageFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { ageFocused = false }
                }
            }
        }
    }
}

/// Type-to-filter country list with flags, in a half-height sheet so the
/// keyboard and the results share the screen.
struct PassportPickerSheet: View {
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var queryFocused: Bool

    private var results: [Country] {
        Country.search(query)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search countries", text: $query)
                        .font(.kanit(16))
                        .focused($queryFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            if let first = results.first { select(first) }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                List {
                    if selection != nil {
                        Button("Clear selection") {
                            selection = nil
                            dismiss()
                        }
                        .font(.kanit(15))
                        .foregroundStyle(.secondary)
                    }
                    ForEach(results) { country in
                        Button {
                            select(country)
                        } label: {
                            HStack(spacing: 12) {
                                Text(country.flag)
                                    .font(.system(size: 22))
                                Text(country.name)
                                    .font(.kanit(16))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                if country.code == selection {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.appTint)
                                }
                            }
                        }
                        .accessibilityAddTraits(country.code == selection ? .isSelected : [])
                    }
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Passport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task {
            await Task.yield()
            queryFocused = true
        }
    }

    private func select(_ country: Country) {
        selection = country.code
        dismiss()
    }
}
