import SwiftUI

struct SatelliteDetailView: View {
    let satellite: SatelliteEntity
    @Environment(LocationService.self) private var location
    @Environment(\.appTheme) private var theme
    @AppStorage("useUTC") private var useUTC = false
    @AppStorage("skyView") private var skyView = true
    @AppStorage("compassMode") private var compassMode = false
    @AppStorage("passHours") private var passHours = 48
    @AppStorage("devCrossTrack") private var devCross = 0.0
    @State private var vm: SatelliteDetailViewModel?
    @State private var mode = 0
    @State private var freqMHz = 145.8
    @State private var uplinkMHz: Double? = nil
    @State private var selectedPresetID = RadioPreset.customID

    private var loadKey: String {
        "\(Int((location.observer?.latitude ?? 0) * 100))|\(Int((location.observer?.longitude ?? 0) * 100))|\(passHours)|\(devCross)"
    }

    var body: some View {
        ScrollView {
            if let vm {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    content(vm: vm, now: ctx.date)
                }
            } else {
                ProgressView().padding()
            }
        }
        .navigationTitle(satellite.name)
        .onAppear {
            let saved = UserDefaults.standard.double(forKey: "freq-\(satellite.noradID)")
            if saved > 0 { freqMHz = saved }
            let savedPreset = UserDefaults.standard.string(forKey: "radio-preset-\(satellite.noradID)")
            if let savedPreset, RadioPreset.common.contains(where: { $0.id == savedPreset }) {
                selectedPresetID = savedPreset
                applyRadioPreset(id: savedPreset)
            }
        }
        .onChange(of: freqMHz) { _, v in
            UserDefaults.standard.set(v, forKey: "freq-\(satellite.noradID)")
        }
        .onChange(of: selectedPresetID) { _, id in
            UserDefaults.standard.set(id, forKey: "radio-preset-\(satellite.noradID)")
            applyRadioPreset(id: id)
        }
        .task { vm = SatelliteDetailViewModel(satellite: satellite) }
        .task(id: loadKey) {
            if let o = location.observer, let vm {
                await vm.loadPasses(observer: o, hours: Double(passHours))
            }
        }
        .task(id: mode) {                           // keep the ground track fresh while the map is open
            guard mode == 1 else { return }
            while !Task.isCancelled {
                if let o = location.observer, let vm { vm.refreshGroundTrack(observer: o) }
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    @ViewBuilder
    private func content(vm: SatelliteDetailViewModel, now: Date) -> some View {
        let observer = location.observer
        let live = observer.flatMap { vm.live(at: now, observer: $0) }
        let next = vm.nextPass(after: now)
        let nextTrack = (observer != nil && next != nil) ? vm.track(for: next!, observer: observer!) : []

        VStack(spacing: 16) {
            banner(next: next, now: now)

            Picker("View", selection: $mode) {
                Text("Radar").tag(0)
                Text("Map").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if mode == 0 {
                PolarPlotView(
                    track: nextTrack,
                    current: live.map { PolarPoint(azimuth: $0.look.azimuth, elevation: $0.look.elevation) },
                    skyView: skyView,
                    rotation: compassMode ? (location.heading ?? 0) : 0,
                    accent: theme.accent)
                    .padding(.horizontal)
            } else {
                SatelliteMapView(pastSegments: vm.groundTrackPast,
                                 futureSegments: vm.groundTrackFuture,
                                 position: live?.sub, observer: observer, accent: theme.accent)
                    .padding(.horizontal)
            }

            
            if let l = live {
                let shiftHz = -freqMHz * 1e6 * l.rangeRate / 299_792.458
                let uplinkShiftHz = (uplinkMHz ?? 0) * 1e6 * l.rangeRate / 299_792.458

                VStack(alignment: .leading, spacing: 8) {
                    Text("Radio")
                        .font(.headline)
                    Picker("Preset", selection: $selectedPresetID) {
                        ForEach(RadioPreset.common) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                    }
                    .pickerStyle(.menu)
                    if let preset = RadioPreset.common.first(where: { $0.id == selectedPresetID }) {
                        Text("\(preset.mode) · \(preset.notes)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    row("Latitude", String(format: "%.3f°", l.sub.latitude))
                    row("Longitude", String(format: "%.3f°", l.sub.longitude))
                    row("Altitude", String(format: "%.0f km", l.sub.altitudeKm))
                    row("Speed", String(format: "%.2f km/s", l.speed))
                    row("Range", String(format: "%.0f km", l.look.range))
                    row("Range rate", String(format: "%+.2f km/s", l.rangeRate))
                    row("Azimuth", String(format: "%.1f° %@", l.look.azimuth, Compass.name(l.look.azimuth)))
                    row("Elevation", String(format: "%.1f°", l.look.elevation))

                    Divider().gridCellColumns(2)

                    GridRow {
                        Text("Downlink")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: 4) {
                            TextField("MHz", value: $freqMHz, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 110)

                            Text("MHz")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    row("Downlink Doppler", String(format: "%+.0f Hz", shiftHz))
                    row("Receive at", String(format: "%.6f MHz", freqMHz + shiftHz / 1e6))
                    if let uplinkMHz {
                        row("Uplink", String(format: "%.6f MHz", uplinkMHz))
                        row("Transmit at*", String(format: "%.6f MHz", uplinkMHz + uplinkShiftHz / 1e6))
                    }
                }
                .padding(.horizontal)
                if uplinkMHz != nil {
                    Text("*Estimated Doppler correction; verify radio direction and local operating rules before transmitting.")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            } else {
                Text("Waiting for location…")
                    .foregroundStyle(.secondary)
            }


            if !vm.isDev {
                let age = now.timeIntervalSince(vm.tle.epoch) / 86_400
                if age > 14 {
                    Label(String(format: "TLE is %.0f days old; accuracy degraded", age),
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.orange)
                }
            } else {
                Label("Synthetic orbit for testing: a pass roughly every 8 minutes.",
                      systemImage: "hammer")
                    .font(.caption).foregroundStyle(.secondary)
            }

            NavigationLink {
                PassListView(name: satellite.name, tle: vm.tle, passes: vm.passes)
            } label: {
                Label("Upcoming passes (\(vm.passes.count))", systemImage: "calendar")
            }
            .padding(.bottom)
        }
    }

    private func applyRadioPreset(id: String) {
        guard let preset = RadioPreset.common.first(where: { $0.id == id }) else { return }
        if id != RadioPreset.customID { freqMHz = preset.downlinkMHz }
        uplinkMHz = preset.uplinkMHz
    }

    @ViewBuilder
    private func banner(next: SatPass?, now: Date) -> some View {
        if let p = next {
            VStack(spacing: 2) {
                if p.aos > now {
                    Text("Next pass in \(TimeFormat.countdown(p.aos.timeIntervalSince(now)))")
                        .font(.headline).monospacedDigit()
                    Text("\(TimeFormat.time(p.aos, utc: useUTC)) · max \(Int(p.maxElevation))° · rises \(Compass.name(p.aosAzimuth))")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Overhead now · sets in \(TimeFormat.countdown(p.los.timeIntervalSince(now)))")
                        .font(.headline).monospacedDigit().foregroundStyle(theme.accent)
                    Text("max \(Int(p.maxElevation))° · sets \(Compass.name(p.losAzimuth))")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(.top)
        } else {
            Text("No pass in the next \(passHours) h").font(.subheadline)
                .foregroundStyle(.secondary).padding(.top)
        }
    }

    private func dopplerSection(live l: LiveState) -> some View {
        let shiftHz = -freqMHz * 1e6 * l.rangeRate / 299_792.458
        return VStack(spacing: 6) {
            Divider()
            HStack {
                Text("Downlink").foregroundStyle(.secondary)
                Spacer()
                TextField("MHz", value: $freqMHz, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
                Text("MHz")
            }
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                row("Doppler shift", String(format: "%+.0f Hz", shiftHz))
                row("Receive at", String(format: "%.6f MHz", freqMHz + shiftHz / 1e6))
            }
        }
        .padding(.horizontal)
    }

    
    private func row(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(v)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

}
