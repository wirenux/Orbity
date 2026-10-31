import Foundation

enum TimeFormat {
    static func time(_ d: Date, utc: Bool) -> String {
        format(d, "HH:mm:ss", utc) + (utc ? " UTC" : "")
    }

    static func dateTime(_ d: Date, utc: Bool) -> String {
        format(d, "EEE d MMM HH:mm", utc) + (utc ? " UTC" : "")
    }

    static func countdown(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    private static func format(_ d: Date, _ pattern: String, _ utc: Bool) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = utc ? TimeZone(identifier: "UTC") : .current
        f.dateFormat = pattern
        return f.string(from: d)
    }
}

enum Compass {
    private static let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

    static func name(_ azimuth: Double) -> String {
        let a = (azimuth + 22.5).truncatingRemainder(dividingBy: 360)
        return dirs[Int((a < 0 ? a + 360 : a) / 45) % 8]
    }
}
