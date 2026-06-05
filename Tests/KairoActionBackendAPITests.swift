import XCTest
@testable import KairoCore

final class KairoActionBackendAPITests: XCTestCase {
    func testActionBackendAPIPreviewsSafetyDecisionWithoutExecuting() async throws {
        let executor = AllowingBackendActionExecutor()
        let api = KairoActionBackendService(actionExecutor: executor)
        let action = makeReminderAction()

        let preview = await api.preview(action)

        XCTAssertEqual(preview.action.id, action.id)
        XCTAssertTrue(preview.decision.allowed)
        XCTAssertTrue(preview.decision.requiresConfirmation)
        let executedKinds = await executor.executedKinds()
        XCTAssertTrue(executedKinds.isEmpty)
    }

    func testActionBackendAPIPreviewsThroughInjectedSafetyPolicy() async throws {
        let executor = AllowingBackendActionExecutor()
        let api = KairoActionBackendService(
            actionExecutor: executor,
            safetyPolicyEngine: BlockingActionSafetyPolicy()
        )
        let action = makeReminderAction()

        let preview = await api.preview(action)

        XCTAssertEqual(preview.action.id, action.id)
        XCTAssertFalse(preview.decision.allowed)
        XCTAssertFalse(preview.decision.requiresConfirmation)
        let executedKinds = await executor.executedKinds()
        XCTAssertTrue(executedKinds.isEmpty)
    }

    func testActionBackendAPIConfirmsThroughInjectedExecutor() async throws {
        let executor = AllowingBackendActionExecutor()
        let api = KairoActionBackendService(actionExecutor: executor)
        let action = makeReminderAction()

        let result = try await api.confirm(action)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.createdIdentifier, action.id.uuidString)
        let executedKinds = await executor.executedKinds()
        let confirmations = await executor.confirmations()
        XCTAssertEqual(executedKinds, [.createReminderDraft])
        XCTAssertEqual(confirmations, [true])
    }

    private func makeReminderAction() -> AgentAction {
        AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User asked Kairo to create a reminder after preview.",
            payload: .reminder(ReminderDraft(
                title: "Review Kairo backend action API",
                notes: nil,
                dueDate: nil
            )),
            riskTier: .tier2LowRiskWrite
        )
    }
}

private struct BlockingActionSafetyPolicy: ActionSafetyPolicyEvaluating {
    func evaluate(_ action: AgentAction) -> SafetyPolicyDecision {
        SafetyPolicyDecision(
            allowed: false,
            requiresConfirmation: false,
            reason: "blocked"
        )
    }
}
