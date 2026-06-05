import Foundation

public struct KairoLiveActionFactory: Sendable {
    public var memoryStore: any MemoryStore
    public var auditLogger: any AuditLogger
    public var urlOpener: (any URLOpener)?
    public var notificationScheduler: (any NotificationScheduling)?

    public init(
        memoryStore: any MemoryStore,
        auditLogger: any AuditLogger,
        urlOpener: (any URLOpener)? = nil,
        notificationScheduler: (any NotificationScheduling)? = nil
    ) {
        self.memoryStore = memoryStore
        self.auditLogger = auditLogger
        self.urlOpener = urlOpener
        self.notificationScheduler = notificationScheduler
    }

    public func makeActionExecutor() -> any ActionExecutor {
        SandboxActionExecutor(
            memoryStore: memoryStore,
            urlOpener: urlOpener ?? Self.platformURLOpener(),
            notificationScheduler: notificationScheduler ?? Self.platformNotificationScheduler(),
            auditLogger: auditLogger
        )
    }

    public static func platformURLOpener() -> any URLOpener {
        #if canImport(UIKit)
        UIApplicationURLOpener()
        #else
        NoOpURLOpener()
        #endif
    }

    public static func platformNotificationScheduler() -> any NotificationScheduling {
        #if canImport(UserNotifications)
        UserNotificationScheduler()
        #else
        UnavailableNotificationScheduler()
        #endif
    }
}
