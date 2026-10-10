import Foundation
import CoreLocation
import Observation

// MARK: - LocationManager

/// Manages GPS coordinates, compass heading, and reverse geocoding.
/// All published properties are updated on the main actor.
@MainActor
@Observable
final class LocationManager: NSObject {

    // MARK: Published State
    var coordinate: CLLocationCoordinate2D?
    var cityName: String = ""
    var countryName: String = ""
    var compassHeading: Double = 0
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var locationError: String?

    // MARK: Private
    private let clManager = CLLocationManager()
    private let geocoder  = CLGeocoder()
    private var lastGeocodedLocation: CLLocation?

    override init() {
        super.init()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        clManager.headingFilter   = 2          // fire only on ≥2° change
        authorizationStatus       = clManager.authorizationStatus

        // Auto-start if we're already authorised from a previous session
        if authorizationStatus == .authorizedWhenInUse ||
           authorizationStatus == .authorizedAlways {
            startUpdates()
        }
    }

    // MARK: Public API

    func requestPermission() {
        guard authorizationStatus == .notDetermined else { return }
        clManager.requestWhenInUseAuthorization()
    }

    func startUpdates() {
        clManager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            clManager.startUpdatingHeading()
        }
    }

    // MARK: Internal Handlers (called from nonisolated delegate)

    fileprivate func handleCoordinate(_ coordinate: CLLocationCoordinate2D,
                                      accuracy: CLLocationAccuracy,
                                      rawLocation: CLLocation) {
        guard accuracy >= 0 else { return }
        self.coordinate = coordinate
        geocodeIfNeeded(rawLocation)
    }

    /// Called with pre-extracted scalar values so that no non-Sendable CLHeading
    /// object crosses the actor boundary (fixes Swift 6 data-race warning).
    fileprivate func handleHeading(trueHeading: Double, magneticHeading: Double) {
        compassHeading = trueHeading >= 0 ? trueHeading : magneticHeading
    }

    fileprivate func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            startUpdates()
        }
    }

    fileprivate func handleError(_ error: Error) {
        locationError = error.localizedDescription
    }

    // MARK: Geocoding

    private func geocodeIfNeeded(_ location: CLLocation) {
        // Skip if we've already geocoded this area recently
        if let last = lastGeocodedLocation, location.distance(from: last) < 5_000 { return }
        lastGeocodedLocation = location

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self, let p = placemarks?.first else { return }
            Task { @MainActor in
                self.cityName    = p.locality ?? p.administrativeArea ?? ""
                self.countryName = p.country ?? ""
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        // Extract Sendable values before crossing the @MainActor boundary.
        guard let loc = locations.last, loc.horizontalAccuracy >= 0 else { return }
        let coord    = loc.coordinate          // CLLocationCoordinate2D — plain C struct, Sendable
        let accuracy = loc.horizontalAccuracy  // Double — Sendable
        Task { @MainActor [weak self] in self?.handleCoordinate(coord, accuracy: accuracy, rawLocation: loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateHeading newHeading: CLHeading) {
        // Extract Doubles here so CLHeading never crosses the actor boundary.
        let trueH = newHeading.trueHeading
        let magH  = newHeading.magneticHeading
        Task { @MainActor [weak self] in self?.handleHeading(trueHeading: trueH, magneticHeading: magH) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor [weak self] in self?.handleAuthorizationChange(status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor [weak self] in self?.handleError(error) }
    }
}
