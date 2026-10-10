import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {
    let date: Date
    let nextPrayer: PrayerTime?
    let allPrayers: [PrayerTime]
    let cityName: String
    let hijriDate: String
    let hasLocation: Bool
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            nextPrayer: PrayerTime(id: "الظهر", name: "الظهر", time: "١٢:٠٥ م", date: Date().addingTimeInterval(3600), isNext: true),
            allPrayers: PrayerTime.sampleDay,
            cityName: "مكة المكرمة",
            hijriDate: "١٤٤٧ هـ",
            hasLocation: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let entry = makeCurrentEntry(for: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> Void) {
        let (entries, refreshDate) = generateEntries(startingAt: Date())
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }

    // MARK: - Entry Generators

    private func makeCurrentEntry(for date: Date) -> SimpleEntry {
        let shared = UserDefaults(suiteName: "group.com.shafeek.qibla")
        let lat = shared?.double(forKey: "latitude") ?? 0
        let lon = shared?.double(forKey: "longitude") ?? 0
        let cityName = shared?.string(forKey: "cityName") ?? ""
        let hijri = makeHijriString(from: date)

        guard lat != 0 && lon != 0 else {
            return SimpleEntry(
                date: date,
                nextPrayer: nil,
                allPrayers: [],
                cityName: cityName,
                hijriDate: hijri,
                hasLocation: false
            )
        }

        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let methodRaw = shared?.string(forKey: "calculationMethod") ?? CalculationMethod.egyptian.rawValue
        let method = CalculationMethod(rawValue: methodRaw) ?? .egyptian

        let todayRaw = PrayerCalculator(coordinate: coord, date: date, method: method).calculate()
        let todayPrayers = buildPrayers(from: todayRaw)
        let next = findNextPrayer(from: todayPrayers, after: date)

        return SimpleEntry(
            date: date,
            nextPrayer: next,
            allPrayers: todayPrayers,
            cityName: cityName,
            hijriDate: hijri,
            hasLocation: true
        )
    }

    private func generateEntries(startingAt now: Date) -> ([SimpleEntry], Date) {
        let shared = UserDefaults(suiteName: "group.com.shafeek.qibla")
        let lat = shared?.double(forKey: "latitude") ?? 0
        let lon = shared?.double(forKey: "longitude") ?? 0
        let cityName = shared?.string(forKey: "cityName") ?? ""

        guard lat != 0 && lon != 0 else {
            let entry = SimpleEntry(
                date: now,
                nextPrayer: nil,
                allPrayers: [],
                cityName: cityName,
                hijriDate: makeHijriString(from: now),
                hasLocation: false
            )
            let reloadDate = Calendar.current.date(byAdding: .minute, value: 30, to: now)!
            return ([entry], reloadDate)
        }

        let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        let methodRaw = shared?.string(forKey: "calculationMethod") ?? CalculationMethod.egyptian.rawValue
        let method = CalculationMethod(rawValue: methodRaw) ?? .egyptian

        // 1. Calculate today's and tomorrow's prayers
        let todayRaw = PrayerCalculator(coordinate: coord, date: now, method: method).calculate()
        let todayPrayers = buildPrayers(from: todayRaw)

        let tomorrowDate = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let tomorrowRaw = PrayerCalculator(coordinate: coord, date: tomorrowDate, method: method).calculate()
        let tomorrowPrayers = buildPrayers(from: tomorrowRaw)

        let allUpcoming = (todayPrayers + tomorrowPrayers).sorted { $0.date < $1.date }

        var entries: [SimpleEntry] = []

        // Entry 0: Right now
        let currentNext = findNextPrayer(from: allUpcoming, after: now)
        entries.append(
            SimpleEntry(
                date: now,
                nextPrayer: currentNext,
                allPrayers: todayPrayers,
                cityName: cityName,
                hijriDate: makeHijriString(from: now),
                hasLocation: true
            )
        )

        // Subsequent entries: at each prayer transition time
        for (index, prayer) in allUpcoming.enumerated() {
            guard prayer.date > now else { continue }
            // Once this prayer time arrives, next prayer becomes the following one
            let subsequentNext = (index + 1 < allUpcoming.count) ? allUpcoming[index + 1] : nil
            let hijriAtPrayer = makeHijriString(from: prayer.date)
            let isTomorrow = Calendar.current.isDate(prayer.date, inSameDayAs: tomorrowDate)
            let displayPrayers = isTomorrow ? tomorrowPrayers : todayPrayers

            entries.append(
                SimpleEntry(
                    date: prayer.date,
                    nextPrayer: subsequentNext,
                    allPrayers: displayPrayers,
                    cityName: cityName,
                    hijriDate: hijriAtPrayer,
                    hasLocation: true
                )
            )
        }

        let refreshDate = allUpcoming.last?.date ?? Calendar.current.date(byAdding: .day, value: 1, to: now)!
        return (entries, refreshDate)
    }

    private func findNextPrayer(from list: [PrayerTime], after date: Date) -> PrayerTime? {
        list.first { $0.date > date }
    }

    private func buildPrayers(from raw: RawPrayerTimes) -> [PrayerTime] {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ar")
        fmt.timeStyle = .short
        fmt.dateStyle = .none

        let pairs: [(String, Date)] = [
            ("الفجر", raw.fajr),
            ("الشروق", raw.sunrise),
            ("الظهر", raw.dhuhr),
            ("العصر", raw.asr),
            ("المغرب", raw.maghrib),
            ("العشاء", raw.isha)
        ]

        return pairs.map { name, date in
            PrayerTime(
                id: name,
                name: name,
                time: fmt.string(from: date),
                date: date,
                isNext: false
            )
        }
    }

    private func makeHijriString(from date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ar")
        fmt.calendar = Calendar(identifier: .islamicUmmAlQura)
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: date)
    }
}

