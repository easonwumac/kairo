import XCTest
@testable import KairoCore

final class AgentCoreActionPreviewTests: XCTestCase {
    func testAgentCoreAddsDeterministicHomeKitPreviewAction() async throws {
        let response = try await makeAgent().respond(to: "Turn on the desk lamp")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .controlHome })
        XCTAssertEqual(action.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(action.requiresConfirmation)
    }

    func testAgentCoreReturnsShortcutToolCandidateWithoutActionExecution() async throws {
        let response = try await makeAgent().respond(to: "Turn this shared text into todo tasks")

        let candidate = try XCTUnwrap(response.toolCandidates.first { $0.skillID == "shortcut-save-shared-text" })
        XCTAssertEqual(candidate.skillKind, .shortcutWorkflow)
        XCTAssertEqual(candidate.shortcutRecipeID, "save-shared-text")
        XCTAssertTrue(candidate.handoffSummary.contains(KairoL10n.string("chat.tool.summary.shortcutBoundary")))
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testAgentCoreAddsDeterministicNotificationPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "提醒我下班前整理 Kairo model list",
            expectedKind: .sendNotification,
            expectedTitle: KairoL10n.string("chat.action.displayName.scheduleNotification"),
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-send-notification"
        )
    }

    func testAgentCoreAddsDeterministicReminderPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Create a reminder to review the Shortcut node outputs",
            expectedKind: .createReminderDraft,
            expectedTitle: KairoL10n.string("chat.action.displayName.createReminder"),
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-create-reminder"
        )
    }

    func testAgentCoreAddsDeterministicCalendarPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Create a calendar event: Kairo launch review",
            expectedKind: .createCalendarDraft,
            expectedTitle: KairoL10n.string("chat.action.displayName.createCalendar"),
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-create-calendar-event"
        )
    }

    func testAgentCoreAddsDeterministicContactPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Create a contact: Alex Chen 555-0100 alex@example.com",
            expectedKind: .createContactDraft,
            expectedTitle: KairoL10n.string("chat.action.displayName.createContact"),
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-create-contact"
        )
    }

    func testAgentCoreAddsDeterministicEmailDraftPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.",
            expectedKind: .composeEmailDraft,
            expectedTitle: KairoL10n.string("chat.action.displayName.composeEmail"),
            expectedRiskTier: .tier1Draft,
            expectedCandidateID: "action-compose-email-draft"
        )
    }

    func testAgentCoreAddsDeterministicMapDirectionsPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Drive to Apple Park",
            expectedKind: .openMapDirections,
            expectedTitle: KairoL10n.string("chat.action.displayName.openMaps"),
            expectedRiskTier: .tier1Draft,
            expectedCandidateID: "action-open-map-directions"
        )
    }

    func testAgentCoreAddsDeterministicMessagePreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Text 0912-345-678 body I am running late.",
            expectedKind: AgentActionKind(rawValue: "openMessageHandoff")!,
            expectedTitle: KairoL10n.string("chat.action.displayName.openMessages"),
            expectedRiskTier: .tier1Draft,
            expectedCandidateID: "action-open-message-handoff"
        )
    }

    func testAgentCoreAddsDeterministicPhoneCallPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Call 0912-345-678",
            expectedKind: .openPhoneCallHandoff,
            expectedTitle: KairoL10n.string("chat.action.displayName.openPhone"),
            expectedRiskTier: .tier1Draft,
            expectedCandidateID: "action-open-phone-call-handoff"
        )
    }

    func testAgentCoreAddsDeterministicWebSearchPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Search web for SwiftUI App Intents examples",
            expectedKind: .openWebSearchHandoff,
            expectedTitle: KairoL10n.string("chat.action.displayName.openWebSearch"),
            expectedRiskTier: .tier1Draft,
            expectedCandidateID: "action-open-web-search-handoff"
        )
    }

    private func assertPreviewAction(
        prompt: String,
        expectedKind: AgentActionKind,
        expectedTitle: String,
        expectedRiskTier: ActionRiskTier,
        expectedCandidateID: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let response = try await makeAgent().respond(to: prompt)

        let action = try XCTUnwrap(
            response.proposedActions.first { $0.kind == expectedKind },
            file: file,
            line: line
        )
        XCTAssertEqual(action.title, expectedTitle, file: file, line: line)
        XCTAssertEqual(action.riskTier, expectedRiskTier, file: file, line: line)
        XCTAssertTrue(action.requiresConfirmation, file: file, line: line)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == expectedCandidateID }, file: file, line: line)
    }

    private func makeAgent() -> AgentCore {
        AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )
    }
}
