import Foundation
import simd
import SatelliteKit

/// Adapter around SatelliteKit (https://github.com/gavineadie/SatelliteKit).
struct SGP4Propagator: OrbitPropagator {
    private let satellite: Satellite
    private let epoch: Date

    init(tle: TLE) throws {
        let elements = try Elements(tle.name, tle.line1, tle.line2)
        self.satellite = Satellite(elements: elements)
        self.epoch = tle.epoch
    }

    func state(at date: Date) throws -> (position: SIMD3<Double>, velocity: SIMD3<Double>) {
        let minutes = date.timeIntervalSince(epoch) / 60
        let p = try satellite.position(minsAfterEpoch: minutes)    // km, TEME
        let v = try satellite.velocity(minsAfterEpoch: minutes)    // km/s, TEME
        return (SIMD3(p.x, p.y, p.z), SIMD3(v.x, v.y, v.z))
    }
}
