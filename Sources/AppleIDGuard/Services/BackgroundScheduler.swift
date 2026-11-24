import Foundation

#if os(iOS)
import BackgroundTasks
#endif

public enum BackgroundTaskIdentifiers {
    public static let refresh = "com.skat.appleidguard.refresh"
    public static let processing = "com.skat.appleidguard.processing"
}

public protocol BackgroundScanHandler: Sendable {
    func performBackgroundScan() async
}

public enum BackgroundScheduler {
    #if os(iOS)
    @MainActor
    public static func register(handler: BackgroundScanHandler) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifiers.refresh,
            using: nil
        ) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleRefresh(task: refreshTask, handler: handler)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: BackgroundTaskIdentifiers.processing,
            using: nil
        ) { task in
            guard let processingTask = task as? BGProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handleProcessing(task: processingTask, handler: handler)
        }
    }

    @MainActor
    public static func scheduleNextRefresh(settings: GuardSettings) {
        guard settings.backgroundRefreshEnabled else { return }

        let request = BGAppRefreshTaskRequest(identifier: BackgroundTaskIdentifiers.refresh)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)

        let processing = BGProcessingTaskRequest(identifier: BackgroundTaskIdentifiers.processing)
        processing.requiresNetworkConnectivity = false
        processing.requiresExternalPower = false
        processing.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(processing)
    }

    private static func handleRefresh(task: BGAppRefreshTask, handler: BackgroundScanHandler) {
        let work = Task {
            await handler.performBackgroundScan()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }

    private static func handleProcessing(task: BGProcessingTask, handler: BackgroundScanHandler) {
        let work = Task {
            await handler.performBackgroundScan()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
    #else
    @MainActor
    public static func register(handler: BackgroundScanHandler) {}

    @MainActor
    public static func scheduleNextRefresh(settings: GuardSettings) {}
    #endif
}
