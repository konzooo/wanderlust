//
//  NearYouLocationPicker.swift
//  Wanderlust
//
//  Address-independent accommodation selection. The exact coordinate exists
//  only for the current Near You search; CoarseAccommodation rounds it before
//  anything can be persisted or shared.
//

import CoreLocation
import CoreModels
import DesignSystem
import MapKit
import SwiftUI

struct NearYouCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var mapCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var isValid: Bool {
        CLLocationCoordinate2DIsValid(mapCoordinate)
            && latitude.isFinite
            && longitude.isFinite
            && !(latitude == 0 && longitude == 0)
    }
}

enum NearYouPinnedLocation {
    static func choice(
        coordinate: NearYouCoordinate,
        destination: String
    ) -> NearYouResolutionChoice {
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationLabel = trimmedDestination.isEmpty ? "your destination" : trimmedDestination
        return NearYouResolutionChoice(
            title: "Pinned stay",
            subtitle: destinationLabel,
            centre: NearYouSearchCentre(
                accommodation: CoarseAccommodation(
                    label: "Your stay in \(destinationLabel)",
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    precision: .address
                ),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                researchArea: destinationLabel
            )
        )
    }
}

@MainActor
private final class NearYouCurrentLocationProvider: NSObject, ObservableObject {
    @Published private(set) var coordinate: NearYouCoordinate?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private var hasUserRequestedLocation = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        hasUserRequestedLocation = true
        errorMessage = nil
        guard CLLocationManager.locationServicesEnabled() else {
            isLoading = false
            errorMessage = "Location Services are turned off. Move the map manually instead."
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            isLoading = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLoading = true
            manager.requestLocation()
        case .denied, .restricted:
            isLoading = false
            errorMessage = "Location access is off for Wanderlust. Move the map manually or enable it in Settings."
        @unknown default:
            isLoading = false
            errorMessage = "Your current location isn't available. Move the map manually instead."
        }
    }
}

extension NearYouCurrentLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard hasUserRequestedLocation else { return }
            switch status {
            case .authorizedAlways, .authorizedWhenInUse:
                manager.requestLocation()
            case .denied, .restricted:
                isLoading = false
                errorMessage = "Location access is off for Wanderlust. Move the map manually or enable it in Settings."
            case .notDetermined:
                break
            @unknown default:
                isLoading = false
                errorMessage = "Your current location isn't available. Move the map manually instead."
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        let coordinate = NearYouCoordinate(location.coordinate)
        Task { @MainActor [weak self] in
            guard let self else { return }
            isLoading = false
            guard coordinate.isValid else {
                errorMessage = "Your current location isn't available. Move the map manually instead."
                return
            }
            self.coordinate = coordinate
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isLoading = false
            self?.errorMessage = "We couldn't get your current location. Move the map manually and place the pin."
        }
    }
}

struct NearYouLocationPicker: View {
    let destination: String
    let initialCoordinate: NearYouCoordinate?
    let onConfirm: (NearYouResolutionChoice) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var currentLocation = NearYouCurrentLocationProvider()
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var pinCoordinate: NearYouCoordinate?
    @State private var isPreparingMap = true
    @State private var preparationError: String?
    @State private var hasUserOverriddenInitialCenter = false

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition, interactionModes: .all)
                .mapControls {
                    MapCompass()
                    MapScaleView()
                }
                .overlay {
                    if isPreparingMap {
                        ProgressView("Centering on \(destination)…")
                            .font(.kanit(14))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    } else if pinCoordinate != nil {
                        centerPin
                    }
                }
                .onMapCameraChange(frequency: .continuous) { context in
                    guard !isPreparingMap else { return }
                    let coordinate = NearYouCoordinate(context.camera.centerCoordinate)
                    if coordinate.isValid {
                        pinCoordinate = coordinate
                    }
                }
                .onChange(of: currentLocation.coordinate) { _, coordinate in
                    guard let coordinate else { return }
                    hasUserOverriddenInitialCenter = true
                    moveMap(to: coordinate)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    controls
                }
                .navigationTitle("Choose your stay")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .font(.kanitMedium(16))
                    }
                }
        }
        .task { await prepareMap() }
    }

    private var centerPin: some View {
        VStack(spacing: 0) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.white, Color.appTint)
                .shadow(color: .black.opacity(0.28), radius: 5, y: 3)
            Circle()
                .fill(Color.black.opacity(0.20))
                .frame(width: 9, height: 4)
                .blur(radius: 1)
                .offset(y: -2)
        }
        .offset(y: -20)
        .accessibilityHidden(true)
    }

    private var controls: some View {
        VStack(spacing: 12) {
            VStack(spacing: 3) {
                Text("Place the pin where you're staying")
                    .font(.kanitMedium(18))
                    .foregroundStyle(.primary)
                Text("Move and zoom the map until the pin is on the right building or entrance.")
                    .font(.kanit(13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: currentLocation.requestLocation) {
                HStack(spacing: 8) {
                    if currentLocation.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "location.fill")
                    }
                    Text(currentLocation.isLoading ? "Finding your location…" : "Use my current location")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle(fullWidth: true, internalPadding: 9))
            .disabled(currentLocation.isLoading)

            if let message = currentLocation.errorMessage ?? preparationError {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.kanit(12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Confirm this location", action: confirm)
                .buttonStyle(PrimaryButtonStyle(fullWidth: true))
                .disabled(pinCoordinate == nil)

            Text("Your exact location is used for this search. Only the approximate area is saved.")
                .font(.kanit(11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, .Padding.md)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
    }

    private func prepareMap() async {
        if let initialCoordinate, initialCoordinate.isValid {
            moveMap(to: initialCoordinate)
            return
        }

        guard let destinationRegion = await MapKitNearYouService.searchRegion(for: destination) else {
            guard !hasUserOverriddenInitialCenter else { return }
            isPreparingMap = false
            preparationError = "We couldn't center the destination automatically. Use your current location or move the map manually."
            return
        }
        guard !hasUserOverriddenInitialCenter else { return }
        let coordinate = NearYouCoordinate(destinationRegion.center)
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate.mapCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        )
        pinCoordinate = coordinate
        isPreparingMap = false
    }

    private func moveMap(to coordinate: NearYouCoordinate) {
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate.mapCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
            )
        )
        pinCoordinate = coordinate
        isPreparingMap = false
        preparationError = nil
    }

    private func confirm() {
        guard let pinCoordinate else { return }
        onConfirm(
            NearYouPinnedLocation.choice(
                coordinate: pinCoordinate,
                destination: destination
            )
        )
        dismiss()
    }
}

#Preview("Location picker") {
    NearYouLocationPicker(
        destination: "Veliko Tarnovo, Bulgaria",
        initialCoordinate: NearYouCoordinate(latitude: 43.0757, longitude: 25.6172),
        onConfirm: { _ in }
    )
}
