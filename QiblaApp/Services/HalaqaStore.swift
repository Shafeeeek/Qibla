import Foundation
import SwiftData

// MARK: - HalaqaStore

/// Manages CRUD operations for Halaqas (shared group activities).
@MainActor
@Observable
final class HalaqaStore {
    private let modelContext: ModelContext

    /// The currently stored user display name.
    var userName: String {
        get { UserDefaults.standard.string(forKey: "halaqaUserName") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "halaqaUserName") }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Fetch

    func fetchAll() -> [Halaqa] {
        let descriptor = FetchDescriptor<Halaqa>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func findByCode(_ code: String) -> Halaqa? {
        let upperCode = code.uppercased()
        var descriptor = FetchDescriptor<Halaqa>(
            predicate: #Predicate { $0.shareCode == upperCode }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Create

    @discardableResult
    func createHalaqa(name: String, type: HalaqaType, target: Int? = nil, creatorName: String) -> Halaqa {
        let halaqa = Halaqa(name: name, type: type, totalTarget: target)
        let creator = HalaqaMember(name: creatorName, isCurrentUser: true)
        halaqa.members.append(creator)
        modelContext.insert(halaqa)
        try? modelContext.save()
        return halaqa
    }

    // MARK: - Join

    enum JoinResult {
        case success(Halaqa)
        case notFound
        case alreadyJoined
    }

    func joinHalaqa(code: String, userName: String) -> JoinResult {
        guard let halaqa = findByCode(code) else {
            return .notFound
        }
        if halaqa.members.contains(where: \.isCurrentUser) {
            return .alreadyJoined
        }
        let member = HalaqaMember(name: userName, isCurrentUser: true)
        halaqa.members.append(member)
        try? modelContext.save()
        return .success(halaqa)
    }

    // MARK: - Update Progress

    func updateProgress(halaqa: Halaqa, amount: Int) {
        guard let member = halaqa.currentUserMember else { return }
        member.progress = max(0, member.progress + amount)
        member.lastUpdated = .now
        try? modelContext.save()
    }

    // MARK: - Delete

    func delete(_ halaqa: Halaqa) {
        modelContext.delete(halaqa)
        try? modelContext.save()
    }

    // MARK: - Demo Data (for testing)

    func insertDemoDataIfEmpty() {
        guard fetchAll().isEmpty else { return }

        let khatma = Halaqa(name: "ختمة العائلة", type: .quranKhatma)
        let me = HalaqaMember(name: userName.isEmpty ? "أنا" : userName, progress: 8, isCurrentUser: true)
        let friend1 = HalaqaMember(name: "أحمد", progress: 5)
        let friend2 = HalaqaMember(name: "فاطمة", progress: 12)
        let friend3 = HalaqaMember(name: "محمد", progress: 3)
        khatma.members = [me, friend1, friend2, friend3]
        modelContext.insert(khatma)

        let tasbih = Halaqa(name: "مجموعة التسبيح", type: .tasbih, totalTarget: 10000)
        let me2 = HalaqaMember(name: userName.isEmpty ? "أنا" : userName, progress: 1500, isCurrentUser: true)
        let friend4 = HalaqaMember(name: "عمر", progress: 2200)
        tasbih.members = [me2, friend4]
        modelContext.insert(tasbih)

        try? modelContext.save()
    }
}
