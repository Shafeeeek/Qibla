import Foundation
import CoreLocation

// MARK: - QiblaInfo

struct QiblaInfo: Equatable, Sendable {
    /// Bearing from True North, clockwise (0–360°)
    let bearing: Double
    /// Great-circle distance to the Kaaba in kilometres
    let distanceKm: Double
}

// MARK: - QiblaCalculator

/// Pure, offline calculation of the Qibla direction and distance to Mecca.
enum QiblaCalculator {

    // Kaaba (Al-Masjid Al-Haram) coordinates
    private static let kaabaLat: Double = 21.4225
    private static let kaabaLon: Double = 39.8262
    private static let earthRadiusKm: Double = 6_371.0

    /// Calculate Qibla bearing and distance from `coordinate`.
    static func calculate(from coordinate: CLLocationCoordinate2D) -> QiblaInfo {
        let φ1 = coordinate.latitude.rad
        let λ1 = coordinate.longitude.rad
        let φ2 = kaabaLat.rad
        let λ2 = kaabaLon.rad
        let Δλ = λ2 - λ1

        // Forward azimuth (bearing) — standard spherical formula
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let bearing = (atan2(y, x).deg + 360).truncatingRemainder(dividingBy: 360)

        // Haversine great-circle distance
        let Δφ = φ2 - φ1
        let a  = sin(Δφ/2) * sin(Δφ/2) + cos(φ1) * cos(φ2) * sin(Δλ/2) * sin(Δλ/2)
        let distanceKm = earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a))

        return QiblaInfo(bearing: bearing, distanceKm: distanceKm)
    }
}

// MARK: - Helpers

private extension Double {
    var rad: Double { self * .pi / 180 }
    var deg: Double { self * 180 / .pi }
}
