import Foundation

struct PassPredictor {
    let propagator: OrbitPropagator
    let observer: Observer
    var coarseStep: TimeInterval = 20

    private func angles(at t: Date) -> LookAngles? {
        guard let s = try? propagator.state(at: t) else { return nil }
        return Geodesy.lookAngles(teme: s.position, observer: observer, at: t)
    }

    func passes(from start: Date, hours: Double, minPeakElevation: Double = 0) -> [SatPass] {
        let end = start.addingTimeInterval(hours * 3600)
        var out: [SatPass] = []

        var t = start
        guard var prev = angles(at: t) else { return [] }
        var aos: Date? = prev.elevation > 0 ? start : nil

        while t < end {
            let next = t.addingTimeInterval(coarseStep)
            guard let cur = angles(at: next) else { t = next; continue }

            if prev.elevation <= 0, cur.elevation > 0 {
                aos = refine(from: t, to: next, rising: true)
            } else if prev.elevation > 0, cur.elevation <= 0, let a = aos {
                let los = refine(from: t, to: next, rising: false)
                if let pass = build(aos: a, los: los), pass.maxElevation >= minPeakElevation {
                    out.append(pass)
                }
                aos = nil
            }
            prev = cur
            t = next
        }
        return out
    }

    /// Samples the pass trajectory for the polar plot.
    func track(for pass: SatPass, step: TimeInterval = 10) -> [PolarPoint] {
        var pts: [PolarPoint] = []
        var t = pass.aos
        while !(t > pass.los) {
            if let a = angles(at: t) { pts.append(PolarPoint(azimuth: a.azimuth, elevation: a.elevation)) }
            t = t.addingTimeInterval(step)
        }
        if let a = angles(at: pass.los) { pts.append(PolarPoint(azimuth: a.azimuth, elevation: max(0, a.elevation))) }
        return pts
    }

    /// Bisection on the elevation = 0 crossing.
    private func refine(from lo: Date, to hi: Date, rising: Bool) -> Date {
        var lo = lo, hi = hi
        for _ in 0..<20 {
            let mid = lo.addingTimeInterval(hi.timeIntervalSince(lo) / 2)
            let above = (angles(at: mid)?.elevation ?? -1) > 0
            if above == rising { hi = mid } else { lo = mid }
        }
        return hi
    }

    private func build(aos: Date, los: Date) -> SatPass? {
        // Golden-section search for max elevation (unimodal within a pass).
        let phi = (5.0.squareRoot() - 1) / 2
        var a = aos.timeIntervalSince1970, b = los.timeIntervalSince1970
        func el(_ x: Double) -> Double {
            angles(at: Date(timeIntervalSince1970: x))?.elevation ?? -90
        }
        var c = b - phi * (b - a), d = a + phi * (b - a)
        for _ in 0..<30 {
            if el(c) > el(d) { b = d } else { a = c }
            c = b - phi * (b - a); d = a + phi * (b - a)
        }
        let tca = Date(timeIntervalSince1970: (a + b) / 2)
        guard let pk = angles(at: tca),
              let aa = angles(at: aos.addingTimeInterval(0.5)),
              let la = angles(at: los.addingTimeInterval(-0.5)) else { return nil }
        return SatPass(aos: aos, tca: tca, los: los,
                       aosAzimuth: aa.azimuth, tcaAzimuth: pk.azimuth, losAzimuth: la.azimuth,
                       maxElevation: pk.elevation)
    }
}
