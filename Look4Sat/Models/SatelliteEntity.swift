import SwiftData
import Foundation

@Model
final class SatelliteEntity {
    @Attribute(.unique) var noradID: Int
    var name: String
    var line1: String
    var line2: String
    var epoch: Date
    var group: String
    var isTracked: Bool
    var updatedAt: Date

    init(noradID: Int, name: String, line1: String, line2: String,
         epoch: Date, group: String, isTracked: Bool = false) {
        self.noradID = noradID
        self.name = name
        self.line1 = line1
        self.line2 = line2
        self.epoch = epoch
        self.group = group
        self.isTracked = isTracked
        self.updatedAt = .now
    }

    /// Plain Sendable value for crossing into background tasks.
    var tle: TLE {
        TLE(name: name, line1: line1, line2: line2, noradID: noradID, epoch: epoch)
    }
}
