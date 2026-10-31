import SwiftUI

/// Shared row used by the per-satellite and combined pass lists.
struct PassRow: View {
    var title: String? = nil
    let pass: SatPass
    var noradID: Int? = nil

    @AppStorage("useUTC") private var useUTC = false

    @State private var reminderScheduled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title {
                Text(title).font(.headline)
            }

            HStack {
                Text(TimeFormat.dateTime(pass.aos, utc: useUTC))
                    .font(title == nil ? .headline : .subheadline)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(pass.maxElevation))°")
                        .bold()
                        .monospacedDigit()

                    Text(qualityLabel(pass.maxElevation))
                        .font(.caption2)
                        .foregroundStyle(qualityColor(pass.maxElevation))
                }
            }

            Text("\(Compass.name(pass.aosAzimuth)) → \(Compass.name(pass.tcaAzimuth)) → \(Compass.name(pass.losAzimuth))"
                 + " · \(Int(pass.duration) / 60) min \(Int(pass.duration) % 60) s")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let noradID {
                HStack(spacing: 5) {
                    Image(systemName: reminderScheduled ? "bell.badge.fill" : "bell")
                    Text(reminderScheduled ? "Reminder set" : "No reminder")
                }
                .font(.caption2)
                .foregroundStyle(reminderScheduled ? .green : .secondary)
            }
        }
        .task(id: noradID.map { PassNotifier.identifier(noradID: $0, pass: pass) }) {
            guard let noradID else {
                reminderScheduled = false
                return
            }

            reminderScheduled = await PassNotifier.isScheduled(
                noradID: noradID,
                pass: pass
            )
        }
    }

    private func qualityLabel(_ elevation: Double) -> String {
        switch elevation {
        case 60...: return "Excellent"
        case 30..<60: return "Good"
        case 10..<30: return "Fair"
        default: return "Low"
        }
    }

    private func qualityColor(_ elevation: Double) -> Color {
        elevation >= 60 ? .green :
        elevation >= 30 ? .blue :
        elevation >= 10 ? .orange : .secondary
    }
}

struct PassListView: View {
    let name: String
    let tle: TLE
    let passes: [SatPass]
    @AppStorage("minPassElevation") private var minElevation = 0.0
    @AppStorage("minPassDurationMinutes") private var minDurationMinutes = 0.0
    @State private var sortByElevation = false

    var body: some View {
        let now = Date()
        let filtered = passes.filter {
            $0.los > now && $0.maxElevation >= minElevation && $0.duration >= minDurationMinutes * 60
        }
        let shown = sortByElevation ? filtered.sorted { $0.maxElevation > $1.maxElevation } : filtered.sorted { $0.aos < $1.aos }
        List {
            Section {
                Slider(value: $minElevation, in: 0...90, step: 5)
                Text("Minimum peak elevation: \(Int(minElevation))°").font(.caption)
                Slider(value: $minDurationMinutes, in: 0...20, step: 1)
                Text("Minimum duration: \(Int(minDurationMinutes)) min").font(.caption)
                Toggle("Sort by highest elevation", isOn: $sortByElevation)
            }
            Section("\(shown.count) passes") {
                ForEach(shown) { p in
                    NavigationLink {
                        PassDetailView(name: name, tle: tle, pass: p)
                    } label: {
                        PassRow(pass: p, noradID: tle.noradID)
                    }
                }
            }
        }
        .navigationTitle("Passes")
    }
}
