import Foundation
import CoreLocation
import Observation
import WidgetKit

// MARK: - AppState

/// Central observable state for the app.
/// Owns LocationManager, triggers calculations when the coordinate changes,
/// syncs data with the Widget App Group, and manages prayer and tip notifications.
@MainActor
@Observable
final class AppState {

    // MARK: Dependencies
    let locationManager = LocationManager()

    // MARK: Settings (persisted in UserDefaults)
    var calculationMethod: CalculationMethod = .egyptian {
        didSet {
            UserDefaults.standard.set(calculationMethod.rawValue, forKey: "calculationMethod")
            UserDefaults(suiteName: "group.com.shafeek.qibla")?.set(calculationMethod.rawValue, forKey: "calculationMethod")
            WidgetCenter.shared.reloadAllTimelines()
            refresh()
        }
    }

    var tipsNotificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(tipsNotificationsEnabled, forKey: "tipsNotificationsEnabled")
        }
    }

    var prayerNotificationsEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(prayerNotificationsEnabled, forKey: "prayerNotificationsEnabled")
        }
    }

    var preAdhanRemindersEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(preAdhanRemindersEnabled, forKey: "preAdhanRemindersEnabled")
        }
    }

    var showNotificationPermissionAlert: Bool = false

    // MARK: Results
    var prayerTimeItems: [PrayerTime] = []
    var qiblaInfo:       QiblaInfo?
    var hijriDateString: String = ""

    // MARK: Init

    init() {
        // Restore previously saved calculation method
        if let raw    = UserDefaults.standard.string(forKey: "calculationMethod"),
           let method = CalculationMethod(rawValue: raw) {
            calculationMethod = method
        } else {
            calculationMethod = .egyptian
        }

        // Restore notification settings (with fallback to legacy key)
        let legacyTips = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        tipsNotificationsEnabled = UserDefaults.standard.object(forKey: "tipsNotificationsEnabled") != nil
            ? UserDefaults.standard.bool(forKey: "tipsNotificationsEnabled")
            : legacyTips
        prayerNotificationsEnabled = UserDefaults.standard.bool(forKey: "prayerNotificationsEnabled")
        preAdhanRemindersEnabled = UserDefaults.standard.bool(forKey: "preAdhanRemindersEnabled")

        // Sync default calculation method to App Group
        UserDefaults(suiteName: "group.com.shafeek.qibla")?.set(calculationMethod.rawValue, forKey: "calculationMethod")

        // Reschedule tips if enabled
        if tipsNotificationsEnabled {
            NotificationService.shared.scheduleDailyTips()
        }

        // Reschedule pre-adhan reminders if enabled (and we have prayer times)
        // Will be properly scheduled once location is available and refresh() runs

        observeCoordinateChanges()
        scheduleMidnightRefresh()
    }

    // MARK: Notification Actions

    func setTipsNotifications(enabled: Bool) {
        if enabled {
            NotificationService.shared.requestPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.tipsNotificationsEnabled = true
                        NotificationService.shared.scheduleDailyTips()
                    } else {
                        self.tipsNotificationsEnabled = false
                        self.showNotificationPermissionAlert = true
                    }
                }
            }
        } else {
            tipsNotificationsEnabled = false
            NotificationService.shared.cancelDailyTips()
        }
    }

    func setPrayerNotifications(enabled: Bool) {
        if enabled {
            NotificationService.shared.requestPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.prayerNotificationsEnabled = true
                        NotificationService.shared.schedulePrayerNotifications(items: self.prayerTimeItems)
                    } else {
                        self.prayerNotificationsEnabled = false
                        self.showNotificationPermissionAlert = true
                    }
                }
            }
        } else {
            prayerNotificationsEnabled = false
            NotificationService.shared.cancelPrayerNotifications()
        }
    }

    func setPreAdhanReminders(enabled: Bool) {
        if enabled {
            NotificationService.shared.requestPermission { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if granted {
                        self.preAdhanRemindersEnabled = true
                        NotificationService.shared.schedulePreAdhanReminders(items: self.prayerTimeItems)
                    } else {
                        self.preAdhanRemindersEnabled = false
                        self.showNotificationPermissionAlert = true
                    }
                }
            }
        } else {
            preAdhanRemindersEnabled = false
            NotificationService.shared.cancelPreAdhanReminders()
        }
    }

    // MARK: Public API

    func startLocationUpdates() {
        locationManager.requestPermission()
        locationManager.startUpdates()
    }

    func refresh() {
        guard let coord = locationManager.coordinate else { return }
        
        // Sync coordinates & city with App Group for Widget
        if let sharedDefaults = UserDefaults(suiteName: "group.com.shafeek.qibla") {
            sharedDefaults.set(coord.latitude, forKey: "latitude")
            sharedDefaults.set(coord.longitude, forKey: "longitude")
            sharedDefaults.set(calculationMethod.rawValue, forKey: "calculationMethod")
            if !locationManager.cityName.isEmpty {
                sharedDefaults.set(locationManager.cityName, forKey: "cityName")
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
        
        qiblaInfo       = QiblaCalculator.calculate(from: coord)
        let raw         = PrayerCalculator(coordinate: coord, method: calculationMethod).calculate()
        prayerTimeItems = buildPrayerItems(from: raw)
        hijriDateString = makeHijriString()

        // If prayer notifications are enabled, reschedule for upcoming times
        if prayerNotificationsEnabled {
            NotificationService.shared.schedulePrayerNotifications(items: prayerTimeItems)
        }

        // If pre-adhan reminders are enabled, reschedule for upcoming times
        if preAdhanRemindersEnabled {
            NotificationService.shared.schedulePreAdhanReminders(items: prayerTimeItems)
        }
    }

    // MARK: Private — observation

    /// Re-registers observation tracking every time `coordinate` changes,
    /// so `refresh()` is called automatically on every new GPS fix.
    private func observeCoordinateChanges() {
        withObservationTracking {
            _ = locationManager.coordinate
            _ = locationManager.cityName
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refresh()
                self?.observeCoordinateChanges()
            }
        }
    }

    // MARK: Private — midnight refresh

    /// Schedules a Task that sleeps until local midnight and then refreshes
    /// prayer times (which change daily) and reschedules itself.
    private func scheduleMidnightRefresh() {
        Task { @MainActor [weak self] in
            let now      = Date()
            let tomorrow = Calendar.current.startOfDay(for: now.addingTimeInterval(86_400))
            let interval = tomorrow.timeIntervalSince(now)
            guard interval > 0 else { return }
            try? await Task.sleep(for: .seconds(interval))
            self?.refresh()
            self?.scheduleMidnightRefresh()
        }
    }

    // MARK: Private — helpers

    private func buildPrayerItems(from raw: RawPrayerTimes) -> [PrayerTime] {
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale    = Locale(identifier: "ar")
        fmt.timeStyle = .short
        fmt.dateStyle = .none

        let pairs: [(String, Date)] = [
            ("الفجر",   raw.fajr),
            ("الشروق",  raw.sunrise),
            ("الظهر",   raw.dhuhr),
            ("العصر",   raw.asr),
            ("المغرب",  raw.maghrib),
            ("العشاء",  raw.isha)
        ]

        let nextDate = pairs.first { $0.1 > now }?.1

        return pairs.map { name, date in
            PrayerTime(
                id:     name,
                name:   name,
                time:   fmt.string(from: date),
                date:   date,
                isNext: nextDate != nil && date == nextDate
            )
        }
    }

    private func makeHijriString() -> String {
        let fmt = DateFormatter()
        fmt.locale    = Locale(identifier: "ar")
        fmt.calendar  = Calendar(identifier: .islamicUmmAlQura)
        fmt.dateStyle = .long
        fmt.timeStyle = .none
        return fmt.string(from: Date())
    }
}
