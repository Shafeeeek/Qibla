import SwiftUI
import SwiftData

@main
struct QiblaApp: App {
    @State private var appState = AppState()

    let modelContainer: ModelContainer = {
        let schema = Schema([Halaqa.self, HalaqaMember.self, WorshipLog.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        // Initialize NotificationService and set UNUserNotificationCenter delegate
        _ = NotificationService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
