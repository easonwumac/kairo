import Foundation

public struct KairoUITestingActionFactory: Sendable {
    public var memoryStore: any MemoryStore
    public var auditLogger: any AuditLogger

    public init(memoryStore: any MemoryStore, auditLogger: any AuditLogger) {
        self.memoryStore = memoryStore
        self.auditLogger = auditLogger
    }

    public func makeActionExecutor() -> any ActionExecutor {
        SandboxActionExecutor(
            memoryStore: memoryStore,
            reminderScheduler: AllowingReminderScheduler(identifier: "ui-testing-reminder-id"),
            calendarScheduler: AllowingCalendarScheduler(identifier: "ui-testing-calendar-event-id"),
            contactScheduler: AllowingContactScheduler(identifier: "ui-testing-contact-id"),
            urlOpener: AllowingURLOpener(),
            notificationScheduler: AllowingNotificationScheduler(identifier: "ui-testing-notification-id"),
            auditLogger: auditLogger
        )
    }
}
