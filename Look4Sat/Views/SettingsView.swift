import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PassStore.self) private var passes

    @AppStorage("nightMode") private var nightMode = false
    @AppStorage("skyView") private var skyView = true
    @AppStorage("compassMode") private var compassMode = false
    @AppStorage("useUTC") private var useUTC = false

    @AppStorage("tleRefreshHours") private var refreshHours = 24
    @AppStorage("passHours") private var passHours = 48
    @AppStorage("minPassElevation") private var minElevation = 0.0
    @AppStorage("minPassDurationMinutes") private var minDurationMinutes = 0.0

    @AppStorage("passAlerts") private var passAlerts = false
    @AppStorage("alertLeadMinutes") private var alertLead = 10

    @AppStorage("useManualLocation") private var useManual = false
    @AppStorage("manualLat") private var lat = 0.0
    @AppStorage("manualLon") private var lon = 0.0

    @AppStorage("devSatellite") private var devSatellite = true
    @AppStorage("devCrossTrack") private var devCross = 0.0
    
    @AppStorage("showDeveloperOptions") private var showDeveloperOptions = false
    @State private var versionTapCount = 0
    @State private var lastVersionTap = Date.distantPast

    @State private var refreshing = false
    @State private var alertsDenied = false

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Red night mode", isOn: $nightMode)
                Toggle("Sky view (east on the left)", isOn: $skyView)
                Toggle("Compass-oriented radar", isOn: $compassMode)
                Toggle("Show times in UTC", isOn: $useUTC)
            }

            Section("Orbital data") {
                Picker("Auto-update", selection: $refreshHours) {
                    Text("12 hours").tag(12)
                    Text("24 hours").tag(24)
                    Text("3 days").tag(72)
                    Text("Weekly").tag(168)
                }
                Button(refreshing ? "Updating…" : "Update TLEs now") {
                    refreshing = true
                    Task {
                        await TLEImporter.refreshIfNeeded(container: context.container, force: true)
                        refreshing = false
                    }
                }
                .disabled(refreshing)
            }

            Section("Passes") {
                Picker("Prediction window", selection: $passHours) {
                    Text("12 h").tag(12)
                    Text("24 h").tag(24)
                    Text("48 h").tag(48)
                    Text("72 h").tag(72)
                }
                Stepper("Min peak elevation: \(Int(minElevation))°", value: $minElevation, in: 0...80, step: 5)
                Stepper("Min pass duration: \(Int(minDurationMinutes)) min", value: $minDurationMinutes, in: 0...20, step: 1)
            }

            Section {
                Toggle("Pass alerts", isOn: $passAlerts)
                if passAlerts {
                    Picker("Notify", selection: $alertLead) {
                        Text("1 min before").tag(1)
                        Text("5 min before").tag(5)
                        Text("10 min before").tag(10)
                        Text("15 min before").tag(15)
                        Text("30 min before").tag(30)
                    }
                }
                if alertsDenied {
                    Text("Notifications are turned off for this app in iOS Settings.")
                        .font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Alerts")
            } footer: {
                Text("Alerts use your tracked satellites and the minimum elevation above.")
            }

            Section("Location") {
                LocationStatusView()
                Toggle("Manual location", isOn: $useManual)
                if useManual {
                    TextField("Latitude", value: $lat, format: .number)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Longitude", value: $lon, format: .number)
                        .keyboardType(.numbersAndPunctuation)
                }
            }

            if showDeveloperOptions {
                Section {
                    Toggle("DEV TEST satellite", isOn: $devSatellite)

                    if devSatellite {
                        Stepper(
                            "Cross-track offset: \(Int(devCross))°",
                            value: $devCross,
                            in: 0...40,
                            step: 5
                        )
                    }
                } header: {
                    Text("Developer")
                } footer: {
                    Text("A synthetic satellite that passes every ~8 minutes, lasting about 1m50s. At 0° it goes through the zenith; larger offsets give lower passes.")
                }
            }
            Section {
                HStack {
                    Spacer()

                    Button {
                        let now = Date()

                        // Reset if taps are more than 2 seconds apart.
                        if now.timeIntervalSince(lastVersionTap) > 2 {
                            versionTapCount = 0
                        }

                        lastVersionTap = now
                        versionTapCount += 1

                        if versionTapCount >= 5 {
                            showDeveloperOptions.toggle()
                            versionTapCount = 0

                            // Keep the synthetic satellite in sync when enabled.
                            DevSatellite.sync(
                                enabled: devSatellite,
                                context: context
                            )
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("Satellite Tracker")
                                .font(.footnote)

                            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("App version")
                    .accessibilityHint("Tap five times to toggle developer options")

                    Spacer()
                }
            }
        }
        .navigationTitle("Settings")
        .tint(nightMode ? .red : .accentColor)
        .onChange(of: devSatellite) { _, on in
            DevSatellite.sync(enabled: on, context: context)
        }
        .onChange(of: passAlerts) { _, on in
            Task {
                if on, !(await PassNotifier.requestAuthorization()) {
                    passAlerts = false
                    alertsDenied = true
                    return
                }
                alertsDenied = false
                await passes.rescheduleAlerts()
            }
        }
        .onChange(of: alertLead) { _, _ in Task { await passes.rescheduleAlerts() } }
        .onChange(of: minElevation) { _, _ in Task { await passes.rescheduleAlerts() } }
    }
}
