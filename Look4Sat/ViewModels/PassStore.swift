import SwiftUI

struct PassEntry: Identifiable, Sendable {
    let id = UUID()
    let noradID: Int
    let name: String
    let tle: TLE
    let pass: SatPass
}

@MainActor @Observable
final class PassStore {
    /// Every predicted pass for tracked satellites, sorted by AOS.
    private(set) var entries: [PassEntry] = []
    @ObservationIgnored private var lastSignature: String?
    @ObservationIgnored private var lastRun: Date?

    /// First not-yet-finished pass for a satellite.
    func nextPass(for noradID: Int, after date: Date = .now) -> SatPass? {
        entries.first { $0.noradID == noradID && $0.pass.los > date }?.pass
    }

    /// Skips the work if nothing relevant changed in the last 30 minutes.
    func refreshIfNeeded(for sats: [SatelliteEntity], observer: Observer, hours: Double) async {
        let ids = sats.map(\.noradID).sorted().map(String.init).joined(separator: ",")
        let dev = UserDefaults.standard.double(forKey: "devCrossTrack")
        let sig = "\(ids)|\(Int(observer.latitude * 100))|\(Int(observer.longitude * 100))|\(Int(hours))|\(dev)"
        if sig == lastSignature, let lastRun, Date().timeIntervalSince(lastRun) < 1800 { return }
        lastSignature = sig
        lastRun = .now
        await refresh(for: sats, observer: observer, hours: hours)
    }

    func refresh(for sats: [SatelliteEntity], observer: Observer, hours: Double) async {
        let tles = sats.map(\.tle)                       // plain values cross the actor boundary
        let result = await Task.detached(priority: .utility) { () -> [PassEntry] in
            var out: [PassEntry] = []
            for tle in tles {
                guard let p = try? PropagatorFactory.make(tle: tle, observer: observer) else { continue }
                let predictor = PassPredictor(propagator: p, observer: observer)
                for pass in predictor.passes(from: .now, hours: hours) {
                    out.append(PassEntry(noradID: tle.noradID, name: tle.name, tle: tle, pass: pass))
                }
            }
            return out.sorted { $0.pass.aos < $1.pass.aos }
        }.value
        entries = result
        await rescheduleAlerts()
    }

    func rescheduleAlerts() async {
        let d = UserDefaults.standard
        guard d.bool(forKey: "passAlerts") else { await PassNotifier.cancelAll(); return }
        let lead = d.object(forKey: "alertLeadMinutes") as? Int ?? 10
        await PassNotifier.reschedule(entries: entries,
                                      leadMinutes: lead,
                                      minElevation: d.double(forKey: "minPassElevation"))
    }
}
