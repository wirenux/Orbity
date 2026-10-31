import SwiftUI
import MapKit

struct SatelliteMapView: View {
    let pastSegments: [[CLLocationCoordinate2D]]
    let futureSegments: [[CLLocationCoordinate2D]]
    let position: SubPoint?
    let observer: Observer?
    var accent: Color = .green

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map(initialPosition: .automatic) {
                ForEach(pastSegments.indices, id: \.self) { i in
                    MapPolyline(coordinates: pastSegments[i])
                        .stroke(.secondary.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [5, 4]))
                }
                ForEach(futureSegments.indices, id: \.self) { i in
                    MapPolyline(coordinates: futureSegments[i])
                        .stroke(accent, lineWidth: 2.5)
                }
                if let p = position {
                    let coordinate = CLLocationCoordinate2D(latitude: p.latitude, longitude: p.longitude)
                    MapCircle(center: coordinate, radius: footprintRadius(altitudeKm: p.altitudeKm))
                        .foregroundStyle(accent.opacity(0.13))
                        .stroke(accent.opacity(0.75), lineWidth: 1)
                    Annotation("Satellite", coordinate: coordinate) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(accent, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                    }
                }
                if let o = observer {
                    Marker("You", systemImage: "location.fill",
                           coordinate: CLLocationCoordinate2D(latitude: o.latitude, longitude: o.longitude))
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 14) {
                legend(color: .secondary, dashed: true, label: "Past track")
                legend(color: accent, dashed: false, label: "Future track")
                Spacer(minLength: 0)
                Label("Footprint", systemImage: "circle.dashed")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func legend(color: Color, dashed: Bool, label: String) -> some View {
        HStack(spacing: 5) {
            Path { path in path.move(to: CGPoint(x: 0, y: 4)); path.addLine(to: CGPoint(x: 22, y: 4)) }
                .stroke(color, style: StrokeStyle(lineWidth: 2, dash: dashed ? [4, 3] : []))
                .frame(width: 22, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// Great-circle horizon radius, in metres, approximated on a spherical Earth.
    private func footprintRadius(altitudeKm: Double) -> Double {
        let earthRadius = Geodesy.a
        let altitude = max(altitudeKm, 0)
        return earthRadius * acos(earthRadius / (earthRadius + altitude)) * 1000
    }
}
