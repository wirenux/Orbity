import Foundation

struct SatPass: Identifiable, Sendable {
    let id = UUID()
    let aos: Date, tca: Date, los: Date
    let aosAzimuth: Double, tcaAzimuth: Double, losAzimuth: Double   // degrees
    let maxElevation: Double                                         // degrees
    var duration: TimeInterval { los.timeIntervalSince(aos) }
}

struct PolarPoint: Sendable {
    var azimuth: Double      // degrees, 0 = north, clockwise
    var elevation: Double    // degrees
}

struct Observer: Sendable {
    var latitude: Double     // degrees
    var longitude: Double    // degrees
    var altitude: Double     // meters
}

struct LookAngles: Sendable {
    var azimuth: Double
    var elevation: Double
    var range: Double        // km
}

struct SubPoint: Sendable {
    var latitude: Double
    var longitude: Double
    var altitudeKm: Double
}
