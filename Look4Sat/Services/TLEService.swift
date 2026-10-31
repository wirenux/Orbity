import Foundation
import SwiftData

enum TLEGroup: String, CaseIterable, Identifiable, Sendable {
    case stations, weather, noaa, amateur, visual, starlink, active
    var id: String { rawValue }
    var url: URL {
        URL(string: "https://celestrak.org/NORAD/elements/gp.php?GROUP=\(rawValue)&FORMAT=tle")!
    }
}

actor TLEService {
    func download(_ group: TLEGroup) async throws -> [TLE] {
        let (data, response) = try await URLSession.shared.data(from: group.url)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8) else {
            throw URLError(.badServerResponse)
        }
        return TLEParser.parse(text)
    }
}

@ModelActor
actor TLEStore {
    func upsert(_ tles: [TLE], group: String) throws {
        for t in tles {
            let id = t.noradID
            let existing = try modelContext.fetch(
                FetchDescriptor<SatelliteEntity>(predicate: #Predicate { $0.noradID == id })
            ).first
            if let s = existing {
                s.name = t.name; s.line1 = t.line1; s.line2 = t.line2
                s.epoch = t.epoch; s.updatedAt = .now
            } else {
                modelContext.insert(SatelliteEntity(
                    noradID: id, name: t.name, line1: t.line1,
                    line2: t.line2, epoch: t.epoch, group: group))
            }
        }
        try modelContext.save()
    }
}

/// Downloads default groups when the cache is older than the user's refresh interval.
enum TLEImporter {
    static let lastRefreshKey = "tleLastRefresh"
    static let defaultGroups: [TLEGroup] = [.stations, .weather, .amateur]

    static func refreshIfNeeded(container: ModelContainer, force: Bool = false) async {
        let hours = UserDefaults.standard.object(forKey: "tleRefreshHours") as? Int ?? 24
        let last = UserDefaults.standard.object(forKey: lastRefreshKey) as? Date
        if !force, let last, Date().timeIntervalSince(last) < Double(hours) * 3600 { return }

        let service = TLEService()
        let store = TLEStore(modelContainer: container)
        var ok = false
        for group in defaultGroups {                // sequential: be polite to CelesTrak
            do {
                let tles = try await service.download(group)
                try await store.upsert(tles, group: group.rawValue)
                ok = true
            } catch {
                print("TLE refresh failed for \(group.rawValue): \(error)")
            }
        }
        if ok { UserDefaults.standard.set(Date(), forKey: lastRefreshKey) }
    }
}
