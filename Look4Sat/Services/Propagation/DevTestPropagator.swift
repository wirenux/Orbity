import Foundation
import simd

extension Geodesy {
    /// Inverse of `temeToECEF` (same rotation by GMST, opposite direction).
    static func ecefToTEME(_ r: SIMD3<Double>, at date: Date) -> SIMD3<Double> {
        let th = gmst(date), c = cos(th), s = sin(th)
        return SIMD3(r.x * c - r.y * s, r.x * s + r.y * c, r.z)
    }
}

/// Synthetic satellite for testing every feature without waiting for a real pass.
///
/// It flies a great-circle ground track (fixed in the Earth frame) that passes
/// `crossTrackDeg` degrees away from the observer, at `altitudeKm`, completing one lap every
/// `cycle` seconds. Passes are therefore centered on the middle of every cycle
/// (unix time mod 480 s == 240 s), about every 8 minutes, lasting roughly 108 s.
/// crossTrackDeg 0 gives a zenith pass; larger values give lower passes.
struct DevTestPropagator: OrbitPropagator {
    var observer: Observer
    var crossTrackDeg: Double = 0
    var altitudeKm: Double = 2000
    var cycle: TimeInterval = 480
    var headingDeg: Double = 20

    func state(at date: Date) throws -> (position: SIMD3<Double>, velocity: SIMD3<Double>) {
        let up = simd_normalize(Geodesy.observerECEF(observer))
        let lat = observer.latitude * .pi / 180, lon = observer.longitude * .pi / 180
        let east = SIMD3(-sin(lon), cos(lon), 0.0)
        let north = SIMD3(-sin(lat) * cos(lon), -sin(lat) * sin(lon), cos(lat))

        let h = headingDeg * .pi / 180
        let t0 = north * cos(h) + east * sin(h)
        let t = simd_normalize(t0 - up * simd_dot(t0, up))     // tangent along track
        let side = simd_cross(up, t)                           // cross-track direction

        let delta = crossTrackDeg * .pi / 180
        let u = up * cos(delta) + side * sin(delta)            // closest-approach direction

        let frac = date.timeIntervalSince1970.truncatingRemainder(dividingBy: cycle) / cycle
        let theta = 2 * Double.pi * (frac - 0.5)               // closest approach at mid-cycle

        let radius = Geodesy.a + altitudeKm
        let dir = u * cos(theta) + t * sin(theta)
        let tangent = t * cos(theta) - u * sin(theta)
        let omega = 2 * Double.pi / cycle

        return (Geodesy.ecefToTEME(dir * radius, at: date),
                Geodesy.ecefToTEME(tangent * (radius * omega), at: date))
    }
}

enum PropagatorFactory {
    /// Returns the DEV TEST propagator for the dev satellite, SGP4 for everything else.
    static func make(tle: TLE, observer: Observer) throws -> any OrbitPropagator {
        if tle.noradID == DevSatellite.noradID {
            let cross = UserDefaults.standard.double(forKey: "devCrossTrack")
            return DevTestPropagator(observer: observer, crossTrackDeg: cross)
        }
        return try SGP4Propagator(tle: tle)
    }
}
