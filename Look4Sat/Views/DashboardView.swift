import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(filter: #Predicate<SatelliteEntity> { $0.isTracked }, sort: \.name)
    private var tracked: [SatelliteEntity]
    @Environment(PassStore.self) private var passes
    @Environment(LocationService.self) private var location
    @Environment(\.modelContext) private var context
    @AppStorage("passHours") private var passHours = 48
    @AppStorage("devCrossTrack") private var devCross = 0.0

    private var refreshKey: String {
        let o = location.observer
        return "\(tracked.map(\.noradID))|\(Int((o?.latitude ?? 0) * 100))|\(Int((o?.longitude ?? 0) * 100))|\(passHours)|\(devCross)"
    }

    var body: some View {
        NavigationStack {
            Group {
                if tracked.isEmpty {
                    ContentUnavailableView("No tracked satellites",
                                           systemImage: "star",
                                           description: Text("Star satellites in the Satellites tab."))
                } else {
                    List {
                        ForEach(tracked) { sat in
                            NavigationLink(value: sat) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(sat.name)
                                            .font(.headline)

                                        Text("NORAD \(sat.noradID)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                        countdownLabel(for: sat, now: ctx.date)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteSatellites)
                    }
                }
            }
            .navigationTitle("Tracked")
            .navigationDestination(for: SatelliteEntity.self) { SatelliteDetailView(satellite: $0) }
            .safeAreaInset(edge: .top) {
                if location.observer == nil {
                    LocationStatusView()
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.bar)
                }
            }
            .task(id: refreshKey) {
                if let o = location.observer {
                    await passes.refreshIfNeeded(for: tracked, observer: o, hours: Double(passHours))
                }
            }
        }
    }

    @ViewBuilder
    private func countdownLabel(for sat: SatelliteEntity, now: Date) -> some View {
        if let p = passes.nextPass(for: sat.noradID, after: now) {
            VStack(alignment: .trailing) {
                if p.aos > now {
                    Text(TimeFormat.countdown(p.aos.timeIntervalSince(now))).monospacedDigit()
                } else {
                    Text("Overhead").foregroundStyle(.green)
                }
                Text("max \(Int(p.maxElevation))°").font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("—").foregroundStyle(.secondary)
        }
    }
    private func deleteSatellites(at offsets: IndexSet) {
        for index in offsets {
            let satellite = tracked[index]
            satellite.isTracked = false
        }

        do {
            try context.save()
        } catch {
            print("Failed to remove tracked satellite: \(error)")
        }
    }
}
