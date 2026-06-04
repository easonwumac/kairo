import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatPrivacyModeActionStateTests: XCTestCase {
    @MainActor
    func testPrivateChatClearsPendingActionReviewState() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
        )

        await viewModel.send("建立行程：週五 10:00 Kairo roadmap review")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })
        XCTAssertEqual(viewModel.calendarReviewAction?.id, action.id)

        viewModel.reviewCalendarAction()
        XCTAssertEqual(viewModel.pendingAction?.id, action.id)

        viewModel.setPrivateChatEnabled(true)

        XCTAssertTrue(viewModel.isPrivateChatEnabled)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.calendarReviewAction)
        XCTAssertNil(viewModel.handoffReviewAction)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertNil(viewModel.actionResultMessage)
    }
}
#endif
