import SwiftUI
import UIKit

// MARK: - QiblaView

struct QiblaView: View {
    @Environment(AppState.self) private var appState

    enum FinderMode: String, CaseIterable {
        case compass = "البوصلة"
        case ar = "الواقع المعزز"
    }

    @State private var mode: FinderMode = .compass

    private var lm:       LocationManager { appState.locationManager }
    private var info:     QiblaInfo?      { appState.qiblaInfo }
    private var bearing:  Double          { info?.bearing    ?? 0 }
    private var distance: Double          { info?.distanceKm ?? 0 }
    private var heading:  Double          { lm.compassHeading }

    var body: some View {
        NavigationStack {
            ZStack {
                AppPalette.backgroundGradient
                    .ignoresSafeArea()

                if mode == .ar {
                    ARQiblaView(onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            mode = .compass
                        }
                    })
                    .transition(.opacity)
                } else {
                    compassContent
                        .transition(.opacity)
                }
            }
            .navigationTitle(mode == .ar ? "الواقع المعزز" : "القبلة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppPalette.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if mode == .ar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                mode = .compass
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "safari.fill")
                                Text("البوصلة")
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppPalette.goldLight)
                        }
                    }
                }
            }
            .sensoryFeedback(.success, trigger: isFacingQibla) { oldValue, newValue in
                !oldValue && newValue
            }
            .onAppear {
                appState.startLocationUpdates()
            }
        }
    }

    // MARK: - Compass Content

    private var compassContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                header

                switch lm.authorizationStatus {
                case .denied, .restricted:
                    permissionCard
                default:
                    if lm.coordinate == nil {
                        loadingCard
                    } else {
                        modeSelector
                        QiblaDial(
                            compassHeading: heading,
                            qiblaBearing: bearing
                        )
                        qiblaStatus
                        bearingCard
                        arBannerButton
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                RubElHizbShape()
                    .stroke(AppPalette.gold, lineWidth: 1.2)
                    .frame(width: 18, height: 18)

                Text("مكة المكرمة")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppPalette.goldGradient)

                RubElHizbShape()
                    .stroke(AppPalette.gold, lineWidth: 1.2)
                    .frame(width: 18, height: 18)
            }

            if distance > 0 {
                Label(formattedDistance, systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppPalette.card)
                            .overlay(Capsule().stroke(AppPalette.cardBorder, lineWidth: 1))
                    )
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 4) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    mode = .compass
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "safari.fill")
                        .font(.caption)
                    Text("البوصلة الملكية")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(mode == .compass ? AppPalette.goldLight : Color.white.opacity(0.6))
                .background(
                    mode == .compass ? AppPalette.gold.opacity(0.2) : Color.clear,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    mode = .ar
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.caption)
                    Text("الواقع المعزز (AR)")
                        .font(.caption.weight(.bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .foregroundStyle(mode == .ar ? AppPalette.emeraldLight : Color.white.opacity(0.6))
                .background(
                    mode == .ar ? AppPalette.green.opacity(0.25) : Color.clear,
                    in: Capsule()
                )
            }
            .buttonStyle(.plain)
        }
        .padding(4)
        .background(AppPalette.card, in: Capsule())
        .overlay(Capsule().stroke(AppPalette.cardBorder, lineWidth: 1))
        .sensoryFeedback(.selection, trigger: mode)
    }

    // MARK: - AR Banner Button

    private var arBannerButton: some View {
        Button {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                mode = .ar
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(AppPalette.green.opacity(0.2))
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.viewfinder")
                        .font(.title3)
                        .foregroundStyle(AppPalette.emeraldLight)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("تحديد القبلة بالواقع المعزز (AR)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.white)
                    Text("وجّه كاميرا هاتفك لرؤية الكعبة المشرفة في محيطك")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.7))
                }

                Spacer()

                Image(systemName: "chevron.backward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppPalette.gold)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppPalette.cardElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppPalette.cardBorderActive, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Qibla status

    /// Normalises an angle to (−180, 180]
    private func normalised(_ a: Double) -> Double {
        var r = a.truncatingRemainder(dividingBy: 360)
        if r >  180 { r -= 360 }
        if r < -180 { r += 360 }
        return r
    }

    private var isFacingQibla: Bool {
        abs(normalised(bearing - heading)) < 5
    }

    private var qiblaStatus: some View {
        HStack(spacing: 10) {
            if isFacingQibla {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.gold)
                Text("أنت تواجه القبلة المشرفة الآن!")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppPalette.goldLight)
            } else {
                Image(systemName: "arrow.turn.up.right")
                    .foregroundStyle(AppPalette.gold)
                Text("دوّر جهازك حتى تشير الإبرة نحو الكعبة")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            isFacingQibla
                ? AnyShapeStyle(AppPalette.heroCardGradient)
                : AnyShapeStyle(AppPalette.card),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .stroke(
                    isFacingQibla ? AppPalette.cardBorderActive : AppPalette.cardBorder,
                    lineWidth: 1
                )
        )
        .shadow(
            color: isFacingQibla ? AppPalette.gold.opacity(0.3) : Color.clear,
            radius: 12, y: 3
        )
        .animation(.easeInOut(duration: 0.3), value: isFacingQibla)
    }

    private var bearingCard: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppPalette.gold.opacity(0.18))
                    .frame(width: 48, height: 48)
                Circle()
                    .stroke(AppPalette.gold, lineWidth: 1)
                    .frame(width: 48, height: 48)
                Image(systemName: "safari.fill")
                    .font(.title3)
                    .foregroundStyle(AppPalette.gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(Int(bearing.rounded()))°")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.goldLight)

                Text("درجة القبلة من الشمال الحقيقي")
                    .font(.caption)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppPalette.cardBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("درجة القبلة \(Int(bearing.rounded())) درجة من الشمال")
    }

    private var loadingCard: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.6)
                .tint(AppPalette.gold)
            Text("جاري تحديد موقعك بدقة…")
                .font(.subheadline)
                .foregroundStyle(Color.white.opacity(0.75))
        }
        .frame(height: 300)
    }

    private var permissionCard: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 52))
                .foregroundStyle(AppPalette.gold)

            Text("يرجى السماح بالوصول إلى الموقع")
                .font(.headline)
                .foregroundStyle(Color.white)

            Text("افتح الإعدادات وامنح قبلتي إذن الموقع لتحديد الاتجاه الدقيق للقبلة")
                .font(.callout)
                .foregroundStyle(Color.white.opacity(0.8))
                .multilineTextAlignment(.center)

            Button("فتح الإعدادات") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(AppPalette.green)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(AppPalette.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppPalette.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var formattedDistance: String {
        guard distance > 0 else { return "" }
        let fmt = NumberFormatter()
        fmt.locale                = Locale(identifier: "ar")
        fmt.numberStyle           = .decimal
        fmt.maximumFractionDigits = 0
        let s = fmt.string(from: NSNumber(value: distance)) ?? "\(Int(distance))"
        return "تبعد \(s) كم"
    }
}

