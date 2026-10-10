import SwiftUI

enum AppPalette {
    // MARK: - Core Royal Palette
    static let green = Color(red: 0.10, green: 0.68, blue: 0.40)
    static let emeraldLight = Color(red: 0.20, green: 0.82, blue: 0.50)
    static let emeraldDark = Color(red: 0.04, green: 0.15, blue: 0.10)
    static let emeraldDeep = Color(red: 0.02, green: 0.08, blue: 0.05)

    // MARK: - Gold Palette
    static let gold = Color(red: 0.90, green: 0.76, blue: 0.38)
    static let goldLight = Color(red: 0.98, green: 0.89, blue: 0.58)
    static let goldDark = Color(red: 0.72, green: 0.55, blue: 0.22)

    // MARK: - Background & Surface
    static let background = Color(red: 0.03, green: 0.08, blue: 0.05)
    static let card = Color(red: 0.06, green: 0.16, blue: 0.11).opacity(0.85)
    static let cardElevated = Color(red: 0.08, green: 0.22, blue: 0.15).opacity(0.90)
    static let cardBorder = gold.opacity(0.20)
    static let cardBorderActive = gold.opacity(0.65)

    // MARK: - Gradients
    static let goldGradient = LinearGradient(
        colors: [goldLight, gold, goldDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emeraldGradient = LinearGradient(
        colors: [Color(red: 0.08, green: 0.28, blue: 0.18), Color(red: 0.03, green: 0.11, blue: 0.07)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.07, blue: 0.05),
            Color(red: 0.04, green: 0.13, blue: 0.09),
            Color(red: 0.02, green: 0.06, blue: 0.04)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let heroCardGradient = LinearGradient(
        colors: [
            Color(red: 0.09, green: 0.30, blue: 0.20),
            Color(red: 0.05, green: 0.18, blue: 0.12)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Streak & Gamification
    static let streak = Color(red: 1.0, green: 0.50, blue: 0.18)       // fiery amber

    // MARK: - Prayer chart colours
    static let chartFajr    = Color(red: 0.35, green: 0.50, blue: 0.85) // deep blue
    static let chartDhuhr   = Color(red: 0.95, green: 0.78, blue: 0.25) // gold
    static let chartAsr     = Color(red: 0.92, green: 0.58, blue: 0.22) // warm amber
    static let chartMaghrib = Color(red: 0.85, green: 0.32, blue: 0.35) // sunset red
    static let chartIsha    = Color(red: 0.48, green: 0.32, blue: 0.72) // royal purple

    static func prayerColor(for name: String) -> Color {
        switch name {
        case "الفجر":  return chartFajr
        case "الظهر":  return chartDhuhr
        case "العصر":  return chartAsr
        case "المغرب": return chartMaghrib
        case "العشاء": return chartIsha
        default:       return green
        }
    }

    // MARK: - Heatmap gradient (low → high)
    static let heatmapEmpty = Color.gray.opacity(0.15)
    static let heatmapLow   = Color(red: 0.15, green: 0.40, blue: 0.25)
    static let heatmapMid   = Color(red: 0.12, green: 0.60, blue: 0.35)
    static let heatmapHigh  = Color(red: 0.10, green: 0.80, blue: 0.45)

    static func heatmapColor(score: Double) -> Color {
        if score <= 0 { return heatmapEmpty }
        if score < 0.3 { return heatmapLow }
        if score < 0.7 { return heatmapMid }
        return heatmapHigh
    }

    // MARK: - Social
    static let socialPurple = Color(red: 0.60, green: 0.40, blue: 0.88)
}

// MARK: - Islamic 8-Pointed Star Shape (Rub El Hizb)
struct RubElHizbShape: Shape {
    func path(in rect: CGRect) -> Path {
        let size = min(rect.width, rect.height)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerR = size / 2
        let innerR = outerR * 0.72
        var path = Path()

        for i in 0..<16 {
            let angle = (Double(i) * 22.5 - 90) * .pi / 180
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(
                x: center.x + CGFloat(cos(angle)) * r,
                y: center.y + CGFloat(sin(angle)) * r
            )
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Luxury Glass Card Modifier
struct LuxuryCardModifier: ViewModifier {
    var isHighlighted: Bool = false
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                isHighlighted ? AppPalette.heroCardGradient : AppPalette.emeraldGradient
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isHighlighted ? AppPalette.cardBorderActive : AppPalette.cardBorder,
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .shadow(
                color: isHighlighted ? AppPalette.gold.opacity(0.25) : Color.black.opacity(0.3),
                radius: isHighlighted ? 14 : 8,
                y: isHighlighted ? 4 : 2
            )
    }
}

extension View {
    func luxuryCard(isHighlighted: Bool = false, cornerRadius: CGFloat = 20) -> some View {
        self.modifier(LuxuryCardModifier(isHighlighted: isHighlighted, cornerRadius: cornerRadius))
    }
}
