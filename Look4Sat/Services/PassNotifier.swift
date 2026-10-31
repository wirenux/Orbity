import Foundation
import UserNotifications

enum PassNotifier {
    private static let prefix = "pass-"

    static func isAuthorized() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return s == .authorized || s == .provisional || s == .ephemeral
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func identifier(noradID: Int, pass: SatPass) -> String {
        "\(prefix)\(noradID)-\(Int(pass.aos.timeIntervalSince1970))"
    }

    /// Checks whether this specific pass has a pending notification.
    static func isScheduled(noradID: Int, pass: SatPass) async -> Bool {
        let id = identifier(noradID: noradID, pass: pass)
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.contains { $0.identifier == id }
    }

    /// Cancels the reminder for one specific pass.
    static func cancel(noradID: Int, pass: SatPass) {
        let id = identifier(noradID: noradID, pass: pass)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [id])
    }

    @discardableResult
    static func schedule(
        name: String,
        noradID: Int,
        pass: SatPass,
        leadMinutes: Int,
        prompt: Bool = false
    ) async -> Bool {
        let ok = prompt ? await requestAuthorization() : await isAuthorized()
        guard ok else { return false }

        let delay = pass.aos
            .addingTimeInterval(-Double(leadMinutes) * 60)
            .timeIntervalSinceNow

        guard delay > 1 else { return false }

        let content = UNMutableNotificationContent()
        content.title = "\(name) pass"
        content.body = "Rises in \(leadMinutes) min toward \(Compass.name(pass.aosAzimuth)), max elevation \(Int(pass.maxElevation))°."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier(noradID: noradID, pass: pass),
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: delay,
                repeats: false
            )
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let ids = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }

        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    static func reschedule(
        entries: [PassEntry],
        leadMinutes: Int,
        minElevation: Double
    ) async {
        await cancelAll()

        let upcoming = entries.filter {
            $0.pass.maxElevation >= minElevation
            && $0.pass.aos
                .addingTimeInterval(-Double(leadMinutes) * 60)
                .timeIntervalSinceNow > 1
        }.prefix(60)

        for e in upcoming {
            await schedule(
                name: e.name,
                noradID: e.noradID,
                pass: e.pass,
                leadMinutes: leadMinutes
            )
        }
    }
}
