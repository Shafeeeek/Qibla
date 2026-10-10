import Foundation
import SwiftData

// MARK: - HalaqaType

/// The type of a group activity (Halaqa).
enum HalaqaType: String, CaseIterable, Identifiable, Codable, Sendable {
    case quranKhatma = "ختمة قرآن"
    case tasbih      = "تسبيح"
    case azkar       = "أذكار يومية"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .quranKhatma: return "book.fill"
        case .tasbih:      return "circle.grid.cross.fill"
        case .azkar:       return "sparkles"
        }
    }

    var defaultTarget: Int {
        switch self {
        case .quranKhatma: return 30   // 30 juz
        case .tasbih:      return 1000
        case .azkar:       return 30   // 30 days
        }
    }

    var unitName: String {
        switch self {
        case .quranKhatma: return "جزء"
        case .tasbih:      return "تسبيحة"
        case .azkar:       return "يوم"
        }
    }
}

// MARK: - HalaqaMember

@Model
final class HalaqaMember {
    var id: UUID
    var name: String
    var progress: Int
    var lastUpdated: Date
    var isCurrentUser: Bool

    @Relationship(inverse: \Halaqa.members)
    var halaqa: Halaqa?

    init(
        id: UUID = UUID(),
        name: String,
        progress: Int = 0,
        lastUpdated: Date = .now,
        isCurrentUser: Bool = false
    ) {
        self.id            = id
        self.name          = name
        self.progress      = progress
        self.lastUpdated   = lastUpdated
        self.isCurrentUser = isCurrentUser
    }

    var progressFormatted: String {
        "\(progress)"
    }
}

// MARK: - Halaqa

@Model
final class Halaqa {
    var id: UUID
    var name: String
    var typeRaw: String
    var shareCode: String
    var createdAt: Date
    var totalTarget: Int

    @Relationship(deleteRule: .cascade)
    var members: [HalaqaMember]

    var type: HalaqaType {
        get { HalaqaType(rawValue: typeRaw) ?? .quranKhatma }
        set { typeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        type: HalaqaType,
        shareCode: String = "",
        createdAt: Date = .now,
        totalTarget: Int? = nil,
        members: [HalaqaMember] = []
    ) {
        self.id          = id
        self.name        = name
        self.typeRaw     = type.rawValue
        self.shareCode   = shareCode.isEmpty ? Halaqa.generateCode() : shareCode
        self.createdAt   = createdAt
        self.totalTarget = totalTarget ?? type.defaultTarget
        self.members     = members
    }

    // MARK: Computed

    var totalProgress: Int {
        members.reduce(0) { $0 + $1.progress }
    }

    var completionRatio: Double {
        guard totalTarget > 0 else { return 0 }
        return min(Double(totalProgress) / Double(totalTarget), 1.0)
    }

    var isCompleted: Bool { completionRatio >= 1.0 }

    var currentUserMember: HalaqaMember? {
        members.first(where: \.isCurrentUser)
    }

    // MARK: Share Code Generator

    static func generateCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789" // no confusing 0/O, 1/I
        return String((0..<6).map { _ in chars.randomElement()! })
    }
}
