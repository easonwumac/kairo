import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatCalendarActionAuditTests: XCTestCase {
    @MainActor
    func testChatCalendarConfirmationRecordsAuditEvent() async throws {
        let auditLogger = InMemoryAuditLogger()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: SandboxActionExecutor(
                memoryStore: InMemoryMemoryStore(),
                calendarScheduler: AllowingCalendarScheduler(identifier: "chat-calendar-event-id"),
                auditLogger: auditLogger
            )
        )

        await viewModel.send("建立行程：週五 10:00 Kairo roadmap review")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })
        guard case let .calendarEvent(draft) = action.payload else {
            return XCTFail("Expected calendar event payload.")
        }
        XCTAssertEqual(draft.title, "週五 10:00 Kairo roadmap review")

        viewModel.previewAction(action)
        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.actionResultMessage, "Created calendar event.")
        let auditEvents = try await auditLogger.list(limit: 10)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createCalendarDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.calendar])
        XCTAssertEqual(auditEvents.first?.requiredConfirmation, true)
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .completed)
    }
}
#endif
