import Foundation
import CoreLocation

// MARK: - CalculationMethod

/// The recognised Islamic prayer-time calculation authority.
enum CalculationMethod: String, CaseIterable, Identifiable, Sendable {
    case egyptian          = "الهيئة المصرية"
    case muslimWorldLeague = "رابطة العالم الإسلامي"
    case ummAlQura         = "أم القرى"
    case northAmerica      = "أمريكا الشمالية"

    var id: String { rawValue }

    /// Angle below the horizon that marks Fajr (°)
    var fajrAngle: Double {
        switch self {
        case .egyptian:           return 19.5
        case .muslimWorldLeague:  return 18.0
        case .ummAlQura:          return 18.5
        case .northAmerica:       return 15.0
        }
    }

    /// Angle below the horizon that marks Isha (nil → use fixed minutes instead)
    var ishaAngle: Double? {
        switch self {
        case .egyptian:           return 17.5
        case .muslimWorldLeague:  return 17.0
        case .northAmerica:       return 15.0
        case .ummAlQura:          return nil
        }
    }

    /// Fixed minutes after Maghrib for Isha (Umm al-Qura only)
    var ishaMinutesAfterMaghrib: Double { 90 }
}

// MARK: - RawPrayerTimes

struct RawPrayerTimes: Sendable {
    let fajr:    Date
    let sunrise: Date
    let dhuhr:   Date
    let asr:     Date
    let maghrib: Date
    let isha:    Date
}

// MARK: - PrayerCalculator

/// Offline astronomical prayer-time calculator.
///
/// Uses the USNO simplified solar position algorithm together with the
/// standard spherical-trigonometry hour-angle formula to derive prayer
/// times for any location on Earth without requiring an internet connection.
struct PrayerCalculator: Sendable {

    let coordinate:      CLLocationCoordinate2D
    let date:            Date
    let method:          CalculationMethod
    /// Shadow factor: 1 = Shāfiʿī / Mālikī / Ḥanbalī, 2 = Ḥanafī
    let asrShadowFactor: Double

    init(
        coordinate:      CLLocationCoordinate2D,
        date:            Date            = .now,
        method:          CalculationMethod = .egyptian,
        asrShadowFactor: Double          = 1
    ) {
        self.coordinate      = coordinate
        self.date            = date
        self.method          = method
        self.asrShadowFactor = asrShadowFactor
    }

    // MARK: Main entry point

    func calculate() -> RawPrayerTimes {
        let lat = coordinate.latitude
        let lng = coordinate.longitude
        let tz  = Double(TimeZone.current.secondsFromGMT(for: date)) / 3_600

        // Sun position at approximately local solar noon
        let jd            = julianDay(for: date)
        let (decl, eqTime) = sunPosition(jd: jd + 0.5)   // +0.5 ≈ noon UTC

        // Solar noon in local clock-hours
        let solarNoon = 12 - lng / 15 - eqTime + tz

        // Hour angle for a given altitude above/below horizon (degrees)
        func ha(altitude: Double) -> Double {
            let cosHA = (sin(altitude.rad) - sin(lat.rad) * sin(decl.rad))
                      / (cos(lat.rad) * cos(decl.rad))
            return acos(max(-1, min(1, cosHA))).deg
        }

        let haRise = ha(altitude: -0.833)               // sunrise / sunset
        let haFajr = ha(altitude: -method.fajrAngle)

        // Asr: altitude at which shadow length = factor * object height + noon shadow
        let asrAlt = atan(1 / (asrShadowFactor + tan(abs(lat - decl).rad))).deg
        let haAsr  = ha(altitude: asrAlt)

        let fajrH    = solarNoon - haFajr / 15
        let sunriseH = solarNoon - haRise  / 15
        let dhuhrH   = solarNoon + 1.0 / 60            // 1 min after solar noon
        let asrH     = solarNoon + haAsr  / 15
        let maghribH = solarNoon + haRise  / 15

        let ishaH: Double
        if let angle = method.ishaAngle {
            ishaH = solarNoon + ha(altitude: -angle) / 15
        } else {
            ishaH = maghribH + method.ishaMinutesAfterMaghrib / 60
        }

        let startOfDay = Calendar.current.startOfDay(for: date)
        func toDate(_ h: Double) -> Date { startOfDay.addingTimeInterval(h * 3_600) }

        return RawPrayerTimes(
            fajr:    toDate(fajrH),
            sunrise: toDate(sunriseH),
            dhuhr:   toDate(dhuhrH),
            asr:     toDate(asrH),
            maghrib: toDate(maghribH),
            isha:    toDate(ishaH)
        )
    }

    // MARK: Solar position (USNO simplified algorithm)

    /// Returns `(declination°, equationOfTime_hours)` for the given Julian Day.
    private func sunPosition(jd: Double) -> (decl: Double, eqTime: Double) {
        let d = jd - 2_451_545.0                          // days since J2000.0
        let g = (357.529 + 0.985_600_28 * d).norm360      // mean anomaly
        let q = (280.459 + 0.985_647_36 * d).norm360      // mean longitude
        let L = (q + 1.915 * sin(g.rad) + 0.020 * sin((2*g).rad)).norm360
        let e = 23.439 - 0.000_000_36 * d                 // obliquity of ecliptic

        let ra   = atan2(cos(e.rad) * sin(L.rad), cos(L.rad)).deg.norm360
        let decl = asin(sin(e.rad) * sin(L.rad)).deg

        // Equation of time in hours, clamped to (−12, 12)
        var eqTime = (q - ra) / 15
        while eqTime >  12 { eqTime -= 24 }
        while eqTime < -12 { eqTime += 24 }

        return (decl, eqTime)
    }

    // MARK: Julian Day Number

    private func julianDay(for date: Date) -> Double {
        let cal   = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: date)
        var year  = Double(comps.year!), month = Double(comps.month!)
        let day   = Double(comps.day!)

        if month <= 2 { year -= 1; month += 12 }
        let a = floor(year / 100)
        let b = 2 - a + floor(a / 4)
        return floor(365.25 * (year + 4_716))
             + floor(30.6001 * (month + 1))
             + day + b - 1_524.5
    }
}

// MARK: - Private extensions

private extension Double {
    var rad:     Double { self * .pi / 180 }
    var deg:     Double { self * 180 / .pi }
    var norm360: Double {
        let r = truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }
}