// MARK: - QiblaDial (Royal Astrolabe Design)

private struct QiblaDial: View {
    let compassHeading: Double
    let qiblaBearing:   Double

    /// When this angle is 0 -> arrow points straight up -> device faces Qibla.
    private var needleAngle: Double { qiblaBearing - compassHeading }

    private var normalised: Double {
        var r = needleAngle.truncatingRemainder(dividingBy: 360)
        if r >  180 { r -= 360 }
        if r < -180 { r += 360 }
        return r
    }
    private var isFacingQibla: Bool {
        abs(normalised) < 5
    }

    var body: some View {
        ZStack {
            // ── Outer Astrolabe Bezel ─────────────────────────────────
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.05, green: 0.16, blue: 0.11),
                            Color(red: 0.02, green: 0.07, blue: 0.05)
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 155
                    )
                )
                .overlay {
                    // Concentric gold accent rings
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [AppPalette.goldLight, AppPalette.gold, AppPalette.goldDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                }
                .overlay {
                    Circle()
                        .stroke(AppPalette.gold.opacity(0.25), lineWidth: 1)
                        .padding(10)
                }
                .overlay {
                    Circle()
                        .stroke(AppPalette.gold.opacity(0.15), lineWidth: 1)
                        .padding(50)
                }
                .shadow(
                    color: isFacingQibla ? AppPalette.gold.opacity(0.35) : AppPalette.green.opacity(0.2),
                    radius: 30
                )

            // ── Background Islamic Geometric Star Watermark ───────────
            RubElHizbShape()
                .stroke(AppPalette.gold.opacity(0.12), lineWidth: 1.5)
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(compassHeading * 0.5))

            // ── Alignment Ray Glow Beam (When Facing Qibla) ───────────
            if isFacingQibla {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.gold.opacity(0.7), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 110)
                    .offset(y: -60)
                    .blur(radius: 2)
                    .transition(.opacity)
            }

            // ── Compass Ring (Rotates with device heading) ────────────
            ZStack {
                tickMarks
                cardinalDirections
            }
            .rotationEffect(.degrees(-compassHeading))
            .animation(.smooth(duration: 0.25), value: compassHeading)

            // ── Astrolabe Needle (Points to Qibla) ────────────────────
            ZStack {
                // Needle shadow
                AstrolabeNeedleShape()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 14, height: 190)
                    .offset(y: 4)

                // Left facet of needle (Light Gold)
                AstrolabeNeedleHalf(isLeft: true)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.goldLight, isFacingQibla ? AppPalette.gold : AppPalette.emeraldLight],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 7, height: 190)
                    .offset(x: -3.5)

                // Right facet of needle (Dark Gold / Shadow)
                AstrolabeNeedleHalf(isLeft: false)
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.goldDark, isFacingQibla ? AppPalette.goldLight : AppPalette.green],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 7, height: 190)
                    .offset(x: 3.5)

                // Center jewel along needle
                RubElHizbShape()
                    .fill(AppPalette.goldLight)
                    .frame(width: 12, height: 12)
                    .offset(y: -40)
                    .shadow(color: AppPalette.gold, radius: 4)
            }
            .rotationEffect(.degrees(needleAngle))
            .shadow(
                color: (isFacingQibla ? AppPalette.gold : AppPalette.green).opacity(0.65),
                radius: isFacingQibla ? 14 : 6
            )
            .animation(.smooth(duration: 0.25), value: needleAngle)

            // ── Kaaba at 12 o’clock (Target) ──────────────────────────
            ZStack {
                // Golden halo glow behind Kaaba
                Circle()
                    .fill(AppPalette.gold.opacity(isFacingQibla ? 0.35 : 0.12))
                    .frame(width: 54, height: 54)
                    .blur(radius: isFacingQibla ? 10 : 4)

                KaabaIcon(size: 32)
            }
            .offset(y: -116)
            .scaleEffect(isFacingQibla ? 1.15 : 1.0)
            .animation(.spring(duration: 0.4), value: isFacingQibla)
            .accessibilityHidden(true)

            // ── Royal Center Pin (Concentric Gold Boss & Jewel) ──────
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppPalette.goldLight, AppPalette.goldDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 24, height: 24)

                Circle()
                    .fill(Color(red: 0.05, green: 0.15, blue: 0.10))
                    .frame(width: 14, height: 14)

                Circle()
                    .fill(isFacingQibla ? AppPalette.goldLight : AppPalette.emeraldLight)
                    .frame(width: 6, height: 6)
            }
            .shadow(color: Color.black.opacity(0.5), radius: 4, y: 2)
        }
        .frame(width: 310, height: 310)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("بوصلة القبلة")
        .accessibilityValue("دوّر جهازك حتى تشير الإبرة نحو الكعبة في أعلى الشاشة")
    }

    // MARK: - Tick marks (72 × 5° = 360°)

    private var tickMarks: some View {
        ForEach(0..<72, id: \.self) { i in
            let major  = i.isMultiple(of: 9)   // every 45°
            let medium = i.isMultiple(of: 3)   // every 15°
            Capsule()
                .fill(
                    major  ? AppPalette.gold :
                    medium ? AppPalette.gold.opacity(0.60) :
                             Color.white.opacity(0.25)
                )
                .frame(
                    width:  major ? 2.5 : 1.2,
                    height: major ? 14 : medium ? 9 : 5
                )
                .offset(y: -140)
                .rotationEffect(.degrees(Double(i) * 5))
        }
    }

    // MARK: - Cardinal directions

    private var cardinalDirections: some View {
        ZStack {
            directionBadge("ش", offsetY: -112) // North
            directionBadge("ج", offsetY:  112) // South
            directionBadge("ق", offsetX:  112) // East
            directionBadge("غ", offsetX: -112) // West
        }
    }

    private func directionBadge(_ letter: String, offsetX: CGFloat = 0, offsetY: CGFloat = 0) -> some View {
        Text(letter)
            .font(.system(size: 15, weight: .bold, design: .serif))
            .foregroundStyle(letter == "ش" ? AppPalette.goldLight : Color.white.opacity(0.85))
            .offset(x: offsetX, y: offsetY)
    }
}

