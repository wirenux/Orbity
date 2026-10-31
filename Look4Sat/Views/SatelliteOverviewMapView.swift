import SwiftUI
import SwiftData
import MapKit

/// Map of all starred/tracked satellites, each with a stable, distinct color.
struct SatelliteOverviewMapView: View {
    @Query(filter: #Predicate<SatelliteEntity> { $0.isTracked }, sort: \SatelliteEntity.name)
    private var tracked: [SatelliteEntity]
    @Environment(LocationService.self) private var location
    @Environment(\.appTheme) private var theme

    @State private var positions: [SatelliteMapPosition] = []
    @State private var selectedSatellite: SatelliteEntity?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var lastUpdated: Date?

    private let refreshInterval: Duration = .seconds(5)

    var body: some View {
        NavigationStack {
            Group {
                if tracked.isEmpty {
                    ContentUnavailableView(
                        "No tracked satellites",
                        systemImage: "map",
                        description: Text("Star satellites in the Satellites tab to show them here.")
                    )
                } else {
                    VStack(spacing: 0) {
                        Map(position: $cameraPosition) {
                            ForEach(positions) { item in
                                // Historical path is dashed; predicted path is solid.
                                // Segments are split at the antimeridian to avoid lines across the map.
                                ForEach(item.pastTracks.indices, id: \.self) { index in
                                    MapPolyline(coordinates: item.pastTracks[index])
                                        .stroke(
                                            item.color.opacity(0.55),
                                            style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 5])
                                        )
                                }
                                ForEach(item.futureTracks.indices, id: \.self) { index in
                                    MapPolyline(coordinates: item.futureTracks[index])
                                        .stroke(
                                            item.color,
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                }

                                Annotation(item.name, coordinate: item.coordinate, anchor: .bottom) {
                                    Button {
                                        selectedSatellite = tracked.first { $0.noradID == item.noradID }
                                    } label: {
                                        VStack(spacing: 3) {
                                            Image(systemName: item.noradID == DevSatellite.noradID ? "testtube.2" : "antenna.radiowaves.left.and.right")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundStyle(.white)
                                                .frame(width: 31, height: 31)
                                                .background(item.color, in: Circle())
                                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                                            Text(item.name)
                                                .font(.caption2.weight(.semibold))
                                                .lineLimit(1)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(.regularMaterial, in: Capsule())
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Show \(item.name) details")
                                }
                            }
                            if let observer = location.observer {
                                Marker("You", systemImage: "location.fill",
                                       coordinate: CLLocationCoordinate2D(latitude: observer.latitude,
                                                                          longitude: observer.longitude))
                                    .tint(theme.accent)
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic))
                        .overlay(alignment: .bottomTrailing) {
                            HStack(spacing: 10) {
                                HStack(spacing: 4) {
                                    Capsule().fill(.secondary.opacity(0.7)).frame(width: 20, height: 2)
                                    Text("Past")
                                }
                                HStack(spacing: 4) {
                                    Capsule().fill(.primary).frame(width: 20, height: 3)
                                    Text("Predicted")
                                }
                            }
                            .font(.caption2)
                            .padding(8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(10)
                        }
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 6) {
                                Circle().fill(.green).frame(width: 7, height: 7)
                                Text("Live positions · refreshes every 5 seconds")
                                    .font(.caption2)
                            }
                            .padding(8)
                            .background(.regularMaterial, in: Capsule())
                            .padding(10)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tracked satellites")
                                    .font(.headline)
                                Spacer()
                                Text("\(positions.count) visible")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if positions.isEmpty {
                                Text("Calculating satellite positions…")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(positions) { item in
                                            Button {
                                                selectedSatellite = tracked.first { $0.noradID == item.noradID }
                                                cameraPosition = .region(MKCoordinateRegion(
                                                    center: item.coordinate,
                                                    span: MKCoordinateSpan(latitudeDelta: 35, longitudeDelta: 35)
                                                ))
                                            } label: {
                                                HStack(spacing: 6) {
                                                    Circle().fill(item.color).frame(width: 9, height: 9)
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(item.name).font(.caption.weight(.medium)).lineLimit(1)
                                                        Text(String(format: "%.1f°, %.1f°", item.latitude, item.longitude))
                                                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                                    }
                                                }
                                                .padding(8)
                                                .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                            if let lastUpdated {
                                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding()
                        .background(.bar)
                    }
                }
            }
            .navigationTitle("Satellite Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedSatellite) { satellite in
                NavigationStack {
                    SatelliteDetailView(satellite: satellite)
                }
            }
            .task(id: tracked.map(\.noradID)) {
                await refreshLoop()
            }
        }
    }

    @MainActor
    private func refreshLoop() async {
        while !Task.isCancelled {
            refreshPositions()
            do {
                try await Task.sleep(for: refreshInterval)
            } catch {
                return
            }
        }
    }

    @MainActor
    private func refreshPositions() {
        let now = Date()
        let observer = location.observer
        let fallbackObserver = Observer(latitude: 0, longitude: 0, altitude: 0)
        let ordered = tracked.sorted { $0.noradID < $1.noradID }
        let palette: [Color] = [
            .red, .blue, .green, .orange, .purple, .pink, .teal, .indigo,
            .mint, .cyan, .brown, .yellow
        ]

        var next: [SatelliteMapPosition] = []
        for (index, satellite) in ordered.enumerated() {
            // The synthetic developer satellite depends on a real observer location.
            if satellite.noradID == DevSatellite.noradID && observer == nil { continue }
            do {
                let propagator = try PropagatorFactory.make(
                    tle: satellite.tle,
                    observer: observer ?? fallbackObserver
                )
                let state = try propagator.state(at: now)
                let subpoint = Geodesy.subPoint(teme: state.position, at: now)
                guard subpoint.latitude.isFinite, subpoint.longitude.isFinite else { continue }

                // Show a short history and predicted ground track. The synthetic test
                // satellite has a much shorter orbit, so use a shorter horizon for it.
                let isDevSatellite = satellite.noradID == DevSatellite.noradID
                let horizon = isDevSatellite ? 240.0 : 5_400.0
                let step = isDevSatellite ? 10.0 : 60.0
                var pastTracks: [[CLLocationCoordinate2D]] = [[]]
                var futureTracks: [[CLLocationCoordinate2D]] = [[]]
                var lastPastLongitude: Double?
                var lastFutureLongitude: Double?

                for offset in stride(from: -horizon, through: horizon, by: step) {
                    let sampleDate = now.addingTimeInterval(offset)
                    guard let sample = try? propagator.state(at: sampleDate) else { continue }
                    let point = Geodesy.subPoint(teme: sample.position, at: sampleDate)
                    guard point.latitude.isFinite, point.longitude.isFinite else { continue }
                    let coordinate = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)

                    if offset <= 0 {
                        if let previous = lastPastLongitude, abs(point.longitude - previous) > 180 {
                            pastTracks.append([])
                        }
                        pastTracks[pastTracks.count - 1].append(coordinate)
                        lastPastLongitude = point.longitude
                    } else {
                        if let previous = lastFutureLongitude, abs(point.longitude - previous) > 180 {
                            futureTracks.append([])
                        }
                        futureTracks[futureTracks.count - 1].append(coordinate)
                        lastFutureLongitude = point.longitude
                    }
                }

                next.append(SatelliteMapPosition(
                    noradID: satellite.noradID,
                    name: satellite.name,
                    latitude: subpoint.latitude,
                    longitude: subpoint.longitude,
                    altitudeKm: subpoint.altitudeKm,
                    color: palette[index % palette.count],
                    pastTracks: pastTracks.filter { $0.count > 1 },
                    futureTracks: futureTracks.filter { $0.count > 1 }
                ))
            } catch {
                // Skip an invalid/stale TLE without preventing other satellites from appearing.
                continue
            }
        }
        positions = next
        lastUpdated = now
    }
}

private struct SatelliteMapPosition: Identifiable {
    var id: Int { noradID }
    let noradID: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let altitudeKm: Double
    let color: Color
    let pastTracks: [[CLLocationCoordinate2D]]
    let futureTracks: [[CLLocationCoordinate2D]]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
