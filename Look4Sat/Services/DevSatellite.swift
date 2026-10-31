import Foundation
import SwiftData

enum DevSatellite {
    static let noradID = 99999
    static let name = "DEV TEST"

    /// Inserts (tracked) or removes the DEV TEST satellite. Its TLE lines are placeholders;
    /// PropagatorFactory never parses them.
    @MainActor
    static func sync(enabled: Bool, container: ModelContainer) {
        sync(enabled: enabled, context: container.mainContext)
    }

    @MainActor
    static func sync(enabled: Bool, context: ModelContext) {
        let id = noradID
        let existing = try? context.fetch(
            FetchDescriptor<SatelliteEntity>(predicate: #Predicate { $0.noradID == id })
        ).first
        if enabled {
            if existing == nil {
                context.insert(SatelliteEntity(noradID: id, name: name,
                                               line1: "DEV", line2: "DEV",
                                               epoch: .now, group: "dev", isTracked: true))
            }
        } else if let existing {
            context.delete(existing)
        }
        try? context.save()
    }
}
