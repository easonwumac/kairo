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

    func testAgentCoreFiltersProviderProposedActionsThroughPhoneToolCatalog() async throws {
        var calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        calendarTool.availabilityStatus = .unsupported
        let providerAction = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "Provider suggested a calendar write.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Blocked provider action",
                notes: nil,
                startDate: Date(timeIntervalSince1970: 10),
                endDate: Date(timeIntervalSince1970: 70)
            )),
            riskTier: .tier2LowRiskWrite
        )
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(
            message: "Provider response",
            proposedActions: [providerAction]
        ))
        let agent = AgentCore(
            aiProvider: provider,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [calendarTool])
        )

        let response = try await agent.respond(to: "General status check")

        XCTAssertTrue(response.proposedActions.isEmpty)
        XCTAssertTrue(response.toolCandidates.isEmpty)
    }

    func testAgentCoreUsesInjectedPhoneToolActionGateForActionPreviews() async throws {
        let agent = AgentCore(
            aiProvider: MockAIProvider(),
            actionGate: BlockingPhoneToolActionGate()
        )

        let response = try await agent.respond(to: "Create a calendar event for launch review")

        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testAgentCoreKeepsUnsupportedSandboxExplanationOutsideExecutableCatalog() async throws {
        let explanation = UnsupportedActionExplanation(
            requestedAction: "Read another app",
            reason: "iOS sandbox does not allow this.",
            safeAlternative: "Share the content into Kairo."
        )
        let providerAction = AgentAction(
            kind: .unsupportedSandboxAction,
            title: "Unsupported",
            rationale: "Explain the sandbox boundary.",
            payload: .unsupported(explanation),
            riskTier: .tier0ReadOnly
        )
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(
            message: "Provider response",
            proposedActions: [providerAction]
        ))
        let agent = AgentCore(
            aiProvider: provider,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [])
        )

        let response = try await agent.respond(to: "Read my other apps")

        XCTAssertEqual(response.proposedActions.map(\.kind), [.unsupportedSandboxAction])
    }

    func testAgentCoreAddsDeterministicNotificationPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "提醒我下班前整理 Kairo model list",
            expectedKind: .sendNotification,
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-send-notification"
        )
    }

    func testAgentCoreAddsDeterministicReminderPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Create a reminder to review the Shortcut node outputs",
            expectedKind: .createReminderDraft,
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-create-reminder"
        )
    }

    func testAgentCoreAddsDeterministicCalendarPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Create a calendar event: Kairo launch review",
            expectedKind: .createCalendarDraft,
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-create-calendar-event"
        )
    }

    func testAgentCoreAddsDeterministicContactPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Create a contact: Alex Chen 555-0100 alex@example.com",
            expectedKind: .createContactDraft,
            expectedRiskTier: .tier2LowRiskWrite,
            expectedCandidateID: "action-create-contact"
        )
    }

    func testAgentCoreAddsDeterministicEmailDraftPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.",
            expectedKind: .composeEmailDraft,
            expectedRiskTier: .tier1Draft
        )
    }

    func testAgentCoreAddsDeterministicMapDirectionsPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Drive to Apple Park",
            expectedKind: .openMapDirections,
            expectedRiskTier: .tier1Draft,
            expectedCandidateID: "action-open-map-directions"
        )
    }

    func testAgentCoreAddsDeterministicMessagePreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Text 0912-345-678 body I am running late.",
            expectedKind: AgentActionKind(rawValue: "openMessageHandoff")!,
            expectedRiskTier: .tier1Draft
        )
    }

    func testAgentCoreAddsDeterministicPhoneCallPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Call 0912-345-678",
            expectedKind: .openPhoneCallHandoff,
            expectedRiskTier: .tier1Draft
        )
    }

    func testAgentCoreAddsDeterministicWebSearchPreviewAction() async throws {
        try await assertPreviewAction(
            prompt: "Search web for SwiftUI App Intents examples",
            expectedKind: .openWebSearchHandoff,
            expectedRiskTier: .tier1Draft
        )
    }

    private func assertPreviewAction(
        prompt: String,
        expectedKind: AgentActionKind,
        expectedRiskTier: ActionRiskTier,
        expectedCandidateID: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let response = try await makeAgent().respond(to: prompt)

        let action = try XCTUnwrap(
            response.proposedActions.first { $0.kind == expectedKind },
            file: file,
            line: line
        )
        XCTAssertEqual(action.riskTier, expectedRiskTier, file: file, line: line)
        XCTAssertTrue(action.requiresConfirmation, file: file, line: line)
        XCTAssertTrue(response.toolCandidates.contains { $0.action?.kind == expectedKind }, file: file, line: line)
        if let expectedCandidateID {
            XCTAssertTrue(response.toolCandidates.contains { $0.id == expectedCandidateID }, file: file, line: line)
        }
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

private struct BlockingPhoneToolActionGate: PhoneToolActionGating {
    func allowsExecutablePreview(_ action: AgentAction) -> Bool {
        false
    }

    func filterExecutablePreviews(_ actions: [AgentAction]) -> [AgentAction] {
        []
    }

    func blockedTool(for shortcutNodeKind: ShortcutNodeKind) -> BuiltInPhoneToolDefinition? {
        nil
    }

    func blockedTool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition? {
        nil
    }
}
