//
//  NearYouView.swift
//  Wanderlust
//
//  The complete solo/group Near You flow: device-side grounding, adaptive
//  editorial picks, and a visually separate deterministic practical layer.
//

import CoreArchitecture
import CoreModels
import DesignSystem
import MapKit
import SwiftUI

/// A value the UI can render while retaining MapKit's exact completion object.
///
/// Flattening a completion into `title, subtitle` and searching that text again
/// can produce a different place. The MapKit object is immutable for our use
/// and crosses only the main-actor UI/store boundary, so the wrapper owns the
/// unchecked conformance rather than leaking it through the rest of the model.
struct NearYouAddressSuggestion: Identifiable, Equatable, @unchecked Sendable {
    let title: String
    let subtitle: String
    let completion: MKLocalSearchCompletion?

    var id: String { "\(title)|\(subtitle)" }

    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        completion = nil
    }

    init(completion: MKLocalSearchCompletion) {
        title = completion.title
        subtitle = completion.subtitle
        self.completion = completion
    }

    /// A completion is still resolved by MapKit after confirmation. Keeping the
    /// full subtitle here gives that search enough context to preserve the exact
    /// result the traveller selected from the list.
    var searchText: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubtitle = subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubtitle.isEmpty,
              !trimmedTitle.localizedCaseInsensitiveContains(trimmedSubtitle) else {
            return trimmedTitle
        }
        return "\(trimmedTitle), \(trimmedSubtitle)"
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
private final class NearYouAddressCompleter: NSObject, ObservableObject {
    @Published private(set) var suggestions: [NearYouAddressSuggestion] = []
    @Published private(set) var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var destination = ""
    private var destinationRegion: MKCoordinateRegion?

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func configure(destination: String) async {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != self.destination else { return }
        self.destination = trimmed
        destinationRegion = await MapKitNearYouService.searchRegion(for: trimmed)
        if let destinationRegion {
            completer.region = destinationRegion
        }
    }

    func update(query: String, destination: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            clear()
            return
        }

        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if destinationRegion != nil || destination.isEmpty
            || trimmed.localizedCaseInsensitiveContains(destination) {
            completer.queryFragment = trimmed
        } else {
            completer.queryFragment = "\(trimmed), \(destination)"
        }
        isSearching = true
    }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
        isSearching = false
    }
}

extension NearYouAddressCompleter: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        var seen = Set<String>()
        let suggestions = completer.results.prefix(8).compactMap { completion in
            let suggestion = NearYouAddressSuggestion(
                completion: completion
            )
            return seen.insert(suggestion.id).inserted ? suggestion : nil
        }
        Task { @MainActor [weak self] in
            self?.suggestions = suggestions
            self?.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.suggestions = []
            self?.isSearching = false
        }
    }
}

struct NearYouWalkingFacts: Equatable {
    let distance: String
    let duration: String
    let isApproximate: Bool

    static func make(
        candidate: Trip.NearYouCandidate,
        precision: CoarseAccommodation.Precision
    ) -> Self {
        let distance: String
        if candidate.distanceMetres < 1_000 {
            distance = "\(candidate.distanceMetres) m"
        } else {
            distance = String(format: "%.1f km", Double(candidate.distanceMetres) / 1_000)
        }
        return Self(
            distance: precision == .neighbourhood ? "≈ \(distance)" : distance,
            duration: precision == .neighbourhood
                ? "≈ \(candidate.walkingMinutes) min walk"
                : "\(candidate.walkingMinutes) min walk",
            isApproximate: precision == .neighbourhood
        )
    }
}

struct NearYouView: View {
    let accommodation: CoarseAccommodation?
    let result: AsyncValue<Trip.NearYou>
    let addressResolution: AsyncValue<NearYouAddressResolution>
    let whereToStay: AsyncValue<[Trip.StayArea]>
    let destination: String
    let isGroup: Bool
    let setBy: String?
    let canReplace: Bool
    @Binding var favorites: Trip.Favorites
    let onSearchAddress: (String) -> Void
    let onSearchSuggestion: (NearYouAddressSuggestion) -> Void
    let onResetLocationSearch: () -> Void
    let onChooseResolution: (NearYouResolutionChoice) -> Void
    let onRetryWhereToStay: (() -> Void)?
    let onRetryNearYou: () -> Void
    let onRegenerate: () -> Void
    let onChangeStay: () -> Void

