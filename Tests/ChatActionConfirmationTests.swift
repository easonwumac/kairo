import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ChatActionConfirmationTests: XCTestCase {
    @MainActor
    func testChatViewModelConfirmsNotificationActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "通知我喝水",
            expectedKind: .sendNotification,
            expectedMessage: KairoL10n.string("chat.action.result.notification.success")
        )
    }

    @MainActor
    func testChatViewModelConfirmsReminderActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "建立提醒事項：下班前整理 Kairo model list",
            expectedKind: .createReminderDraft,
            expectedMessage: KairoL10n.string("chat.action.result.reminder.success", "", "")
        )
    }

    @MainActor
    func testChatViewModelConfirmsCalendarActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "建立行程：週五 10:00 Kairo roadmap review",
            expectedKind: .createCalendarDraft,
            expectedMessage: KairoL10n.string("chat.action.result.calendar.success", "", "")
        )
    }

    @MainActor
    func testChatViewModelSurfacesDeniedCalendarPermissionAsFailedActionResult() async throws {
        try await assertDeniedAction(
            prompt: "建立行程：週五 10:00 Kairo roadmap review",
            expectedKind: .createCalendarDraft,
            executorMessage: KairoL10n.string("chat.action.permission.calendar.off"),
            expectedResultMessage: KairoL10n.string(
                "chat.action.result.calendar.failure",
                KairoL10n.string("chat.action.permission.calendar.off")
            )
        )
    }

    @MainActor
    func testChatViewModelSurfacesDeniedReminderPermissionAsFailedActionResult() async throws {
        try await assertDeniedAction(
            prompt: "建立提醒事項：下班前整理 Kairo model list",
            expectedKind: .createReminderDraft,
            executorMessage: KairoL10n.string("chat.action.permission.reminders.off"),
            expectedResultMessage: KairoL10n.string(
                "chat.action.result.reminder.failure",
                KairoL10n.string("chat.action.permission.reminders.off")
            )
        )
    }

    @MainActor
    func testChatViewModelConfirmsContactActionThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "建立聯絡人：王小明 0912-345-678 ming@example.com",
            expectedKind: .createContactDraft,
            expectedMessage: KairoL10n.string("chat.action.result.contact.success")
        )
    }

    @MainActor
    func testChatViewModelConfirmsEmailDraftHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.",
            expectedKind: .composeEmailDraft,
            expectedMessage: KairoL10n.string("chat.action.result.email.success")
        )
    }

    @MainActor
    func testChatViewModelConfirmsMapDirectionsHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Drive to Apple Park",
            expectedKind: .openMapDirections,
            expectedMessage: KairoL10n.string("chat.action.result.maps.success")
        )
    }

    @MainActor
    func testChatViewModelConfirmsMessageHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Text 0912-345-678 body I am running late.",
            expectedKind: AgentActionKind(rawValue: "openMessageHandoff")!,
            expectedMessage: KairoL10n.string("chat.action.result.message.success")
        )
    }

    @MainActor
    func testChatViewModelConfirmsPhoneCallHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Call 0912-345-678",
            expectedKind: .openPhoneCallHandoff,
            expectedMessage: KairoL10n.string("chat.action.result.phone.success")
        )
    }

    @MainActor
    func testChatViewModelConfirmsWebSearchHandoffThroughInjectedExecutor() async throws {
        try await assertConfirmedAction(
            prompt: "Search web for SwiftUI App Intents examples",
            expectedKind: .openWebSearchHandoff,
            expectedMessage: KairoL10n.string("chat.action.result.web.success")
        )
    }

    @MainActor
    func testChatViewModelClearsStaleActionReviewWhenSelectingAnotherThread() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: ChatActionConfirmationMockExecutor()
        )

        await viewModel.send("建立行程：週五 10:00 Kairo roadmap review")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })
        XCTAssertEqual(viewModel.calendarReviewAction?.id, action.id)

        viewModel.selectThread(ChatThread(messages: [
            ChatMessage(role: .user, text: "Different thread")
        ]))

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertNil(viewModel.calendarReviewAction)
        XCTAssertNil(viewModel.handoffReviewAction)
        XCTAssertNil(viewModel.actionResultMessage)
    }

    @MainActor
    func testChatViewModelCancelRestoresCalendarReviewWithoutExecutingAction() async throws {
        let executor = ChatActionConfirmationMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("建立行程：週五 10:00 Kairo roadmap review")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })
        XCTAssertEqual(viewModel.calendarReviewAction?.id, action.id)

        viewModel.reviewCalendarAction()
        XCTAssertEqual(viewModel.pendingAction?.id, action.id)
        XCTAssertNil(viewModel.calendarReviewAction)

        viewModel.cancelPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.calendarReviewAction?.id, action.id)
        XCTAssertNil(viewModel.actionResultMessage)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertTrue(executedActions.isEmpty)
        XCTAssertTrue(confirmations.isEmpty)
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

    @MainActor
    private func assertDeniedAction(
        prompt: String,
        expectedKind: AgentActionKind,
        executorMessage: String,
        expectedResultMessage: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: DeniedActionExecutor(message: executorMessage)
        )
        await viewModel.send(prompt)
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last, file: file, line: line)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == expectedKind }, file: file, line: line)
        viewModel.previewAction(action)
        await viewModel.confirmPendingAction()
        XCTAssertNil(viewModel.pendingAction, file: file, line: line)
        XCTAssertEqual(viewModel.actionResultMessage, expectedResultMessage, file: file, line: line)
        XCTAssertEqual(viewModel.actionResultSucceeded, false, file: file, line: line)
        XCTAssertNil(viewModel.errorMessage, file: file, line: line)
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
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.executor.createdContact"), createdIdentifier: "contact-id")
        case "composeEmailDraft":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.result.email.success"), requiresExternalUI: true)
        case "openMapDirections":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.result.maps.success"), requiresExternalUI: true)
        case "openMessageHandoff":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.result.message.success"), requiresExternalUI: true)
        case "openPhoneCallHandoff":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.result.phone.success"), requiresExternalUI: true)
        case "openWebSearchHandoff":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.result.web.success"), requiresExternalUI: true)
        case "createCalendarDraft":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.executor.createdCalendar"), createdIdentifier: "calendar-event-id")
        case "createReminderDraft":
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.executor.createdReminder"), createdIdentifier: "reminder-id")
        default:
            return ActionExecutionResult(completed: true, message: KairoL10n.string("chat.action.executor.scheduledNotification"), createdIdentifier: "notification-id")
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