// MARK: - Widget Views

struct QiblaWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            if !entry.hasLocation {
                NoLocationView()
            } else {
                switch family {
                case .systemSmall:
                    SmallWidgetView(entry: entry)
                case .systemMedium:
                    MediumWidgetView(entry: entry)
                default:
                    SmallWidgetView(entry: entry)
                }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - Small Widget

private struct SmallWidgetView: View {
    let entry: SimpleEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: City and Moon
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.20))
                        .font(.caption2)
                    Text(entry.cityName.isEmpty ? "قبلتي" : entry.cityName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }
                Spacer()
                Text(entry.hijriDate)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 2)

            if let next = entry.nextPrayer {
                VStack(alignment: .leading, spacing: 3) {
                    Text("الصلاة القادمة")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.44))

                    Text(next.name)
                        .font(.title2)
                        .fontWeight(.black)
                        .foregroundStyle(.white)

                    Text(next.time)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.20))

                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                        Text(next.date, style: .relative)
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.top, 2)
                }
            } else {
                Text("لا توجد صلوات قادمة")
                    .font(.caption)
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 2)
        }
    }
}

// MARK: - Medium Widget

private struct MediumWidgetView: View {
    let entry: SimpleEntry

    // Filter to show the main 5 prayers
    private var fivePrayers: [PrayerTime] {
        entry.allPrayers.filter { $0.name != "الشروق" }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left Card: Next Prayer Highlight
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.20))
                        .font(.caption2)
                    Text(entry.cityName.isEmpty ? "قبلتي" : entry.cityName)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                }

                Spacer()

                if let next = entry.nextPrayer {
                    Text("الصلاة القادمة")
                        .font(.caption2)
                        .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.44))

                    Text(next.name)
                        .font(.title)
                        .fontWeight(.black)
                        .foregroundStyle(.white)

                    Text(next.time)
                        .font(.title2)
                        .fontWeight(.heavy)
                        .foregroundStyle(Color(red: 0.96, green: 0.78, blue: 0.20))

                    HStack(spacing: 3) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                        Text(next.date, style: .relative)
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }

                Spacer()

                Text(entry.hijriDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)

            Divider()
                .background(Color.white.opacity(0.2))

            // Right Column: All 5 Prayers
            VStack(spacing: 4) {
                ForEach(fivePrayers) { prayer in
                    let isCurrentNext = entry.nextPrayer?.name == prayer.name
                    HStack {
                        Circle()
                            .fill(isCurrentNext ? Color(red: 0.96, green: 0.78, blue: 0.20) : Color.white.opacity(0.3))
                            .frame(width: 6, height: 6)

                        Text(prayer.name)
                            .font(.caption)
                            .fontWeight(isCurrentNext ? .bold : .regular)
                            .foregroundStyle(isCurrentNext ? .white : .white.opacity(0.8))

                        Spacer()

                        Text(prayer.time)
                            .font(.caption)
                            .fontWeight(isCurrentNext ? .bold : .regular)
                            .foregroundStyle(isCurrentNext ? Color(red: 0.96, green: 0.78, blue: 0.20) : .white.opacity(0.7))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        isCurrentNext
                            ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12))
                            : RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - No Location Fallback View

private struct NoLocationView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "location.circle.fill")
                .font(.title)
                .foregroundStyle(Color(red: 0.20, green: 0.78, blue: 0.44))

            Text("قبلتي")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("يرجى فتح التطبيق لتحديد موقعك وحساب أوقات الصلاة بدقة.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 4)
        }
    }
}

// MARK: - Widget Definition

struct QiblaWidget: Widget {
    let kind: String = "QiblaWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            QiblaWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            Color(red: 0.04, green: 0.12, blue: 0.08),
                            Color(red: 0.08, green: 0.20, blue: 0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("مواقيت الصلاة")
        .description("متابعة موعد الصلاة القادمة وأوقات الصلوات والتاريخ الهجري.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
