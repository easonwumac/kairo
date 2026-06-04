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
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
        )
    }
}
#endif