// MARK: - Astrolabe Needle Shapes

private struct AstrolabeNeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let midX = rect.midX
        let top = rect.minY
        let bottom = rect.maxY
        let midY = rect.midY

        p.move(to: CGPoint(x: midX, y: top))
        p.addLine(to: CGPoint(x: rect.maxX, y: midY))
        p.addLine(to: CGPoint(x: midX + 2, y: bottom))
        p.addLine(to: CGPoint(x: midX - 2, y: bottom))
        p.addLine(to: CGPoint(x: rect.minX, y: midY))
        p.closeSubpath()
        return p
    }
}

private struct AstrolabeNeedleHalf: Shape {
    let isLeft: Bool

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.minY
        let bottom = rect.maxY
        let midY = rect.midY

        if isLeft {
            p.move(to: CGPoint(x: rect.maxX, y: top))
            p.addLine(to: CGPoint(x: rect.maxX, y: bottom))
            p.addLine(to: CGPoint(x: rect.minX, y: midY))
            p.closeSubpath()
        } else {
            p.move(to: CGPoint(x: rect.minX, y: top))
            p.addLine(to: CGPoint(x: rect.maxX, y: midY))
            p.addLine(to: CGPoint(x: rect.minX, y: bottom))
            p.closeSubpath()
        }
        return p
    }
}

