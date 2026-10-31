import SwiftUI
import SwiftData

@main
struct Look4SatApp: App {
    let container: ModelContainer
    @State private var location = LocationService()
    @State private var passes = PassStore()
    @AppStorage("nightMode") private var night = false

    init() {
        container = try! ModelContainer(for: SatelliteEntity.self)
        RefreshScheduler.register(container: container)
        RefreshScheduler.schedule()
    }

    var body: some Scene {
        WindowGroup {
            let theme = night ? AppTheme.night : AppTheme.standard
            TabView {
                DashboardView().tabItem { Label("Tracked", systemImage: "star") }
                SatelliteOverviewMapView().tabItem { Label("Map", systemImage: "map") }
                NavigationStack { AllPassesView() }
                    .tabItem { Label("Passes", systemImage: "calendar") }
                NavigationStack { SatelliteSearchView() }
                    .tabItem { Label("Satellites", systemImage: "magnifyingglass") }
                NavigationStack { SettingsView() }
                    .tabItem { Label("Settings", systemImage: "gear") }
            }
            .environment(location)
            .environment(passes)
            .environment(\.appTheme, theme)
            .tint(theme.accent)
            .preferredColorScheme(night ? .dark : nil)
            .onAppear { location.start() }
            .task {
                let devOn = UserDefaults.standard.object(forKey: "devSatellite") as? Bool ?? true
                await DevSatellite.sync(enabled: devOn, container: container)
                await TLEImporter.refreshIfNeeded(container: container)
            }
        }
        .modelContainer(container)
    }
}
