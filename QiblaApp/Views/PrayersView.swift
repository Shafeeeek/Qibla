import SwiftUI

// MARK: - PrayersView

struct PrayersView: View {
    @Environment(AppState.self) private var appState
    @State private var currentTime = Date()

    private var lm:          LocationManager { appState.locationManager }
    private var prayers:     [PrayerTime]    { appState.prayerTimeItems }
    private var hijriDate:   String          { appState.hijriDateString }

    private var nextPrayer: PrayerTime? {
        prayers.first(where: { $0.isNext })
    }

    private var locationLabel: String {
        guard !lm.cityName.isEmpty else {
            switch lm.authorizationStatus {
            case .notDetermined:       return "جاري التحديد…"
            case .denied, .restricted: return "الموقع غير متاح"
            default:                   return "جاري التحديد…"
            }
        }
        return lm.countryName.isEmpty
            ? lm.cityName
            : "\(lm.cityName)، \(lm.countryName)"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.backgroundGradient
                    .ignoresSafeArea()

                Group {
                    if prayers.isEmpty {
                        loadingView
                    } else {
                        prayerList
                    }
                }
            }
            .navigationTitle("مواقيت الصلاة")
            .toolbarBackground(AppPalette.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    currentTime = Date()
                }
            }
        }
    }

    // MARK: - Subviews

    private var prayerList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                headerRow

                if let next = nextPrayer {
                    nextPrayerHeroCard(next)
                }

                VStack(spacing: 12) {
                    ForEach(prayers) { prayer in
                        PrayerTimeRow(prayer: prayer)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }

    private var headerRow: some View {
        HStack {
            if !hijriDate.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(AppPalette.gold)
                    Text(hijriDate)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppPalette.gold)
                }
            }
            Spacer()
            Label(locationLabel, systemImage: "mappin.and.ellipse")
                .font(.caption.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(AppPalette.card)
                        .overlay(Capsule().stroke(AppPalette.cardBorder, lineWidth: 0.8))
                )
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }

    // MARK: - Hero Next Prayer Card (Royal Islamic Style)

    private func nextPrayerHeroCard(_ prayer: PrayerTime) -> some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 8) {
                    RubElHizbShape()
                        .stroke(AppPalette.gold, lineWidth: 1.2)
                        .frame(width: 22, height: 22)
                        .overlay {
                            Circle()
                                .fill(AppPalette.gold)
                                .frame(width: 6, height: 6)
                        }

                    Text("الصلاة التالية: \(prayer.name)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.white)
                }

                Spacer()

                Text(prayer.time)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.goldLight)
            }

            Divider()
                .overlay(AppPalette.gold.opacity(0.25))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("الوقت المتبقي للأذان")
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text(countdownString(to: prayer.date))
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppPalette.gold)
                }

                Spacer()

                Image(systemName: prayerIcon(for: prayer.name))
                    .font(.system(size: 38))
                    .foregroundStyle(AppPalette.gold.opacity(0.85))
                    .shadow(color: AppPalette.gold.opacity(0.4), radius: 8)
            }
        }
        .padding(20)
        .background(
            ZStack {
                AppPalette.heroCardGradient

                // Subtle watermark star
                RubElHizbShape()
                    .stroke(AppPalette.gold.opacity(0.06), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .offset(x: 100, y: 10)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppPalette.gold, AppPalette.goldDark.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: AppPalette.gold.opacity(0.20), radius: 16, y: 6)
    }

    private func countdownString(to date: Date) -> String {
        let diff = Int(date.timeIntervalSince(currentTime))
        guard diff > 0 else { return "حان الآن وقت الصلاة" }
        let h = diff / 3600
        let m = (diff % 3600) / 60
        let s = diff % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func prayerIcon(for name: String) -> String {
        switch name {
        case "الفجر":   return "moon.stars.fill"
        case "الشروق":  return "sunrise.fill"
        case "الظهر":   return "sun.max.fill"
        case "العصر":   return "sun.haze.fill"
        case "المغرب":  return "sunset.fill"
        case "العشاء":  return "moon.fill"
        default:        return "clock.fill"
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.6)
                .tint(AppPalette.gold)
            Text("جاري حساب مواقيت الصلاة…")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

// MARK: - PrayerTimeRow (Luxury Glass Row)

private struct PrayerTimeRow: View {
    let prayer: PrayerTime

    var body: some View {
        HStack(spacing: 16) {
            // Emblem icon container
            ZStack {
                if prayer.isNext {
                    RubElHizbShape()
                        .fill(AppPalette.gold.opacity(0.25))
                        .frame(width: 44, height: 44)
                    RubElHizbShape()
                        .stroke(AppPalette.gold, lineWidth: 1.2)
                        .frame(width: 44, height: 44)
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Circle()
                        .stroke(AppPalette.gold.opacity(0.2), lineWidth: 1)
                        .frame(width: 44, height: 44)
                }

                Image(systemName: prayerIcon)
                    .foregroundStyle(prayer.isNext ? AppPalette.goldLight : Color.white.opacity(0.85))
                    .font(.body.weight(.semibold))
            }

            Text(prayer.name)
                .font(.title3.weight(.bold))
                .foregroundStyle(prayer.isNext ? AppPalette.goldLight : Color.white)

            Spacer(minLength: 12)

            Text(prayer.time)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(prayer.isNext ? AppPalette.goldLight : Color.white.opacity(0.92))

            Image(systemName: prayer.isNext ? "bell.fill" : "bell")
                .foregroundStyle(prayer.isNext ? AppPalette.gold : Color.white.opacity(0.35))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            prayer.isNext
                ? AnyShapeStyle(AppPalette.heroCardGradient)
                : AnyShapeStyle(AppPalette.card)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    prayer.isNext ? AppPalette.cardBorderActive : AppPalette.cardBorder,
                    lineWidth: prayer.isNext ? 1.4 : 0.8
                )
        )
        .shadow(
            color: prayer.isNext ? AppPalette.gold.opacity(0.20) : Color.clear,
            radius: 10, y: 3
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(prayer.name)، \(prayer.time)\(prayer.isNext ? "، الصلاة التالية" : "")")
    }

    private var prayerIcon: String {
        switch prayer.name {
        case "الفجر":   return "moon.stars.fill"
        case "الشروق":  return "sunrise.fill"
        case "الظهر":   return "sun.max.fill"
        case "العصر":   return "sun.haze.fill"
        case "المغرب":  return "sunset.fill"
        case "العشاء":  return "moon.fill"
        default:        return "clock"
        }
    }
}

// MARK: - Preview

#Preview {
    PrayersView()
        .environment(AppState())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
