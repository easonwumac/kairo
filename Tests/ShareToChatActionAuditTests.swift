import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ShareToChatActionAuditTests: XCTestCase {
    @MainActor
    func testShareTextToChatReminderConfirmationRecordsAuditEvent() async throws {
        let flow = makeShareReminderFlow(reminderScheduler: AllowingReminderScheduler(identifier: "shared-text-reminder-id"))

        await flow.viewModel.importPendingShares()
        XCTAssertEqual(flow.viewModel.composerText, KairoL10n.string("chat.share.prompt.extractReminder", "Send prototype link"))
        XCTAssertEqual(flow.viewModel.pendingAttachments.map(\.displayName), ["Launch Notes"])
        XCTAssertEqual(flow.viewModel.shareImportPreview,
            "Launch Notes: TODO: Send prototype link Reminder: Book beta review meeting"
        )

        await flow.viewModel.sendImportedShareToChat()
        XCTAssertNil(flow.viewModel.shareImportNotice)
        XCTAssertNil(flow.viewModel.shareImportPreview)
        XCTAssertFalse(flow.viewModel.canSendImportedShareToChat)
        let assistantMessage = try XCTUnwrap(flow.viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createReminderDraft })
        guard case let .reminder(draft) = action.payload else {
            return XCTFail("Expected reminder payload.")
        }
        XCTAssertEqual(draft.title, "Send prototype link")

        flow.viewModel.reviewImportedShareAction()
        XCTAssertEqual(flow.viewModel.pendingAction?.id, action.id)
        await flow.viewModel.confirmPendingAction()

        XCTAssertNil(flow.viewModel.pendingAction)
        let successMessage = KairoL10n.string(
            "chat.action.result.reminder.success",
            "Send prototype link",
            KairoL10n.string("chat.action.result.shareClearedSuffix")
        )
        XCTAssertEqual(flow.viewModel.actionResultMessage, successMessage)
        let auditEvents = try await flow.auditLogger.list(limit: 10)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createReminderDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.reminders])
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .completed)
        let remainingShares = try await flow.shareQueue.pendingItems(limit: 10)
        XCTAssertTrue(remainingShares.isEmpty)
    }

    @MainActor
    func testShareTextReminderPermissionFailureSaysReminderWasNotCreated() async throws {
        let flow = makeShareReminderFlow(reminderScheduler: UnavailableReminderScheduler())

        await flow.viewModel.importPendingShares()
        await flow.viewModel.sendImportedShareToChat()
        flow.viewModel.reviewImportedShareAction()
        await flow.viewModel.confirmPendingAction()

        XCTAssertNil(flow.viewModel.pendingAction)
        let failureMessage = KairoL10n.string(
            "chat.action.result.reminder.failure",
            KairoL10n.string("chat.action.permission.reminders.off")
        )
        XCTAssertEqual(flow.viewModel.actionResultMessage, failureMessage)
        XCTAssertEqual(flow.viewModel.actionResultSucceeded, false)
        XCTAssertNil(flow.viewModel.errorMessage)
        let auditEvents = try await flow.auditLogger.list(limit: 10)
        let remainingShares = try await flow.shareQueue.pendingItems(limit: 10)
        XCTAssertEqual(auditEvents.first?.result, .failed)
        XCTAssertTrue(remainingShares.isEmpty)
    }

    @MainActor
    private func makeShareReminderFlow(reminderScheduler: any ReminderScheduling) -> (
        viewModel: ChatViewModel,
        shareQueue: InMemoryShareIngestionQueue,
        auditLogger: InMemoryAuditLogger
    ) {
        let builder = ShareAttachmentBuilder()
        let text = """
        TODO: Send prototype link
        Reminder: Book beta review meeting
        """
        let sharedItem = ShareIngestionItem(attachments: [builder.text(text, displayName: "Launch Notes")], sourceApplication: "ShareSheet", receivedAt: Date(timeIntervalSince1970: 10))
        let shareQueue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let auditLogger = InMemoryAuditLogger()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: shareQueue,
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), reminderScheduler: reminderScheduler, auditLogger: auditLogger)
        )
        return (viewModel, shareQueue, auditLogger)
    }
}
#endif