// MARK: - KaabaIcon

struct KaabaIcon: View {
    var size: CGFloat = 30

    private var h: CGFloat { size * 1.25 }

    var body: some View {
        ZStack {
            // Kiswah
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .fill(Color(red: 0.04, green: 0.03, blue: 0.06))
                .frame(width: size, height: h)

            // Subtle upper shimmer
            LinearGradient(
                colors: [AppPalette.gold.opacity(0.25), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: size, height: h * 0.45)
            .offset(y: -h * 0.28)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.07, style: .continuous))

            // Hizam al-Dhahab (Gold Belt)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppPalette.goldLight, AppPalette.gold, AppPalette.goldDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size, height: size * 0.14)
                .offset(y: -h * 0.1)

            // Bab al-Kaaba (Gold Door)
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading:     size * 0.14,
                    bottomLeading:  0,
                    bottomTrailing: 0,
                    topTrailing:    size * 0.14
                ),
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [AppPalette.goldLight, AppPalette.goldDark],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size * 0.38, height: h * 0.30)
            .offset(y: h * 0.20)

            // Gold border
            RoundedRectangle(cornerRadius: size * 0.07, style: .continuous)
                .stroke(AppPalette.gold.opacity(0.65), lineWidth: 1)
                .frame(width: size, height: h)
        }
        .shadow(color: AppPalette.gold.opacity(0.6), radius: 12)
    }
}

// MARK: - Preview

#Preview {
    QiblaView()
        .environment(AppState())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
