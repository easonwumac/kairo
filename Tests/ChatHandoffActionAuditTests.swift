import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatHandoffActionAuditTests: XCTestCase {
    @MainActor
    func testChatConfirmedEmailMessagePhoneWebAndMapsHandoffsOpenVisibleURLsAndRecordAudit() async throws {
        try await assertConfirmedHandoff(
            prompt: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.",
            expectedKind: .composeEmailDraft,
            expectedCapability: .mail,
            expectedURLScheme: "mailto",
            expectedResult: "Opened visible Mail draft handoff. No email has been sent."
        )
        try await assertConfirmedHandoff(
            prompt: "Text 0912-345-678 body I am running late.",
            expectedKind: AgentActionKind(rawValue: "openMessageHandoff")!,
            expectedCapability: .messages,
            expectedURLScheme: "sms",
            expectedResult: "Opened visible Messages recipient handoff. No message has been sent; body remains in Kairo preview."
        )
        try await assertConfirmedHandoff(
            prompt: "Call 0912-345-678",
            expectedKind: .openPhoneCallHandoff,
            expectedCapability: .phone,
            expectedURLScheme: "tel",
            expectedResult: "Opened visible Phone handoff. No call has been placed; calling still requires user action in Phone."
        )
        try await assertConfirmedHandoff(
            prompt: "Search web for SwiftUI App Intents examples",
            expectedKind: .openWebSearchHandoff,
            expectedCapability: .web,
            expectedURLScheme: "https",
            expectedResult: "Opened visible Safari web search handoff. No browsing has happened inside Kairo."
        )
        try await assertConfirmedHandoff(
            prompt: "Drive to Apple Park",
            expectedKind: .openMapDirections,
            expectedCapability: .location,
            expectedURLScheme: "https",
            expectedResult: "Opened visible Apple Maps handoff. Navigation still requires user action in Maps."
        )
    }

    @MainActor
    private func assertConfirmedHandoff(
        prompt: String,
        expectedKind: AgentActionKind,
        expectedCapability: CapabilityKey,
        expectedURLScheme: String,
        expectedResult: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let auditLogger = InMemoryAuditLogger()
        let urlOpener = CapturingHandoffURLOpener()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: SandboxActionExecutor(
                memoryStore: InMemoryMemoryStore(),
                urlOpener: urlOpener,
                auditLogger: auditLogger
            )
        )

        await viewModel.send(prompt)
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last, file: file, line: line)
        let action = try XCTUnwrap(
            assistantMessage.proposedActions.first { $0.kind == expectedKind },
            file: file,
            line: line
        )
        XCTAssertNil(viewModel.pendingAction, file: file, line: line)
        XCTAssertEqual(viewModel.handoffReviewAction?.id, action.id, file: file, line: line)

        viewModel.reviewHandoffAction()
        XCTAssertEqual(viewModel.pendingAction?.id, action.id, file: file, line: line)
        XCTAssertNil(viewModel.handoffReviewAction, file: file, line: line)
        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction, file: file, line: line)
        XCTAssertEqual(viewModel.actionResultMessage, expectedResult, file: file, line: line)
        let openedURLs = await urlOpener.openedURLs
        XCTAssertEqual(openedURLs.count, 1, file: file, line: line)
        XCTAssertEqual(openedURLs.first?.scheme, expectedURLScheme, file: file, line: line)
        let auditEvents = try await auditLogger.list(limit: 10)
        XCTAssertEqual(auditEvents.count, 1, file: file, line: line)
        XCTAssertEqual(auditEvents.first?.actionKind, expectedKind, file: file, line: line)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [expectedCapability], file: file, line: line)
        XCTAssertEqual(auditEvents.first?.requiredConfirmation, true, file: file, line: line)
        XCTAssertEqual(auditEvents.first?.userConfirmed, true, file: file, line: line)
        XCTAssertEqual(auditEvents.first?.result, .completed, file: file, line: line)
    }
}

private actor CapturingHandoffURLOpener: URLOpener {
    private(set) var openedURLs: [URL] = []

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return true
    }
}
#endif
