import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatHandoffReviewStateTests: XCTestCase {
    @MainActor
    func testHandoffReviewStateClearsWhenStartingNewThread() async throws {
        let viewModel = makeHandoffViewModel()

        try await prepareHandoffReview(in: viewModel)
        viewModel.startNewThread()

        assertNoTransientHandoffState(in: viewModel)
    }

    @MainActor
    func testHandoffReviewStateClearsWhenSelectingAnotherThread() async throws {
        let viewModel = makeHandoffViewModel()

        try await prepareHandoffReview(in: viewModel)
        viewModel.selectThread(ChatThread(messages: [
            ChatMessage(role: .user, text: "Different thread")
        ]))

        assertNoTransientHandoffState(in: viewModel)
    }

    @MainActor
    func testHandoffReviewStateClearsWhenDeletingCurrentThread() async throws {
        let viewModel = makeHandoffViewModel()

        try await prepareHandoffReview(in: viewModel)
        let thread = viewModel.currentThread
        await viewModel.deleteThread(thread)

        assertNoTransientHandoffState(in: viewModel)
    }

    @MainActor
    private func prepareHandoffReview(in viewModel: ChatViewModel) async throws {
        await viewModel.send("Text 0912-345-678 body I am running late.")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .openMessageHandoff })
        XCTAssertEqual(viewModel.handoffReviewAction?.id, action.id)
    }

    @MainActor
    private func assertNoTransientHandoffState(in viewModel: ChatViewModel) {
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.handoffReviewAction)
        XCTAssertNil(viewModel.actionResultMessage)
    }

    @MainActor
    private func makeHandoffViewModel() -> ChatViewModel {
        ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: KairoChatBackendService(agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()))
        )
    }
}
#endif
