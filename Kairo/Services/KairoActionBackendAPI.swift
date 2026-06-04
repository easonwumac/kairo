import Foundation

public struct KairoActionPreview: Equatable, Sendable {
    public var action: AgentAction
    public var decision: SafetyPolicyDecision

    public init(action: AgentAction, decision: SafetyPolicyDecision) {
        self.action = action
        self.decision = decision
    }
}

public protocol KairoActionAPI: Sendable {
    func preview(_ action: AgentAction) async -> KairoActionPreview
    func confirm(_ action: AgentAction) async throws -> ActionExecutionResult
}

public struct KairoActionBackendService: KairoActionAPI {
    private let actionExecutor: any ActionExecutor
    private let safetyPolicyEngine: SafetyPolicyEngine

    public init(
        actionExecutor: any ActionExecutor,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.actionExecutor = actionExecutor
        self.safetyPolicyEngine = safetyPolicyEngine
    }

    public func preview(_ action: AgentAction) async -> KairoActionPreview {
        KairoActionPreview(
            action: action,
            decision: safetyPolicyEngine.evaluate(action)
        )
    }

    public func confirm(_ action: AgentAction) async throws -> ActionExecutionResult {
        try await actionExecutor.execute(action, confirmed: true)
    }
}
