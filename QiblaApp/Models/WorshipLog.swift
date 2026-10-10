import Foundation
import SwiftData

// MARK: - WorshipLog

/// Daily worship log tracking prayer attendance, azkar, and Quran reading.
@Model
final class WorshipLog {
    var id: UUID
    var date: Date          // normalised to start-of-day

    // Prayers — true = prayed on time
    var fajrOnTime:    Bool
    var dhuhrOnTime:   Bool
    var asrOnTime:     Bool
    var maghribOnTime: Bool
    var ishaOnTime:    Bool

    // Azkar
    var morningAzkar:  Bool
    var eveningAzkar:  Bool

    // Quran
    var quranPages: Int

    init(
        id: UUID = UUID(),
        date: Date = .now,
        fajrOnTime: Bool = false,
        dhuhrOnTime: Bool = false,
        asrOnTime: Bool = false,
        maghribOnTime: Bool = false,
        ishaOnTime: Bool = false,
        morningAzkar: Bool = false,
        eveningAzkar: Bool = false,
        quranPages: Int = 0
    ) {
        self.id            = id
        self.date          = Calendar.current.startOfDay(for: date)
        self.fajrOnTime    = fajrOnTime
        self.dhuhrOnTime   = dhuhrOnTime
        self.asrOnTime     = asrOnTime
        self.maghribOnTime = maghribOnTime
        self.ishaOnTime    = ishaOnTime
        self.morningAzkar  = morningAzkar
        self.eveningAzkar  = eveningAzkar
        self.quranPages    = quranPages
    }

    // MARK: Computed

    /// Number of prayers completed on time today (0-5).
    var prayersOnTimeCount: Int {
        [fajrOnTime, dhuhrOnTime, asrOnTime, maghribOnTime, ishaOnTime]
            .filter { $0 }.count
    }

    /// Ratio of prayers done on time (0.0 – 1.0).
    var prayerRatio: Double {
        Double(prayersOnTimeCount) / 5.0
    }

    /// Overall daily score (0.0 – 1.0): 70% prayers + 20% azkar + 10% quran.
    var dailyScore: Double {
        let prayerScore = prayerRatio * 0.7
        let azkarScore  = (morningAzkar && eveningAzkar ? 1.0 : morningAzkar || eveningAzkar ? 0.5 : 0.0) * 0.2
        let quranScore  = min(Double(quranPages) / 5.0, 1.0) * 0.1
        return prayerScore + azkarScore + quranScore
    }

    /// Returns the prayer status array for chart display.
    var prayerStatuses: [(name: String, done: Bool)] {
        [
            ("الفجر",  fajrOnTime),
            ("الظهر",  dhuhrOnTime),
            ("العصر",  asrOnTime),
            ("المغرب", maghribOnTime),
            ("العشاء", ishaOnTime)
        ]
    }
}
