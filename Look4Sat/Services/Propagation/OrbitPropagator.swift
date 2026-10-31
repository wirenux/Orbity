import Foundation
import simd

protocol OrbitPropagator {
    /// TEME position (km) and velocity (km/s) at a given instant.
    func state(at date: Date) throws -> (position: SIMD3<Double>, velocity: SIMD3<Double>)
}
