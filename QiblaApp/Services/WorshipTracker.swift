import Foundation
import SwiftData

// MARK: - WeekdayStats

struct WeekdayStats: Identifiable {
    let id: Int          // 0 = Saturday … 6 = Friday (Arabic week)
    let dayLabel: String
    let log: WorshipLog?

    var prayersCount: Int { log?.prayersOnTimeCount ?? 0 }
    var dailyScore: Double { log?.dailyScore ?? 0 }
}

// MARK: - MonthlyOverview

struct MonthlyOverview {
    let totalDays: Int
    let loggedDays: Int
    let avgPrayerRatio: Double
    let totalQuranPages: Int
    let azkarDays: Int
    let currentStreak: Int
}

// MARK: - WorshipTracker

/// Manages worship log entries — writing, reading, and computing statistics.
@MainActor
@Observable
final class WorshipTracker {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Today's Log

    /// Returns today's log, creating one if it doesn't exist yet.
    func todayLog() -> WorshipLog {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        if let existing = fetchLog(for: startOfDay) {
            return existing
        }
        let newLog = WorshipLog(date: startOfDay)
        modelContext.insert(newLog)
        try? modelContext.save()
        return newLog
    }

    func save() {
        try? modelContext.save()
    }

    // MARK: - Fetch

    private func fetchLog(for date: Date) -> WorshipLog? {
        let start = Calendar.current.startOfDay(for: date)
        let end   = start.addingTimeInterval(86_400)
        var descriptor = FetchDescriptor<WorshipLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    func fetchLogs(from startDate: Date, to endDate: Date) -> [WorshipLog] {
        let start = Calendar.current.startOfDay(for: startDate)
        let end   = Calendar.current.startOfDay(for: endDate).addingTimeInterval(86_400)
        let descriptor = FetchDescriptor<WorshipLog>(
            predicate: #Predicate { $0.date >= start && $0.date < end },
            sortBy: [SortDescriptor(\.date)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Weekly Stats

    func weeklyStats() -> [WeekdayStats] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        // Find the start of the current week (Saturday in Arabic locale)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSaturday = (weekday + 1) % 7 // Saturday = 7 → 0
        guard let weekStart = calendar.date(byAdding: .day, value: -daysFromSaturday, to: today) else {
            return []
        }

        let logs = fetchLogs(from: weekStart, to: today)
        let arabicDays = ["سبت", "أحد", "إثنين", "ثلاثاء", "أربعاء", "خميس", "جمعة"]

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
            let dayStart = calendar.startOfDay(for: date)
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
            return WeekdayStats(id: offset, dayLabel: arabicDays[offset], log: log)
        }
    }

    // MARK: - Monthly Heatmap

    func monthlyHeatmap() -> [(date: Date, score: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let monthStart = calendar.date(byAdding: .day, value: -29, to: today) else {
            return []
        }

        let logs = fetchLogs(from: monthStart, to: today)

        return (0..<30).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: monthStart)!
            let log = logs.first { calendar.isDate($0.date, inSameDayAs: date) }
            return (date: date, score: log?.dailyScore ?? 0)
        }
    }

    // MARK: - Monthly Overview

    func monthlyOverview() -> MonthlyOverview {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let monthStart = calendar.date(byAdding: .day, value: -29, to: today) else {
            return MonthlyOverview(totalDays: 30, loggedDays: 0, avgPrayerRatio: 0, totalQuranPages: 0, azkarDays: 0, currentStreak: 0)
        }

        let logs = fetchLogs(from: monthStart, to: today)

        let loggedDays = logs.count
        let avgPrayer  = logs.isEmpty ? 0 : logs.reduce(0.0) { $0 + $1.prayerRatio } / Double(logs.count)
        let quranPages = logs.reduce(0) { $0 + $1.quranPages }
        let azkarDays  = logs.filter { $0.morningAzkar || $0.eveningAzkar }.count

        return MonthlyOverview(
            totalDays: 30,
            loggedDays: loggedDays,
            avgPrayerRatio: avgPrayer,
            totalQuranPages: quranPages,
            azkarDays: azkarDays,
            currentStreak: currentStreak()
        )
    }

    // MARK: - Streak

    func currentStreak() -> Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        while true {
            guard let log = fetchLog(for: checkDate), log.prayersOnTimeCount >= 3 else {
                break
            }
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }

        return streak
    }

    // MARK: - Demo Data

    func insertDemoDataIfEmpty() {
        let today = Calendar.current.startOfDay(for: .now)
        guard fetchLog(for: today) == nil else { return }

        let calendar = Calendar.current

        // Insert sample data for the past 14 days
        for offset in stride(from: -13, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let log = WorshipLog(date: date)
            let rand = { Bool.random() }
            log.fajrOnTime    = rand()
            log.dhuhrOnTime   = true       // assume most people catch dhuhr
            log.asrOnTime     = rand()
            log.maghribOnTime = true
            log.ishaOnTime    = rand()
            log.morningAzkar  = rand()
            log.eveningAzkar  = rand()
            log.quranPages    = Int.random(in: 0...5)
            modelContext.insert(log)
        }
        try? modelContext.save()
    }
}
