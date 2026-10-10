import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = AppTab.prayers

    var body: some View {
        TabView(selection: $selection) {
            PrayersView()
                .tabItem { Label("المواقيت", systemImage: "clock") }
                .tag(AppTab.prayers)

            QiblaView()
                .tabItem { Label("القبلة", systemImage: "location.north.line.fill") }
                .tag(AppTab.qibla)

            AssistantView()
                .tabItem { Label("المساعد", systemImage: "sparkle") }
                .tag(AppTab.assistant)

            SettingsView()
                .tabItem { Label("الإعدادات", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(AppPalette.gold)
        // Request location permission and begin GPS + heading updates on first launch
        .task {
            appState.startLocationUpdates()
        }
        // Refresh when app returns from background (e.g. date may have changed)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appState.refresh()
            }
        }
    }
}

private enum AppTab: Hashable {
    case prayers, qibla, assistant, settings
}

#Preview {
    ContentView()
        .environment(AppState())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
        .preferredColorScheme(.dark)
}
