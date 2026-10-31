import Foundation

/// Editable starting points for common satellite radio modes. Verify current band plans
/// and operating notes before transmitting; frequencies and access tones can change.
struct RadioPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let downlinkMHz: Double
    let uplinkMHz: Double?
    let mode: String
    let notes: String

    static let customID = "custom"
    static let custom = RadioPreset(id: customID, name: "Custom frequency", downlinkMHz: 145.8,
                                    uplinkMHz: nil, mode: "Manual", notes: "Enter your own frequency")

    static let common: [RadioPreset] = [
        RadioPreset(id: "so50", name: "SO-50 (SaudiSat 1C)", downlinkMHz: 436.795,
                    uplinkMHz: 145.850, mode: "FM", notes: "Uplink access tone may be required; check current operating instructions."),
        RadioPreset(id: "noaa15", name: "NOAA 15 APT", downlinkMHz: 137.620,
                    uplinkMHz: nil, mode: "APT / FM", notes: "Weather image downlink; receive only."),
        RadioPreset(id: "noaa18", name: "NOAA 18 APT", downlinkMHz: 137.9125,
                    uplinkMHz: nil, mode: "APT / FM", notes: "Weather image downlink; receive only."),
        RadioPreset(id: "noaa19", name: "NOAA 19 APT", downlinkMHz: 137.100,
                    uplinkMHz: nil, mode: "APT / FM", notes: "Weather image downlink; receive only."),
        .custom
    ]
}