    @State private var address = ""
    @State private var selectedSuggestion: NearYouAddressSuggestion?
    @State private var ambiguousPreview: NearYouResolutionChoice?
    @State private var showsWhereToStay = false
    @State private var showsLocationPicker = false
    @State private var mapPickerInitialCoordinate: NearYouCoordinate?
    @StateObject private var addressCompleter = NearYouAddressCompleter()
    @FocusState private var isAddressFocused: Bool

    var body: some View {
        Group {
            if let accommodation {
                groundedContent(accommodation: accommodation)
            } else {
                ungroundedContent
            }
        }
        .sheet(isPresented: $showsWhereToStay) {
            WhereToStaySheet(
                areas: whereToStay,
                destination: destination,
                onRetry: onRetryWhereToStay,
                onClose: { showsWhereToStay = false }
            )
        }
        .sheet(isPresented: $showsLocationPicker) {
            NearYouLocationPicker(
                destination: destination,
                initialCoordinate: mapPickerInitialCoordinate,
                onConfirm: onChooseResolution
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task(id: destination) {
            await addressCompleter.configure(destination: destination)
        }
    }

    /// The un-grounded state asks for one honest grounding point: an exact
    /// address selected or confirmed by the traveller. Everything that isn't
    /// that one question stays out of the way — the map is a quiet fallback,
    /// not a competing call to action.
    private var ungroundedContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Spacer(minLength: .Padding.md3)

                VStack(spacing: .Spacing.small) {
                    Image(systemName: "location.magnifyingglass")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(Color.appTint)

                    Text(isGroup ? "Where is the group staying?" : "Where are you staying?")
                        .font(.kanitMedium(25))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, .Padding.md)

                addressField
                    .padding(.horizontal, .Padding.md)
                    .padding(.top, .Padding.md2)

                if shouldShowSearchButton {
                    Button("Find this location", action: submitAddress)
                        .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                        .disabled(trimmedAddress.isEmpty || addressResolution.isLoading)
                        .padding(.horizontal, .Padding.md)
                        .padding(.top, .Spacing.medium)
                }

                if resolvedPreview == nil {
                    Button("Not showing up?") { openLocationPicker() }
                        .font(.kanitMedium(13))
                        .foregroundStyle(Color.appTint)
                        .padding(.top, .Spacing.medium)

                    Button("No place booked yet?") { showsWhereToStay = true }
                        .font(.kanitMedium(13))
                        .foregroundStyle(.secondary)
                        .padding(.top, .Spacing.small)
                }

                Spacer(minLength: .Padding.md3)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, .Padding.md)
        }
        .onDisappear { addressCompleter.clear() }
    }

    private var addressField: some View {
        VStack(alignment: .leading, spacing: .Spacing.small) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Guest house, hotel, or full address", text: $address)
                    .textContentType(.fullStreetAddress)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($isAddressFocused)
                    .onSubmit(handleKeyboardSubmit)
                    .onChange(of: address) { _, value in
                        if selectedSuggestion?.searchText != value {
                            selectedSuggestion = nil
                            ambiguousPreview = nil
                            onResetLocationSearch()
                            addressCompleter.update(query: value, destination: destination)
                        }
                    }

                if addressCompleter.isSearching {
                    ProgressView().controlSize(.small)
                } else if !address.isEmpty {
                    Button {
                        address = ""
                        selectedSuggestion = nil
                        ambiguousPreview = nil
                        addressCompleter.clear()
                        onResetLocationSearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear address")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(
                        selectedSuggestion == nil
                            ? Color.black.opacity(0.08)
                            : Color.appTint.opacity(0.65),
                        lineWidth: selectedSuggestion == nil ? 1 : 1.5
                    )
            )
            .shadow(color: .black.opacity(0.07), radius: 12, y: 3)

            if isAddressFocused, selectedSuggestion == nil,
               !addressCompleter.suggestions.isEmpty {
                suggestionList
            } else if let selectedSuggestion {
                Label("Selected: \(selectedSuggestion.title)", systemImage: "checkmark.circle.fill")
                    .font(.kanit(13))
                    .foregroundStyle(Color.appTint)
                    .fixedSize(horizontal: false, vertical: true)
            }

            resolutionFeedback
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(addressCompleter.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.appTint)
                            .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .font(.kanitMedium(15))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.kanit(12))
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if index < addressCompleter.suggestions.count - 1 {
                    Divider().padding(.leading, 38)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, y: 5)
    }

    private var trimmedAddress: String {
        address.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedPreview: NearYouResolutionChoice? {
        if let ambiguousPreview { return ambiguousPreview }
        guard case .loaded(.resolved(let choice)) = addressResolution else { return nil }
        return choice
    }

    private var shouldShowSearchButton: Bool {
        switch addressResolution {
        case .initial, .error:
            return true
        case .loading, .loaded:
            return false
        }
    }

    private func selectSuggestion(_ suggestion: NearYouAddressSuggestion) {
        selectedSuggestion = suggestion
        ambiguousPreview = nil
        address = suggestion.searchText
        addressCompleter.clear()
        isAddressFocused = false
        onSearchSuggestion(suggestion)
    }

    /// Return resolves one unambiguous completion; otherwise the traveller's
    /// full input takes the address-first manual path.
    private func handleKeyboardSubmit() {
        if addressCompleter.suggestions.count == 1,
           let suggestion = addressCompleter.suggestions.first {
            selectSuggestion(suggestion)
        } else {
            submitAddress()
        }
    }

    @ViewBuilder
    private var resolutionFeedback: some View {
        switch addressResolution {
        case .initial:
            EmptyView()
        case .loading:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Finding that stay in Apple Maps…")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
        case .error:
            Label(
                "We couldn't pin that down. Check the full address or choose it on the map.",
                systemImage: "exclamationmark.triangle"
            )
            .font(.kanit(13))
            .foregroundStyle(.secondary)
        case .loaded(.resolved(let choice)):
            locationPreview(choice)
        case .loaded(.ambiguous(let choices)):
            if let ambiguousPreview {
                locationPreview(ambiguousPreview, canReturnToChoices: true)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Which one did you mean?")
                        .font(DS.Typography.eyebrow)
                        .foregroundStyle(Color.appTint)

                    ForEach(choices) { choice in
                        Button {
                            ambiguousPreview = choice
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(choice.title)
                                    .font(.kanitMedium(15))
                                    .foregroundStyle(.primary)
                                if let subtitle = choice.subtitle {
                                    Text(subtitle)
                                        .font(.kanit(12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.appTint.opacity(0.06))
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func locationPreview(
        _ choice: NearYouResolutionChoice,
        canReturnToChoices: Bool = false
    ) -> some View {
        let coordinate = CLLocationCoordinate2D(
            latitude: choice.centre.latitude,
            longitude: choice.centre.longitude
        )
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Check the pin")
                    .font(DS.Typography.eyebrow)
                    .foregroundStyle(Color.appTint)
                Text(choice.title)
                    .font(.kanitMedium(16))
                    .foregroundStyle(.primary)
                if let subtitle = choice.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.kanit(12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Map(
                initialPosition: .region(
                    MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
                    )
                ),
                interactionModes: []
            ) {
                Marker("Your stay", coordinate: coordinate)
                    .tint(Color.appTint)
            }
            .frame(height: 145)
            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .allowsHitTesting(false)
            .accessibilityLabel("Map preview of \(choice.title)")

            Button("Use this location") {
                onChooseResolution(choice)
            }
            .buttonStyle(PrimaryButtonStyle(fullWidth: true))

            HStack {
                if canReturnToChoices {
                    Button("Back to matches") { ambiguousPreview = nil }
                }
                Spacer()
                Button("Adjust on map") {
                    openLocationPicker(around: choice)
                }
            }
            .font(.kanitMedium(13))
            .foregroundStyle(Color.appTint)

            Text("Your exact address is used for this search. Only the approximate area is saved.")
                .font(.kanit(11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func groundedContent(accommodation: CoarseAccommodation) -> some View {
        switch result {
        case .initial:
            VStack(spacing: .Spacing.small) {
                Image(systemName: "location.magnifyingglass")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text("Ready to check around \(accommodation.label)")
                    .font(DS.Typography.sectionHeader)
                    .multilineTextAlignment(.center)
                Text("This saved stay has no Near You result yet. Nothing will be generated until you ask.")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Find places", action: onRegenerate)
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false, internalPadding: 8))
                Button("Change stay", action: onChangeStay)
                    .font(.kanitMedium(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .Padding.md)
            .padding(.top, .Padding.md3)
            Spacer()

        case .loading:
            VStack(spacing: .Spacing.small) {
                ProgressView()
                Text("Let’s ask your local host, he knows the area very well.")
                    .font(DS.Typography.tabLabel)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, .Padding.md3)
            Spacer()

        case .error:
            VStack(spacing: .Spacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Color.appTint)
                Text("Near You didn't come through")
                    .font(DS.Typography.sectionHeader)
                Text(isGroup
                     ? "The shared result was not changed. The rest of the group trip is unaffected."
                     : "Your stay stays on this device. The rest of the trip is unaffected.")
                    .font(.kanit(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again", action: onRetryNearYou)
                    .buttonStyle(SecondaryButtonStyle(fullWidth: false, internalPadding: 8))
                Button("Change stay", action: onChangeStay)
                    .font(.kanitMedium(14))
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, .Padding.md)
            .padding(.top, .Padding.md3)
            Spacer()

        case .loaded(let output):
            NearYouResultsView(
                output: output,
                accommodation: accommodation,
                isGroup: isGroup,
                setBy: setBy,
                canReplace: canReplace,
                favorites: $favorites,
                onChangeStay: onChangeStay
            )
        }
    }

    private func submitAddress() {
        guard !trimmedAddress.isEmpty else { return }
        isAddressFocused = false
        addressCompleter.clear()
        ambiguousPreview = nil
        if let selectedSuggestion {
            onSearchSuggestion(selectedSuggestion)
        } else {
            onSearchAddress(trimmedAddress)
        }
    }

    private func openLocationPicker(around choice: NearYouResolutionChoice? = nil) {
        if let choice {
            mapPickerInitialCoordinate = NearYouCoordinate(
                latitude: choice.centre.latitude,
                longitude: choice.centre.longitude
            )
        } else {
            mapPickerInitialCoordinate = nil
        }
        isAddressFocused = false
        addressCompleter.clear()
        showsLocationPicker = true
    }
}

private struct NearYouResultsView: View {
    let output: Trip.NearYou
    let accommodation: CoarseAccommodation
    let isGroup: Bool
    let setBy: String?
    let canReplace: Bool
    @Binding var favorites: Trip.Favorites
    let onChangeStay: () -> Void

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: .Padding.md) {
                header

                if let sparse = output.sparseMessage {
                    Label(sparse, systemImage: "leaf")
                        .font(.kanit(14))
                        .foregroundStyle(.secondary)
                        .padding(.Padding.sm3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall)
                                .fill(Color.appTint.opacity(0.06))
                        )
                }

                ForEach(output.sections) { section in
                    editorialSection(section)
                }

                if !output.liveFinds.isEmpty {
                    liveFindLayer
                }

                if output.sections.isEmpty && output.liveFinds.isEmpty {
                    Text("The live search and Apple Maps did not surface enough trustworthy places for an editorial list. The practical results below are everything MapKit could verify.")
                        .font(DS.Typography.generatedBody)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                practicalLayer

                if canReplace {
                    Button(isGroup ? "Change shared stay" : "Change stay", action: onChangeStay)
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true, internalPadding: 8))
                        .padding(.top, .Padding.sm)
                } else if isGroup {
                    Label("This shared Near You result can no longer be changed.", systemImage: "checkmark.seal")
                        .font(.kanit(14))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, .Padding.sm)
                }
            }
            .padding(.horizontal, .Padding.sm3)
            .padding(.vertical, .Padding.md)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Near \(accommodation.label)")
                .font(DS.Typography.sectionHeader)
            if accommodation.precision == .neighbourhood {
                Label(
                    "Neighbourhood centre — all distances and walking times are approximate.",
                    systemImage: "scope"
                )
                .font(.kanit(13))
                .foregroundStyle(Color.appTint)
            } else {
                Text("Walking facts come directly from Apple Maps.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
            if isGroup, let setBy {
                Text("Shared by \(setBy)")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func editorialSection(_ section: Trip.NearYouSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(DS.Typography.sectionHeader)
            ForEach(section.picks) { pick in
                NearYouPlaceCard(
                    candidate: pick.candidate,
                    explanation: pick.explanation,
                    precision: accommodation.precision,
                    isHeartable: true,
                    isFavorited: favorites.contains(pick.id),
                    onHeart: { favorites.toggle(pick.id) }
                )
            }
        }
    }

    private var liveFindLayer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Label("Fresh local finds", systemImage: "sparkle.magnifyingglass")
                    .font(DS.Typography.sectionHeader)
                Text("Current web research, chosen for you. These may include temporary places or events that are not Apple Maps POIs.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }

            ForEach(output.liveFinds) { find in
                NearYouLiveFindCard(
                    find: find,
                    isFavorited: favorites.contains(find.id),
                    onHeart: { favorites.toggle(find.id) }
                )
            }
        }
    }

    private var practicalLayer: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Practical, no editorialising")
                    .font(DS.Typography.sectionHeader)
                Text("Nearest transport, grocery and pharmacy from Apple Maps only.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }

            ForEach(output.practical) { item in
                NearYouPlaceCard(
                    candidate: item.candidate,
                    explanation: item.kind.title,
                    precision: accommodation.precision,
                    isHeartable: false,
                    isFavorited: false,
                    onHeart: nil
                )
            }

            ForEach(
                Trip.NearYouPracticalKind.allCases.filter {
                    output.unavailablePracticalKinds.contains($0)
                },
                id: \.self
            ) { kind in
                Text("No \(kind.title.lowercased()) result with a verified walking route.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.Padding.sm3)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                .fill(.thinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardLarge, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }
}

private struct NearYouLiveFindCard: View {
    let find: Trip.NearYouLiveFind
    let isFavorited: Bool
    let onHeart: () -> Void

    private var mapSearchURL: URL {
        var components = URLComponents(string: "https://maps.apple.com/")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(find.name), \(find.locationHint)")
        ]
        return components.url!
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(find.name)
                        .font(DS.Typography.generatedTitle)
                    Text(find.category)
                        .font(.kanit(12))
                        .foregroundStyle(Color.appTint)
                }
                Spacer(minLength: 8)
                Button(action: onHeart) {
                    HeartIcon(size: 18, isFavorited: isFavorited)
                }
                .accessibilityLabel(isFavorited ? "Remove from favourites" : "Add to favourites")
            }

            Text(find.explanation)
                .font(DS.Typography.generatedBody)
                .fixedSize(horizontal: false, vertical: true)

            if let accessNote = find.accessNote {
                Label(accessNote, systemImage: "signpost.right.and.left")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Link(destination: find.sourceURL) {
                    Label(find.sourceTitle, systemImage: "safari")
                        .lineLimit(1)
                }
                Link(destination: mapSearchURL) {
                    Label("Find in Maps", systemImage: "map")
                }
            }
            .font(.kanitMedium(13))
            .foregroundStyle(Color.appTint)
        }
        .padding(.Padding.sm3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .fill(Color.appTint.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .stroke(Color.appTint.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct NearYouPlaceCard: View {
    let candidate: Trip.NearYouCandidate
    let explanation: String
    let precision: CoarseAccommodation.Precision
    let isHeartable: Bool
    let isFavorited: Bool
    let onHeart: (() -> Void)?

    private var facts: NearYouWalkingFacts {
        .make(candidate: candidate, precision: precision)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Link(destination: candidate.mapURL) {
                    HStack(spacing: 5) {
                        Text(candidate.name)
                            .font(DS.Typography.generatedTitle)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "map")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(Color.appTint)
                }

                Spacer(minLength: 8)

                if isHeartable, let onHeart {
                    Button(action: onHeart) {
                        HeartIcon(size: 18, isFavorited: isFavorited)
                    }
                    .accessibilityLabel(isFavorited ? "Remove from favourites" : "Add to favourites")
                }
            }

            Text(explanation)
                .font(DS.Typography.generatedBody)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Label(facts.distance, systemImage: "figure.walk")
                Text("·")
                Text(facts.duration)
            }
            .font(.kanitMedium(13))
            .foregroundStyle(.secondary)
            .accessibilityLabel(
                facts.isApproximate
                    ? "Approximate distance \(facts.distance), \(facts.duration)"
                    : "Distance \(facts.distance), \(facts.duration)"
            )
        }
        .padding(.Padding.sm3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat.Radius.cardSmall, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}
