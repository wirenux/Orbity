import BackgroundTasks
import SwiftData

enum RefreshScheduler {
    /// Must also be listed under BGTaskSchedulerPermittedIdentifiers in Info.plist.
    static let identifier = "com.wirenux.Look4Sat.tleRefresh"

    static func register(container: ModelContainer) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            schedule()                                   // queue the next run
            let work = Task {
                await TLEImporter.refreshIfNeeded(container: container)
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
    }

    static func schedule() {
        let hours = UserDefaults.standard.object(forKey: "tleRefreshHours") as? Int ?? 24
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Double(hours) * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
