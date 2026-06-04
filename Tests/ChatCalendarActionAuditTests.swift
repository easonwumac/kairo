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

        await viewModel.send("幫我安排週五 10:00 Kairo roadmap review 會議")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.calendarReviewAction?.id, action.id)
        guard case let .calendarEvent(draft) = action.payload else {
            return XCTFail("Expected calendar event payload.")
        }
        XCTAssertEqual(draft.title, "Kairo roadmap review")

        viewModel.reviewCalendarAction()
        XCTAssertEqual(viewModel.pendingAction?.id, action.id)
        XCTAssertNil(viewModel.calendarReviewAction)
        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.actionResultMessage, "Created calendar event. Kairo roadmap review")
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
