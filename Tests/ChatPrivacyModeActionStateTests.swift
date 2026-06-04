import XCTest
import Foundation
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

    func testPrivateChatSuppressesProviderProposedActions() async throws {
        let providerAction = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "Provider suggested a calendar write.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Private planning",
                notes: nil,
                startDate: Date(timeIntervalSince1970: 10),
                endDate: Date(timeIntervalSince1970: 70)
            )),
            riskTier: .tier2LowRiskWrite
        )
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(
            message: "Private response",
            proposedActions: [providerAction]
        ))
        let api = KairoChatBackendService(agent: AgentCore(aiProvider: provider))

        let response = try await api.respond(to: "建立私人行程", attachments: [], privacyMode: .privateChat)

        XCTAssertEqual(response.message, "Private response")
        XCTAssertTrue(response.proposedActions.isEmpty)
        XCTAssertTrue(response.toolCandidates.isEmpty)
    }
}
#endif
