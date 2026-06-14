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

        XCTAssertEqual(viewModel.shareImportReviewAction?.kind, .saveMemory)
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        viewModel.reviewImportedShareAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .saveMemory)
        XCTAssertNil(viewModel.shareImportReviewAction)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
        let pendingItems = try await queue.pendingItems(limit: 10)
        let executedKinds = await executor.executedKinds()
        let confirmations = await executor.confirmations()
        XCTAssertEqual(pendingItems, [])
        XCTAssertEqual(executedKinds, [.saveMemory])
        XCTAssertEqual(confirmations, [true])
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
