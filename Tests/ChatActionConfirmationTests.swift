import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatActionConfirmationTests: XCTestCase {
    @MainActor
    func testChatViewModelConfirmsNotificationActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "通知我喝水",
            expectedKind: .sendNotification,
            expectedMessage: "Scheduled notification."
        )
    }

    @MainActor
    func testChatViewModelConfirmsReminderActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "建立提醒事項：下班前整理 Kairo model list",
            expectedKind: .createReminderDraft,
            expectedMessage: "Created reminder."
        )
    }

    @MainActor
    func testChatViewModelConfirmsCalendarActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "建立行程：週五 10:00 Kairo roadmap review",
            expectedKind: .createCalendarDraft,
            expectedMessage: "Created calendar event."
        )
    }

    @MainActor
    func testChatViewModelSurfacesDeniedCalendarPermissionAsFailedActionResult() async throws {
        let deniedMessage = "Calendar permission was not granted."
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: DeniedActionExecutor(message: deniedMessage)
        )

        await viewModel.send("建立行程：週五 10:00 Kairo roadmap review")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })

        viewModel.previewAction(action)
        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.actionResultMessage, deniedMessage)
        XCTAssertEqual(viewModel.actionResultSucceeded, false)
        XCTAssertEqual(viewModel.errorMessage, deniedMessage)
    }

    @MainActor
    func testChatViewModelConfirmsContactActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "建立聯絡人：王小明 0912-345-678 ming@example.com",
            expectedKind: .createContactDraft,
            expectedMessage: "Created contact."
        )
    }

    @MainActor
    func testChatViewModelConfirmsEmailDraftHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.",
            expectedKind: .composeEmailDraft,
            expectedMessage: "Prepared email draft handoff."
        )
    }

    @MainActor
    func testChatViewModelConfirmsMapDirectionsHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Drive to Apple Park",
            expectedKind: .openMapDirections,
            expectedMessage: "Prepared Apple Maps directions handoff."
        )
    }

    @MainActor
    func testChatViewModelConfirmsMessageHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Text 0912-345-678 body I am running late.",
            expectedKind: AgentActionKind(rawValue: "openMessageHandoff")!,
            expectedMessage: "Prepared Messages handoff."
        )
    }

    @MainActor
    func testChatViewModelConfirmsPhoneCallHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Call 0912-345-678",
            expectedKind: .openPhoneCallHandoff,
            expectedMessage: "Prepared phone call handoff."
        )
    }

    @MainActor
    func testChatViewModelConfirmsWebSearchHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Search web for SwiftUI App Intents examples",
            expectedKind: .openWebSearchHandoff,
            expectedMessage: "Prepared Safari web search handoff."
        )
    }

    @MainActor
    private func assertConfirmedAction(
        prompt: String,
        expectedKind: AgentActionKind,
        expectedMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let executor = ChatActionConfirmationMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send(prompt)
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last, file: file, line: line)
        let action = try XCTUnwrap(
            assistantMessage.proposedActions.first { $0.kind == expectedKind },
            file: file,
            line: line
        )

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, expectedKind, file: file, line: line)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction, file: file, line: line)
        XCTAssertTrue(viewModel.actionResultMessage?.contains(expectedMessage) == true, file: file, line: line)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [expectedKind], file: file, line: line)
        XCTAssertEqual(confirmations, [true], file: file, line: line)
    }
}

private actor ChatActionConfirmationMockExecutor: ActionExecutor {
    private(set) var executedActions: [AgentAction] = []
    private(set) var confirmations: [Bool] = []

    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult {
        executedActions.append(action)
        confirmations.append(confirmed)
        switch action.kind.rawValue {
        case "createContactDraft":
            return ActionExecutionResult(completed: true, message: "Created contact.", createdIdentifier: "contact-id")
        case "composeEmailDraft":
            return ActionExecutionResult(completed: true, message: "Prepared email draft handoff.", requiresExternalUI: true)
        case "openMapDirections":
            return ActionExecutionResult(completed: true, message: "Prepared Apple Maps directions handoff.", requiresExternalUI: true)
        case "openMessageHandoff":
            return ActionExecutionResult(completed: true, message: "Prepared Messages handoff.", requiresExternalUI: true)
        case "openPhoneCallHandoff":
            return ActionExecutionResult(completed: true, message: "Prepared phone call handoff.", requiresExternalUI: true)
        case "openWebSearchHandoff":
            return ActionExecutionResult(completed: true, message: "Prepared Safari web search handoff.", requiresExternalUI: true)
        case "createCalendarDraft":
            return ActionExecutionResult(completed: true, message: "Created calendar event.", createdIdentifier: "calendar-event-id")
        case "createReminderDraft":
            return ActionExecutionResult(completed: true, message: "Created reminder.", createdIdentifier: "reminder-id")
        default:
            return ActionExecutionResult(completed: true, message: "Scheduled notification.", createdIdentifier: "notification-id")
        }
    }
}

private struct DeniedActionExecutor: ActionExecutor {
    let message: String

    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult {
        ActionExecutionResult(completed: false, message: message)
    }
}
#endif
