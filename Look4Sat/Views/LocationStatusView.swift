import SwiftUI

struct LocationStatusView: View {
    @Environment(LocationService.self) private var location

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let o = location.observer {
                Label(String(format: "%.4f, %.4f", o.latitude, o.longitude),
                      systemImage: "location.fill")
            } else {
                Label("No location yet", systemImage: "location.slash")
                    .foregroundStyle(.secondary)
            }

            switch location.authorization {
            case .denied, .restricted:
                Text("Location access is off for this app.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            default:
                Button("Use my location") { location.requestLocation() }
            }

            if let e = location.lastError {
                Text(e).font(.caption).foregroundStyle(.red)
            }
        }
    }
}
