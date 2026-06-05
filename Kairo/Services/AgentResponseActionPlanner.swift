import Foundation

public struct AgentResponseActionPlanningRequest: Sendable {
    public var userMessage: String
    public var modelActions: [AgentAction]
    public var toolCandidates: [AgentToolInvocationCandidate]
    public var memoryContext: AgentMemoryContext
    public var privacyMode: ChatPrivacyMode

    public init(
        userMessage: String,
        modelActions: [AgentAction],
        toolCandidates: [AgentToolInvocationCandidate],
        memoryContext: AgentMemoryContext,
        privacyMode: ChatPrivacyMode
    ) {
        self.userMessage = userMessage
        self.modelActions = modelActions
        self.toolCandidates = toolCandidates
        self.memoryContext = memoryContext
        self.privacyMode = privacyMode
    }
}

public struct AgentResponseActionPlan: Sendable {
    public var proposedActions: [AgentAction]
    public var toolCandidates: [AgentToolInvocationCandidate]

    public init(
        proposedActions: [AgentAction],
        toolCandidates: [AgentToolInvocationCandidate]
    ) {
        self.proposedActions = proposedActions
        self.toolCandidates = toolCandidates
    }
}

public protocol AgentResponseActionPlanning: Sendable {
    func planActions(for request: AgentResponseActionPlanningRequest) -> AgentResponseActionPlan
}

public struct DefaultAgentResponseActionPlanner: AgentResponseActionPlanning {
    private let actionGate: any PhoneToolActionGating
    private let safetyPolicyEngine: any ActionSafetyPolicyEvaluating
    private let memoryCandidateExtractor: MemoryCandidateExtractor

    public init(
        actionGate: any PhoneToolActionGating,
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine(),
        memoryCandidateExtractor: MemoryCandidateExtractor = MemoryCandidateExtractor()
    ) {
        self.actionGate = actionGate
        self.safetyPolicyEngine = safetyPolicyEngine
        self.memoryCandidateExtractor = memoryCandidateExtractor
    }

    public func planActions(for request: AgentResponseActionPlanningRequest) -> AgentResponseActionPlan {
        let toolCandidates = Self.filteredToolCandidates(
            request.toolCandidates,
            privacyMode: request.privacyMode
        )
        var proposedActions = Self.mergeActionPreviews(
            modelActions: request.modelActions,
            toolActions: toolCandidates.compactMap(\.action)
        )
        if request.privacyMode != .privateChat,
           let memoryAction = memoryCandidateExtractor.proposedSaveMemoryAction(
            from: request.userMessage,
            memoryContext: request.memoryContext.deduplicationContext
           ) {
            proposedActions = Self.mergeActionPreviews(modelActions: proposedActions, toolActions: [memoryAction])
        }

        let catalogFilteredActions = proposedActions.filter { action in
            actionGate.allowsExecutablePreview(action)
        }
        let safeActions = catalogFilteredActions.filter { action in
            safetyPolicyEngine.evaluate(action).allowed
        }
        let privacyFilteredActions = Self.filteredActions(
            safeActions,
            privacyMode: request.privacyMode
        )

        return AgentResponseActionPlan(
            proposedActions: privacyFilteredActions,
            toolCandidates: toolCandidates
        )
    }

    private static func mergeActionPreviews(
        modelActions: [AgentAction],
        toolActions: [AgentAction]
    ) -> [AgentAction] {
        var merged = modelActions

        for action in toolActions where !merged.contains(where: { existing in
            existing.kind == action.kind && existing.payload == action.payload
        }) {
            merged.append(action)
        }

        return merged
    }

    private static func filteredActions(
        _ actions: [AgentAction],
        privacyMode: ChatPrivacyMode
    ) -> [AgentAction] {
        guard privacyMode == .privateChat else {
            return actions
        }
        return []
    }

    private static func filteredToolCandidates(
        _ candidates: [AgentToolInvocationCandidate],
        privacyMode: ChatPrivacyMode
    ) -> [AgentToolInvocationCandidate] {
        guard privacyMode == .privateChat else {
            return candidates
        }
        return candidates.filter { candidate in
            !candidate.requiredCapabilities.contains(.memory)
            && candidate.action?.kind != .saveMemory
        }
    }
}
