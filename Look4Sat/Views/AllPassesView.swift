import SwiftUI
import SwiftData

/// Chronological schedule of passes for every tracked satellite.
struct AllPassesView: View {
    @Query(filter: #Predicate<SatelliteEntity> { $0.isTracked }, sort: \.name)
    private var tracked: [SatelliteEntity]
    @Environment(PassStore.self) private var passes
    @Environment(LocationService.self) private var location
    @AppStorage("minPassElevation") private var minElevation = 0.0
    @AppStorage("minPassDurationMinutes") private var minDurationMinutes = 0.0
    @State private var sortByElevation = false
    @AppStorage("passHours") private var passHours = 48
    @AppStorage("devCrossTrack") private var devCross = 0.0

    private var refreshKey: String {
        let o = location.observer
        return "\(tracked.map(\.noradID))|\(Int((o?.latitude ?? 0) * 100))|\(Int((o?.longitude ?? 0) * 100))|\(passHours)|\(devCross)"
    }

    var body: some View {
        let now = Date()
        let horizon = now.addingTimeInterval(Double(passHours) * 3600)
        let filtered = passes.entries.filter {
            $0.pass.los > now && $0.pass.aos < horizon && $0.pass.maxElevation >= minElevation
                && $0.pass.duration >= minDurationMinutes * 60
        }
        let shown = sortByElevation ? filtered.sorted { $0.pass.maxElevation > $1.pass.maxElevation }
                                    : filtered.sorted { $0.pass.aos < $1.pass.aos }
        List {
            Section {
                Slider(value: $minElevation, in: 0...90, step: 5)
                Text("Minimum peak elevation: \(Int(minElevation))°").font(.caption)
                Slider(value: $minDurationMinutes, in: 0...20, step: 1)
                Text("Minimum duration: \(Int(minDurationMinutes)) min").font(.caption)
                Toggle("Sort by highest elevation", isOn: $sortByElevation)
                Picker("Window", selection: $passHours) {
                    Text("12 h").tag(12)
                    Text("24 h").tag(24)
                    Text("48 h").tag(48)
                    Text("72 h").tag(72)
                }
                .pickerStyle(.segmented)
            }
            Section("\(shown.count) passes") {
                ForEach(shown) { e in
                    NavigationLink {
                        PassDetailView(name: e.name, tle: e.tle, pass: e.pass)
                    } label: {
                        PassRow(title: e.name, pass: e.pass)
                    }
                }
            }
        }
        .navigationTitle("Passes")
        .overlay {
            if tracked.isEmpty {
                ContentUnavailableView("No tracked satellites", systemImage: "star",
                                       description: Text("Star satellites in the Satellites tab."))
            }
        }
        .task(id: refreshKey) {
            if let o = location.observer {
                await passes.refreshIfNeeded(for: tracked, observer: o, hours: Double(passHours))
            }
        }
    }
}
