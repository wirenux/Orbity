import SwiftUI

/// One pass: its sky track, AOS/TCA/LOS table, a scrubber that moves the satellite ball along
/// the track, and a reminder button.
struct PassDetailView: View {
    let name: String
    let tle: TLE
    let pass: SatPass

    @Environment(LocationService.self) private var location
    @Environment(\.appTheme) private var theme
    @AppStorage("useUTC") private var useUTC = false
    @AppStorage("skyView") private var skyView = true
    @AppStorage("alertLeadMinutes") private var lead = 10
    @AppStorage("nightMode") private var nightMode = false
    @State private var track: [PolarPoint] = []
    @State private var scrub = 0.0
    @State private var reminderScheduled = false
    @State private var reminderMessage: String?

    private var ball: PolarPoint? {
        guard track.count > 1 else { return nil }
        let i = Int((scrub * Double(track.count - 1)).rounded())
        return track[min(max(i, 0), track.count - 1)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PolarPlotView(track: track, current: ball, skyView: skyView, accent: theme.accent)
                    .padding(.horizontal)

                VStack(spacing: 4) {
                    Slider(value: $scrub, in: 0...1)
                    Text(TimeFormat.time(pass.aos.addingTimeInterval(scrub * pass.duration), utc: useUTC))
                        .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow { Text("AOS").foregroundStyle(.secondary)
                        Text("\(TimeFormat.time(pass.aos, utc: useUTC))  \(Int(pass.aosAzimuth))° \(Compass.name(pass.aosAzimuth))").monospacedDigit() }
                    GridRow { Text("TCA").foregroundStyle(.secondary)
                        Text("\(TimeFormat.time(pass.tca, utc: useUTC))  \(Int(pass.tcaAzimuth))° \(Compass.name(pass.tcaAzimuth))").monospacedDigit() }
                    GridRow { Text("LOS").foregroundStyle(.secondary)
                        Text("\(TimeFormat.time(pass.los, utc: useUTC))  \(Int(pass.losAzimuth))° \(Compass.name(pass.losAzimuth))").monospacedDigit() }
                    GridRow { Text("Max elevation").foregroundStyle(.secondary)
                        Text(String(format: "%.1f°", pass.maxElevation)) }
                    GridRow { Text("Duration").foregroundStyle(.secondary)
                        Text("\(Int(pass.duration) / 60) min \(Int(pass.duration) % 60) s") }
                }

                Button {
                    Task {
                        if reminderScheduled {
                            PassNotifier.cancel(
                                noradID: tle.noradID,
                                pass: pass
                            )

                            reminderScheduled = false
                            reminderMessage = "Reminder cancelled."
                        } else {
                            let ok = await PassNotifier.schedule(
                                name: name,
                                noradID: tle.noradID,
                                pass: pass,
                                leadMinutes: lead,
                                prompt: true
                            )

                            reminderScheduled = ok

                            reminderMessage = ok
                                ? "Reminder set for \(lead) min before AOS."
                                : "Couldn't schedule. Check notification permissions or pass timing."
                        }
                    }
                } label: {
                    Label(
                        reminderScheduled
                            ? "Cancel reminder"
                            : "Remind me \(lead) min before",
                        systemImage: reminderScheduled ? "bell.slash" : "bell"
                    )
                }
                .tint(nightMode ? .red : .accentColor)

                if let reminderMessage {
                    Text(reminderMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(name)
        .task {
            reminderScheduled = await PassNotifier.isScheduled(
                noradID: tle.noradID,
                pass: pass
            )
            
            if let o = location.observer, let p = try? PropagatorFactory.make(tle: tle, observer: o) {
                track = PassPredictor(propagator: p, observer: o).track(for: pass)
            }
        }
    }
}
