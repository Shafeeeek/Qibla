import Foundation

struct PrayerTime: Identifiable, Hashable, Sendable {
    let id:     String
    let name:   String
    let time:   String   // Localised Arabic time string (e.g. "٤:٣٢ ص")
    let date:   Date     // Actual Date for next-prayer comparison
    var isNext: Bool

    // MARK: - Preview / Fallback Data
    static let sampleDay: [PrayerTime] = {
        let start = Calendar.current.startOfDay(for: Date())
        let fmt   = DateFormatter()
        fmt.locale    = Locale(identifier: "ar")
        fmt.timeStyle = .short
        let entries: [(String, Double)] = [
            ("الفجر",  4.5),
            ("الشروق", 6.0),
            ("الظهر",  12.0),
            ("العصر",  15.5),
            ("المغرب", 18.2),
            ("العشاء", 19.7)
        ]
        return entries.map { name, h in
            let d = start.addingTimeInterval(h * 3_600)
            return PrayerTime(id: name, name: name, time: fmt.string(from: d), date: d, isNext: false)
        }
    }()
}
