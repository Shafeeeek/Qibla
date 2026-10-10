import SwiftUI
import SwiftData

// MARK: - AchievementsView

struct AchievementsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var tracker: WorshipTracker?
    @State private var todayLog: WorshipLog?
    @State private var weeklyData: [WeekdayStats] = []
    @State private var heatmapData: [(date: Date, score: Double)] = []
    @State private var overview: MonthlyOverview?
    @State private var streakCount = 0
    @State private var animateStreak = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 18) {
                    streakBanner
                    dailyCheckIn
                    weeklyChart
                    monthlyStats
                    heatmapGrid
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(AppPalette.background)
            .navigationTitle("الإنجازات")
            .onAppear { loadData() }
        }
    }

    private func loadData() {
        let t = WorshipTracker(modelContext: modelContext)
        tracker = t
        t.insertDemoDataIfEmpty()
        todayLog = t.todayLog()
        weeklyData = t.weeklyStats()
        heatmapData = t.monthlyHeatmap()
        overview = t.monthlyOverview()
        streakCount = t.currentStreak()
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            animateStreak = true
        }
    }

    private func refreshStats() {
        guard let t = tracker else { return }
        weeklyData = t.weeklyStats()
        heatmapData = t.monthlyHeatmap()
        overview = t.monthlyOverview()
        streakCount = t.currentStreak()
    }

    // MARK: - Streak Banner

    private var streakBanner: some View {
        HStack(spacing: 16) {
            // Fire icon
            Text("🔥")
                .font(.system(size: 44))
                .scaleEffect(animateStreak ? 1.0 : 0.3)
                .opacity(animateStreak ? 1 : 0)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(AppPalette.streak)
                    .contentTransition(.numericText())

                Text("يوم التزام متواصل")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Mini motivational badge
            if streakCount >= 7 {
                VStack(spacing: 4) {
                    Image(systemName: streakCount >= 30 ? "star.fill" : "flame.fill")
                        .font(.title2)
                        .foregroundStyle(streakCount >= 30 ? AppPalette.gold : AppPalette.streak)
                    Text(streakCount >= 30 ? "ماشاء الله!" : "استمر!")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppPalette.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppPalette.streak.opacity(streakCount > 0 ? 0.3 : 0), lineWidth: 1.5)
                )
        )
    }

    // MARK: - Daily Check-in

    private var dailyCheckIn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(AppPalette.green)
                Text("تسجيل عبادات اليوم")
                    .font(.headline)
                Spacer()
            }

            // Prayers
            VStack(spacing: 8) {
                prayerToggle("الفجر", icon: "moon.stars.fill", color: AppPalette.chartFajr,
                             isOn: binding(\.fajrOnTime))
                prayerToggle("الظهر", icon: "sun.max.fill", color: AppPalette.chartDhuhr,
                             isOn: binding(\.dhuhrOnTime))
                prayerToggle("العصر", icon: "sun.haze.fill", color: AppPalette.chartAsr,
                             isOn: binding(\.asrOnTime))
                prayerToggle("المغرب", icon: "sunset.fill", color: AppPalette.chartMaghrib,
                             isOn: binding(\.maghribOnTime))
                prayerToggle("العشاء", icon: "moon.fill", color: AppPalette.chartIsha,
                             isOn: binding(\.ishaOnTime))
            }

            Divider()

            // Azkar
            HStack(spacing: 12) {
                azkarButton("أذكار الصباح", icon: "sunrise.fill",
                            isActive: todayLog?.morningAzkar ?? false) {
                    todayLog?.morningAzkar.toggle()
                    saveAndRefresh()
                }
                azkarButton("أذكار المساء", icon: "sunset.fill",
                            isActive: todayLog?.eveningAzkar ?? false) {
                    todayLog?.eveningAzkar.toggle()
                    saveAndRefresh()
                }
            }

            Divider()

            // Quran
            HStack(spacing: 12) {
                Image(systemName: "book.fill")
                    .foregroundStyle(AppPalette.green)
                    .frame(width: 24)

                Text("صفحات القرآن")
                    .font(.subheadline)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        guard let log = todayLog, log.quranPages > 0 else { return }
                        log.quranPages -= 1
                        saveAndRefresh()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }

                    Text("\(todayLog?.quranPages ?? 0)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .frame(minWidth: 30)
                        .contentTransition(.numericText())

                    Button {
                        todayLog?.quranPages += 1
                        saveAndRefresh()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppPalette.green)
                    }
                }
            }
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func prayerToggle(_ name: String, icon: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(name)
                .font(.subheadline)

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(color)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    saveAndRefresh()
                }
        }
    }

    private func azkarButton(_ title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .foregroundStyle(isActive ? .white : .secondary)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isActive ? AppPalette.green : Color.gray.opacity(0.15))
            )
        }
    }

    private func binding(_ keyPath: ReferenceWritableKeyPath<WorshipLog, Bool>) -> Binding<Bool> {
        Binding(
            get: { todayLog?[keyPath: keyPath] ?? false },
            set: { newVal in todayLog?[keyPath: keyPath] = newVal }
        )
    }

    private func saveAndRefresh() {
        tracker?.save()
        refreshStats()
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(AppPalette.green)
                Text("الأسبوع الحالي")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(weeklyData) { day in
                    VStack(spacing: 4) {
                        // Stacked prayer bars
                        VStack(spacing: 1) {
                            ForEach(day.log?.prayerStatuses ?? [], id: \.name) { status in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(status.done
                                          ? AppPalette.prayerColor(for: status.name)
                                          : Color.gray.opacity(0.12))
                                    .frame(height: status.done ? 18 : 8)
                            }
                        }
                        .frame(maxHeight: 120, alignment: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(day.dayLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140)

            // Legend
            HStack(spacing: 12) {
                ForEach([("الفجر", AppPalette.chartFajr), ("الظهر", AppPalette.chartDhuhr),
                         ("العصر", AppPalette.chartAsr), ("المغرب", AppPalette.chartMaghrib),
                         ("العشاء", AppPalette.chartIsha)], id: \.0) { name, color in
                    HStack(spacing: 3) {
                        Circle()
                            .fill(color)
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Monthly Stats

    private var monthlyStats: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(AppPalette.gold)
                Text("إحصائيات الشهر")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatCard(
                    icon: "clock.fill",
                    color: AppPalette.green,
                    value: "\(Int((overview?.avgPrayerRatio ?? 0) * 100))%",
                    label: "التزام بالصلاة"
                )
                StatCard(
                    icon: "book.fill",
                    color: AppPalette.gold,
                    value: "\(overview?.totalQuranPages ?? 0)",
                    label: "صفحة قرآن"
                )
                StatCard(
                    icon: "sparkles",
                    color: AppPalette.socialPurple,
                    value: "\(overview?.azkarDays ?? 0)",
                    label: "يوم أذكار"
                )
                StatCard(
                    icon: "checkmark.seal.fill",
                    color: AppPalette.streak,
                    value: "\(overview?.loggedDays ?? 0)/30",
                    label: "يوم مسجّل"
                )
            }
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Heatmap Grid

    private var heatmapGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundStyle(AppPalette.green)
                Text("آخر ٣٠ يوم")
                    .font(.headline)
                Spacer()

                // Legend
                HStack(spacing: 2) {
                    Text("أقل")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    ForEach([0.0, 0.25, 0.5, 0.85], id: \.self) { score in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppPalette.heatmapColor(score: score))
                            .frame(width: 10, height: 10)
                    }
                    Text("أكثر")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }

            // Grid — 6 columns
            let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 6)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(heatmapData.enumerated()), id: \.offset) { _, entry in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppPalette.heatmapColor(score: entry.score))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay {
                            if entry.score > 0 {
                                Text(dayLabel(entry.date))
                                    .font(.system(size: 7))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                }
            }
        }
        .padding(16)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func dayLabel(_ date: Date) -> String {
        let day = Calendar.current.component(.day, from: date)
        return "\(day)"
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Preview

#Preview {
    AchievementsView()
        .modelContainer(for: [WorshipLog.self], inMemory: true)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
