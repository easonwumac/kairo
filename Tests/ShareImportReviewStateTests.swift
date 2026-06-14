import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ShareImportReviewStateTests: XCTestCase {
    @MainActor
    func testShareReminderReviewClearsWhenUserSendsAnotherChatMessage() async throws {
        let viewModel = makeShareImportViewModel()

        await viewModel.importPendingShares()
        await viewModel.sendImportedShareToChat()
        XCTAssertNotNil(viewModel.shareImportReviewAction)

        await viewModel.send("Summarize today's launch plan")

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertNil(viewModel.actionResultMessage)
    }

    @MainActor
    func testShareImportStateClearsWhenUserSwitchesThread() async throws {
        let viewModel = makeShareImportViewModel()

        await viewModel.importPendingShares()
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        XCTAssertNotNil(viewModel.shareImportNotice)
        XCTAssertNotNil(viewModel.shareImportPreview)

        let otherThread = ChatThread(messages: [
            ChatMessage(role: .user, text: "Different conversation")
        ])
        viewModel.selectThread(otherThread)

        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertNil(viewModel.shareImportPreview)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertFalse(viewModel.canSendImportedShareToChat)
    }

    @MainActor
    func testImportedShareSuggestedActionCanBeReviewedAndConfirmedWithoutChatSend() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("記住：AFM 適合短上下文分類。", displayName: "Memory")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let executor = ShareImportReviewMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: queue,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.importPendingShares()

        XCTAssertEqual(viewModel.briefingSnapshot.pendingCaptureCount, 1)
        XCTAssertEqual(viewModel.briefingSnapshot.memoryDraftCount, 1)
        XCTAssertEqual(viewModel.briefingSnapshot.confirmationCount, 1)
        XCTAssertEqual(viewModel.shareImportReviewAction?.kind, .saveMemory)
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        viewModel.reviewImportedShareAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .saveMemory)
        XCTAssertNil(viewModel.shareImportReviewAction)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
        XCTAssertEqual(viewModel.briefingSnapshot, .empty)
        let pendingItems = try await queue.pendingItems(limit: 10)
        let executedKinds = await executor.executedKinds()
        let confirmations = await executor.confirmations()
        XCTAssertEqual(pendingItems, [])
        XCTAssertEqual(executedKinds, [.saveMemory])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testCaptureBriefingReviewImportsShareAndOpensPreview() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("TODO: Send AFM test notes", displayName: "Task")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [sharedItem]),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            )
        )

        await viewModel.refreshBriefingSnapshot()
        XCTAssertEqual(viewModel.briefingSnapshot.pendingCaptureCount, 1)
        XCTAssertEqual(viewModel.briefingSnapshot.confirmationCount, 1)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportReviewAction)

        await viewModel.reviewCaptureBriefing()

        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        XCTAssertNotNil(viewModel.shareImportNotice)
    }

    @MainActor
    func testCaptureBriefingReviewAdvancesThroughQueuedActionsBeforeClearingShare() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("週五前整理 Kairo demo，補 Google Maps 和 Todoist 測試。", displayName: "Tasks")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let executor = ShareImportReviewMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: queue,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.reviewCaptureBriefing()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)

        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        let pendingAfterFirstConfirmation = try await queue.pendingItems(limit: 10)
        XCTAssertFalse(pendingAfterFirstConfirmation.isEmpty)

        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        let pendingAfterSecondConfirmation = try await queue.pendingItems(limit: 10)
        XCTAssertFalse(pendingAfterSecondConfirmation.isEmpty)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportNotice)
        let pendingAfterFinalConfirmation = try await queue.pendingItems(limit: 10)
        XCTAssertEqual(pendingAfterFinalConfirmation, [])
        let executedKinds = await executor.executedKinds()
        XCTAssertEqual(executedKinds, [.createReminderDraft, .createReminderDraft, .createReminderDraft])
    }

    @MainActor
    func testCaptureBriefingCancelSkipsCurrentQueuedActionWithoutExecuting() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("週五前整理 Kairo demo，補 Google Maps 和 Todoist 測試。", displayName: "Tasks")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let executor = ShareImportReviewMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [sharedItem]),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.reviewCaptureBriefing()
        let firstActionID = viewModel.pendingAction?.id

        viewModel.cancelPendingAction()

        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        XCTAssertNotEqual(viewModel.pendingAction?.id, firstActionID)
        let executedKinds = await executor.executedKinds()
        XCTAssertTrue(executedKinds.isEmpty)
    }

    @MainActor
    private func makeShareImportViewModel() -> ChatViewModel {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("TODO: Send prototype link", displayName: "Launch Notes")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        return ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [sharedItem]),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            )
        )
    }
}

private actor ShareImportReviewMockExecutor: ActionExecutor {
    private var actions: [AgentAction] = []
    private var confirmedValues: [Bool] = []

    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult {
        actions.append(action)
        confirmedValues.append(confirmed)
        return ActionExecutionResult(completed: true, message: "ok")
    }

    func executedKinds() -> [AgentActionKind] {
        actions.map(\.kind)
    }

    func confirmations() -> [Bool] {
        confirmedValues
    }
}
#endif
