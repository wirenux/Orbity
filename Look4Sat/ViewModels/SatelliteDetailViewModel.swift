import SwiftUI
import CoreLocation
import simd

struct LiveState {
    var look: LookAngles
    var sub: SubPoint
    var speed: Double          // km/s
    var rangeRate: Double      // km/s, positive = moving away
}

@MainActor @Observable
final class SatelliteDetailViewModel {
    let tle: TLE
    private(set) var passes: [SatPass] = []
    private(set) var groundTrackPast: [[CLLocationCoordinate2D]] = []
    private(set) var groundTrackFuture: [[CLLocationCoordinate2D]] = []
    @ObservationIgnored private var cached: (any OrbitPropagator)?
    @ObservationIgnored private var trackCache: [UUID: [PolarPoint]] = [:]

    init(satellite: SatelliteEntity) {
        self.tle = satellite.tle
    }

    var isDev: Bool { tle.noradID == DevSatellite.noradID }

    private func propagator(for o: Observer) -> (any OrbitPropagator)? {
        if isDev { return try? PropagatorFactory.make(tle: tle, observer: o) }   // cheap, observer-dependent
        if cached == nil { cached = try? PropagatorFactory.make(tle: tle, observer: o) }
        return cached
    }

    func live(at date: Date, observer o: Observer) -> LiveState? {
        guard let p = propagator(for: o) else { return nil }
        let later = date.addingTimeInterval(1)
        guard let s1 = try? p.state(at: date), let s2 = try? p.state(at: later) else { return nil }
        let l1 = Geodesy.lookAngles(teme: s1.position, observer: o, at: date)
        let l2 = Geodesy.lookAngles(teme: s2.position, observer: o, at: later)
        return LiveState(look: l1,
                         sub: Geodesy.subPoint(teme: s1.position, at: date),
                         speed: simd_length(s1.velocity),
                         rangeRate: l2.range - l1.range)
    }

    /// First pass that has not finished yet.
    func nextPass(after date: Date) -> SatPass? {
        passes.first { $0.los > date }
    }

    func track(for pass: SatPass, observer o: Observer) -> [PolarPoint] {
        if let t = trackCache[pass.id] { return t }
        guard let p = propagator(for: o) else { return [] }
        let t = PassPredictor(propagator: p, observer: o).track(for: pass)
        trackCache[pass.id] = t
        return t
    }

    func loadPasses(observer: Observer, hours: Double) async {
        let tle = self.tle
        let found = await Task.detached(priority: .userInitiated) { () -> [SatPass] in
            guard let p = try? PropagatorFactory.make(tle: tle, observer: observer) else { return [] }
            return PassPredictor(propagator: p, observer: observer).passes(from: .now, hours: hours)
        }.value
        trackCache.removeAll()
        passes = found
    }

    /// Sub-satellite track around "now" (±45 min; ±4 min for the fast DEV TEST orbit),
    /// split at the antimeridian and into past/future segments for map styling.
    func refreshGroundTrack(observer o: Observer, around date: Date = .now) {
        guard let p = propagator(for: o) else { return }
        let half = isDev ? 240 : 2700
        var past: [[CLLocationCoordinate2D]] = [[]]
        var future: [[CLLocationCoordinate2D]] = [[]]
        var lastPastLon: Double?
        var lastFutureLon: Double?

        for k in stride(from: -half, through: half, by: 30) {
            let t = date.addingTimeInterval(Double(k))
            guard let state = try? p.state(at: t) else { continue }
            let sub = Geodesy.subPoint(teme: state.position, at: t)
            let coordinate = CLLocationCoordinate2D(latitude: sub.latitude, longitude: sub.longitude)
            if k <= 0 {
                if let last = lastPastLon, abs(sub.longitude - last) > 180 { past.append([]) }
                past[past.count - 1].append(coordinate)
                lastPastLon = sub.longitude
            } else {
                if let last = lastFutureLon, abs(sub.longitude - last) > 180 { future.append([]) }
                future[future.count - 1].append(coordinate)
                lastFutureLon = sub.longitude
            }
        }
        groundTrackPast = past.filter { $0.count > 1 }
        groundTrackFuture = future.filter { $0.count > 1 }
    }
}
