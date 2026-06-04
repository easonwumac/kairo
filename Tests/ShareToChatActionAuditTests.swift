import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ShareToChatActionAuditTests: XCTestCase {
    @MainActor
    func testShareTextToChatReminderConfirmationRecordsAuditEvent() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [
                builder.text("""
                TODO: Send prototype link
                Reminder: Book beta review meeting
                """, displayName: "Launch Notes")
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let shareQueue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let auditLogger = InMemoryAuditLogger()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: shareQueue,
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: SandboxActionExecutor(
                memoryStore: InMemoryMemoryStore(),
                reminderScheduler: AllowingReminderScheduler(identifier: "shared-text-reminder-id"),
                auditLogger: auditLogger
            )
        )

        await viewModel.importPendingShares()
        XCTAssertEqual(viewModel.composerText, "建立提醒事項：Send prototype link")
        XCTAssertEqual(viewModel.pendingAttachments.map(\.displayName), ["Launch Notes"])
        XCTAssertEqual(viewModel.shareImportNotice, "已匯入 1 個分享項目，可送進 Chat 摘要或抽任務。")
        XCTAssertEqual(
            viewModel.shareImportPreview,
            "Launch Notes: TODO: Send prototype link Reminder: Book beta review meeting"
        )
        XCTAssertTrue(viewModel.canSendImportedShareToChat)
        XCTAssertEqual(viewModel.shareImportPrimaryActionTitle, "Extract Tasks")

        await viewModel.sendImportedShareToChat()
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertNil(viewModel.shareImportPreview)
        XCTAssertFalse(viewModel.canSendImportedShareToChat)
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createReminderDraft })
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.shareImportReviewAction?.id, action.id)
        guard case let .reminder(draft) = action.payload else {
            return XCTFail("Expected reminder payload.")
        }
        XCTAssertEqual(draft.title, "Send prototype link")

        viewModel.reviewImportedShareAction()
        XCTAssertEqual(viewModel.pendingAction?.id, action.id)
        XCTAssertNil(viewModel.shareImportReviewAction)
        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.actionResultMessage, "Created reminder. Send prototype link")
        let auditEvents = try await auditLogger.list(limit: 10)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createReminderDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.reminders])
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .completed)
        let remainingShares = try await shareQueue.pendingItems(limit: 10)
        XCTAssertTrue(remainingShares.isEmpty)
    }
}
#endif
