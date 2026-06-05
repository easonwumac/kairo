import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatHandoffFailureStateTests: XCTestCase {
    @MainActor
    func testFailedMessageHandoffClearsReviewStateAndDoesNotClaimSent() async throws {
        let auditLogger = InMemoryAuditLogger()
        let urlOpener = FailingHandoffURLOpener()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: KairoChatBackendService(agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())),
            actionExecutor: SandboxActionExecutor(
                memoryStore: InMemoryMemoryStore(),
                urlOpener: urlOpener,
                auditLogger: auditLogger
            )
        )

        await viewModel.send("Text 0912-345-678 body I am running late.")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .openMessageHandoff })
        XCTAssertEqual(viewModel.handoffReviewAction?.id, action.id)

        viewModel.reviewHandoffAction()
        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.handoffReviewAction)
        XCTAssertEqual(viewModel.actionResultMessage,
            KairoL10n.string("chat.action.result.message.failure")
        )
        XCTAssertEqual(viewModel.actionResultSucceeded, false)
        XCTAssertNil(viewModel.errorMessage)
        let openedURLCount = await urlOpener.openedURLCount()
        XCTAssertEqual(openedURLCount, 1)
        let auditEvents = try await auditLogger.list(limit: 10)
        XCTAssertEqual(auditEvents.first?.actionKind, .openMessageHandoff)
        XCTAssertEqual(auditEvents.first?.result, .failed)
    }
}

private actor FailingHandoffURLOpener: URLOpener {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return false
    }

    func openedURLCount() -> Int {
        openedURLs.count
    }
}
#endif
