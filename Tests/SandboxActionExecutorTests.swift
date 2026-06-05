import XCTest
@testable import KairoCore

final class SandboxActionExecutorTests: XCTestCase {
    func testSandboxActionExecutorSavesConfirmedMemory() async throws {
        let store = InMemoryMemoryStore()
        let executor = SandboxActionExecutor(memoryStore: store)
        let action = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "User asked Kairo to remember this.",
            payload: .text("Remember that Kairo must not overclaim sandbox access."),
            riskTier: .tier2LowRiskWrite
        )

        let unconfirmed = try await executor.execute(action, confirmed: false)
        XCTAssertFalse(unconfirmed.completed)

        let confirmed = try await executor.execute(action, confirmed: true)
        XCTAssertTrue(confirmed.completed)
        XCTAssertNotNil(confirmed.createdIdentifier)

        let memories = try await store.search(query: "overclaim", limit: 10)
        XCTAssertEqual(memories.count, 1)
    }

    func testSandboxActionExecutorReportsUnsupportedSandboxActionWithoutExecuting() async throws {
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        let action = AgentAction(
            kind: .unsupportedSandboxAction,
            title: "Read another app",
            rationale: "The user asked for cross-app data access.",
            payload: .unsupported(UnsupportedActionExplanation(
                requestedAction: "Read messages from another app",
                reason: "iOS does not expose another app's private container to Kairo",
                safeAlternative: "Ask the user to share the content into Kairo"
            )),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: false)

        XCTAssertFalse(result.completed)
        XCTAssertTrue(result.message.contains(KairoL10n.string(
            "chat.action.executor.unsupportedSandbox",
            "iOS does not expose another app's private container to Kairo",
            ""
        )))
        XCTAssertTrue(result.message.contains("share the content"))
    }

    func testSandboxActionExecutorOpensURLThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openURL,
            title: "Open website",
            rationale: "User asked to open a visible URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        let openedURLs = await opener.openedURLs
        XCTAssertEqual(openedURLs, [URL(string: "https://example.com")!])
    }

    func testSandboxActionExecutorOpensConfirmedShortcutHandoffURLThroughInjectedOpener() async throws {
        let handoffURL = try ShortcutHandoffService().runShortcutURL(for: ShortcutHandoffRequest(
            shortcutName: "Kairo Daily Briefing",
            input: ShortcutNodeInput(text: "Action: Review Shortcut handoff"),
            callbackBaseURL: URL(string: "kairo://shortcuts/callback")!,
            requestID: "handoff-123"
        ))
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openURL,
            title: "Run Shortcut",
            rationale: "User confirmed a visible Shortcuts handoff.",
            payload: .url(handoffURL.absoluteString),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        let openedURLs = await opener.openedURLs
        XCTAssertEqual(openedURLs, [handoffURL])
    }

    func testSandboxActionExecutorOpensEmailDraftHandoffThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .composeEmailDraft,
            title: "Compose Email Draft",
            rationale: "User confirmed Kairo may prepare a visible email draft handoff.",
            payload: .email(EmailDraft(
                to: ["alex@example.com"],
                subject: "Kairo update",
                body: "Please review the roadmap."
            )),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.result.email.success"))
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "mailto")
        XCTAssertTrue(openedURL.absoluteString.contains("alex@example.com"))
        XCTAssertTrue(openedURL.absoluteString.contains("subject=Kairo%20update"))
        XCTAssertTrue(openedURL.absoluteString.contains("body=Please%20review%20the%20roadmap."))
    }

    func testSandboxActionExecutorOpensMapDirectionsHandoffThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openMapDirections,
            title: "Open Apple Maps Directions",
            rationale: "User confirmed Kairo may open a visible Apple Maps directions handoff.",
            payload: .mapDirections(MapDirectionsDraft(destinationQuery: "Apple Park", mode: .driving)),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.result.maps.success"))
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host(), "maps.apple.com")
        XCTAssertTrue(openedURL.absoluteString.contains("daddr=Apple%20Park"))
        XCTAssertTrue(openedURL.absoluteString.contains("dirflg=d"))
    }

    func testSandboxActionExecutorOpensMessageHandoffThroughInjectedOpenerWithoutBodyInURL() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openMessageHandoff,
            title: "Open Messages Handoff",
            rationale: "User confirmed Kairo may open a visible Messages recipient handoff.",
            payload: .message(MessageDraft(recipients: ["0912-345-678"], body: "I am running late.")),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.result.message.success"))
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "sms")
        XCTAssertTrue(openedURL.absoluteString.contains("0912-345-678"))
        XCTAssertFalse(openedURL.absoluteString.contains("I%20am%20running%20late"))
        XCTAssertFalse(openedURL.absoluteString.contains("body="))
    }

    func testSandboxActionExecutorOpensPhoneCallHandoffThroughInjectedOpenerWithoutCallingSilently() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openPhoneCallHandoff,
            title: "Open Phone Handoff",
            rationale: "User confirmed Kairo may open a visible Phone handoff.",
            payload: .phoneCall(PhoneCallDraft(phoneNumber: "+1 (555) 0100", label: "Alex", notes: "Follow up")),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.result.phone.success"))
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "tel")
        XCTAssertEqual(openedURL.absoluteString, "tel:+15550100")
    }

    func testSandboxActionExecutorOpensWebSearchHandoffThroughInjectedOpenerWithoutBrowsingSilently() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openWebSearchHandoff,
            title: "Open Web Search Handoff",
            rationale: "User confirmed Kairo may open a visible Safari search handoff.",
            payload: .webSearch(WebSearchDraft(query: "SwiftUI App Intents examples")),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.result.web.success"))
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host(), "duckduckgo.com")
        XCTAssertEqual(openedURL.absoluteString, "https://duckduckgo.com/?q=SwiftUI%20App%20Intents%20examples")
    }

    func testSandboxActionExecutorSchedulesNotificationThroughInjectedScheduler() async throws {
        let scheduler = MockNotificationScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), notificationScheduler: scheduler)
        let action = AgentAction(
            kind: .sendNotification,
            title: "Notify",
            rationale: "User asked for a local notification.",
            payload: .notification(NotificationDraft(title: "Kairo", body: "Time to review")),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.createdIdentifier, "notification-id")
        let scheduledTitles = await scheduler.scheduledDrafts.map(\.title)
        XCTAssertEqual(scheduledTitles, ["Kairo"])
    }

    func testSandboxActionExecutorCreatesReminderThroughInjectedScheduler() async throws {
        let scheduler = MockReminderScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), reminderScheduler: scheduler)
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User confirmed Kairo may write an EventKit reminder.",
            payload: .reminder(ReminderDraft(title: "Review Shortcut node outputs", notes: "From Kairo chat", dueDate: nil)),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.createdReminder"))
        XCTAssertEqual(result.createdIdentifier, "reminder-id")
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, ["Review Shortcut node outputs"])
    }

    func testSandboxActionExecutorReportsReminderPermissionDeniedWithSettingsRecovery() async throws {
        let scheduler = MockReminderScheduler(granted: false)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), reminderScheduler: scheduler)
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User confirmed Kairo may write an EventKit reminder.",
            payload: .reminder(ReminderDraft(title: "Permission denied QA", notes: nil, dueDate: nil)),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.permission.reminders.off"))
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, [])
    }

    func testSandboxActionExecutorRecordsAuditEventAfterConfirmedReminderCreation() async throws {
        let scheduler = MockReminderScheduler(granted: true)
        let auditLogger = InMemoryAuditLogger()
        let executor = SandboxActionExecutor(
            memoryStore: InMemoryMemoryStore(),
            reminderScheduler: scheduler,
            auditLogger: auditLogger
        )
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User confirmed Kairo may write an EventKit reminder.",
            payload: .reminder(ReminderDraft(
                title: "Follow up from shared text",
                notes: "Created from Share -> Chat task extraction.",
                dueDate: nil
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createReminderDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.reminders])
        XCTAssertEqual(auditEvents.first?.requiredConfirmation, true)
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .completed)
    }

    func testSandboxActionExecutorRecordsRejectedAuditEventForUnconfirmedWrite() async throws {
        let scheduler = MockReminderScheduler(granted: true)
        let auditLogger = InMemoryAuditLogger()
        let executor = SandboxActionExecutor(
            memoryStore: InMemoryMemoryStore(),
            reminderScheduler: scheduler,
            auditLogger: auditLogger
        )
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "Kairo must not write EventKit data until the user confirms.",
            payload: .reminder(ReminderDraft(title: "Needs confirmation", notes: nil, dueDate: nil)),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: false)
        let auditEvents = try await auditLogger.list(limit: 10)
        let createdDrafts = await scheduler.createdDrafts

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.confirmationRequired"))
        XCTAssertTrue(createdDrafts.isEmpty)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createReminderDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.reminders])
        XCTAssertEqual(auditEvents.first?.requiredConfirmation, true)
        XCTAssertEqual(auditEvents.first?.userConfirmed, false)
        XCTAssertEqual(auditEvents.first?.result, .rejected)
    }

    func testSandboxActionExecutorRecordsFailedAuditEventForPermissionDeniedWrite() async throws {
        let scheduler = MockCalendarScheduler(granted: false)
        let auditLogger = InMemoryAuditLogger()
        let executor = SandboxActionExecutor(
            memoryStore: InMemoryMemoryStore(),
            calendarScheduler: scheduler,
            auditLogger: auditLogger
        )
        let startDate = Date(timeIntervalSince1970: 1_780_358_400)
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User confirmed Kairo may write an EventKit calendar event.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Permission denied QA",
                notes: nil,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(1800)
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.permission.calendar.off"))
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createCalendarDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.calendar])
        XCTAssertEqual(auditEvents.first?.requiredConfirmation, true)
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .failed)
    }

    func testSandboxActionExecutorReportsCalendarWriteFailureWithFailedAuditEvent() async throws {
        let scheduler = MockCalendarScheduler(granted: true, createError: CalendarSchedulingError.unavailable)
        let auditLogger = InMemoryAuditLogger()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), calendarScheduler: scheduler, auditLogger: auditLogger)
        let action = makeCalendarAction(title: "EventKit write QA")

        let result = try await executor.execute(action, confirmed: true)
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.writeFailed.calendar"))
        XCTAssertEqual(auditEvents.first?.result, .failed)
    }

    func testKairoEnvironmentDefaultActionExecutorUsesInjectedAuditLogger() async throws {
        let auditLogger = InMemoryAuditLogger()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: MockAIProvider(),
            auditLogger: auditLogger
        )
        let action = AgentAction(
            kind: .answer,
            title: "Answer",
            rationale: "No external action required.",
            payload: .text("No-op answer"),
            riskTier: .tier0ReadOnly
        )

        let result = try await environment.actionExecutor.execute(action, confirmed: false)
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .answer)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.chat])
        XCTAssertEqual(auditEvents.first?.result, .completed)
    }

    func testKairoEnvironmentUITestingActionExecutorUsesEnvironmentAuditLogger() async throws {
        let environment = try await KairoEnvironment.uiTesting()
        let action = AgentAction(
            kind: .sendNotification,
            title: "Notify",
            rationale: "UI testing environment should record action audit metadata.",
            payload: .notification(NotificationDraft(title: "Kairo", body: "Audit metadata smoke")),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await environment.actionExecutor.execute(action, confirmed: true)
        let auditEvents = try await environment.auditLogger.list(limit: 10)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .sendNotification)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.notifications])
        XCTAssertEqual(auditEvents.first?.requiredConfirmation, true)
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .completed)
    }

    func testKairoLiveActionFactoryBuildsAuditedHandoffExecutor() async throws {
        let opener = MockURLOpener()
        let auditLogger = InMemoryAuditLogger()
        let executor = KairoLiveActionFactory(
            memoryStore: InMemoryMemoryStore(),
            auditLogger: auditLogger,
            urlOpener: opener,
            notificationScheduler: MockNotificationScheduler(granted: true)
        ).makeActionExecutor()
        let action = AgentAction(
            kind: .openURL,
            title: "Open website",
            rationale: "User confirmed Kairo may open a visible handoff URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)
        let openedURLs = await opener.openedURLs
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(openedURLs, [URL(string: "https://example.com")!])
        XCTAssertEqual(auditEvents.first?.actionKind, .openURL)
        XCTAssertEqual(auditEvents.first?.result, .completed)
    }

    func testSandboxActionExecutorCreatesCalendarEventThroughInjectedScheduler() async throws {
        let scheduler = MockCalendarScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), calendarScheduler: scheduler)
        let startDate = Date(timeIntervalSince1970: 1_780_358_400)
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User confirmed Kairo may write an EventKit calendar event.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Kairo roadmap review",
                notes: "From Kairo chat",
                startDate: startDate,
                endDate: startDate.addingTimeInterval(3600)
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.createdCalendar"))
        XCTAssertEqual(result.createdIdentifier, "calendar-event-id")
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, ["Kairo roadmap review"])
    }

    func testSandboxActionExecutorReportsCalendarPermissionDenied() async throws {
        let scheduler = MockCalendarScheduler(granted: false)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), calendarScheduler: scheduler)
        let startDate = Date(timeIntervalSince1970: 1_780_358_400)
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User confirmed Kairo may write an EventKit calendar event.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Kairo roadmap review",
                notes: nil,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(3600)
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.permission.calendar.off"))
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, [])
    }

    func testSandboxActionExecutorCreatesContactThroughInjectedScheduler() async throws {
        let scheduler = MockContactScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), contactScheduler: scheduler)
        let action = AgentAction(
            kind: .createContactDraft,
            title: "Create Contact",
            rationale: "User confirmed Kairo may write a Contacts.framework contact.",
            payload: .contact(ContactDraft(
                givenName: "Alex",
                familyName: "Chen",
                phoneNumbers: ["555-0100"],
                emailAddresses: ["alex@example.com"],
                notes: "From Kairo chat"
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.createdContact"))
        XCTAssertEqual(result.createdIdentifier, "contact-id")
        let createdNames = await scheduler.createdDrafts.map { "\($0.givenName) \($0.familyName)" }
        XCTAssertEqual(createdNames, ["Alex Chen"])
    }

    func testSandboxActionExecutorReportsContactPermissionDenied() async throws {
        let scheduler = MockContactScheduler(granted: false)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), contactScheduler: scheduler)
        let action = AgentAction(
            kind: .createContactDraft,
            title: "Create Contact",
            rationale: "User confirmed Kairo may write a Contacts.framework contact.",
            payload: .contact(ContactDraft(
                givenName: "Alex",
                familyName: "Chen",
                phoneNumbers: ["555-0100"],
                emailAddresses: [],
                notes: nil
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.permission.contactsDenied"))
        let createdNames = await scheduler.createdDrafts.map(\.givenName)
        XCTAssertEqual(createdNames, [])
    }
}

private func makeCalendarAction(title: String) -> AgentAction {
    let startDate = Date(timeIntervalSince1970: 1_780_358_400)
    let draft = CalendarEventDraft(title: title, notes: nil, startDate: startDate, endDate: startDate.addingTimeInterval(1800))
    return AgentAction(kind: .createCalendarDraft, title: "Create Calendar Event", rationale: "User confirmed Kairo may write an EventKit calendar event.", payload: .calendarEvent(draft), riskTier: .tier2LowRiskWrite)
}

private actor MockURLOpener: URLOpener {
    private(set) var openedURLs: [URL] = []
    private let result: Bool

    init(result: Bool = true) { self.result = result }

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return result
    }
}

private actor MockNotificationScheduler: NotificationScheduling {
    private(set) var scheduledDrafts: [NotificationDraft] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAuthorization() async throws -> Bool { granted }

    func schedule(_ draft: NotificationDraft) async throws -> String {
        scheduledDrafts.append(draft)
        return "notification-id"
    }
}

private actor MockReminderScheduler: ReminderScheduling {
    private(set) var createdDrafts: [ReminderDraft] = []
    private let granted: Bool

    init(granted: Bool) { self.granted = granted }

    func requestAccess() async throws -> Bool { granted }

    func createReminder(from draft: ReminderDraft) async throws -> String {
        createdDrafts.append(draft)
        return "reminder-id"
    }
}

private actor MockCalendarScheduler: CalendarScheduling {
    private(set) var createdDrafts: [CalendarEventDraft] = []
    private let granted: Bool
    private let createError: Error?

    init(granted: Bool, createError: Error? = nil) {
        self.granted = granted
        self.createError = createError
    }

    func requestAccess() async throws -> Bool { granted }

    func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        if let createError { throw createError }
        createdDrafts.append(draft)
        return "calendar-event-id"
    }
}

private actor MockContactScheduler: ContactScheduling {
    private(set) var createdDrafts: [ContactDraft] = []
    private let granted: Bool

    init(granted: Bool) { self.granted = granted }

    func requestAccess() async throws -> Bool { granted }

    func createContact(from draft: ContactDraft) async throws -> String {
        createdDrafts.append(draft)
        return "contact-id"
    }
}
