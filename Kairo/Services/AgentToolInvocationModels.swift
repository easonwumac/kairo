import Foundation

public enum AgentToolInvocationSource: String, Codable, Equatable, Sendable {
    case installedSkill
    case integrationRegistry
    case appIntegrationCatalog
    case actionCatalog
}

public struct AgentToolInvocationRequest: Codable, Equatable, Sendable {
    public var userText: String
    public var matchingText: String
    public var allowsToolUse: Bool

    public init(userText: String, matchingText: String? = nil, allowsToolUse: Bool = true) {
        self.userText = userText
        self.matchingText = matchingText ?? userText
        self.allowsToolUse = allowsToolUse
    }
}

public struct AgentToolInvocationPlan: Codable, Equatable, Sendable {
    public var candidates: [AgentToolInvocationCandidate]
    public var unsupportedMessage: String?

    public init(candidates: [AgentToolInvocationCandidate], unsupportedMessage: String? = nil) {
        self.candidates = candidates
        self.unsupportedMessage = unsupportedMessage
    }

    public var proposedActions: [AgentAction] {
        candidates.compactMap(\.action)
    }
}

public struct AgentToolInvocationCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var source: AgentToolInvocationSource
    public var skillID: String?
    public var integrationKey: String?
    public var skillKind: AgentSkillKind
    public var shortcutRecipeID: String?
    public var requiredCapabilities: [CapabilityKey]
    public var riskTier: ActionRiskTier
    public var requiresConfirmation: Bool
    public var handoffSummary: String
    public var action: AgentAction?

    public init(
        id: String,
        title: String,
        source: AgentToolInvocationSource,
        skillID: String? = nil,
        integrationKey: String? = nil,
        skillKind: AgentSkillKind,
        shortcutRecipeID: String? = nil,
        requiredCapabilities: [CapabilityKey],
        riskTier: ActionRiskTier,
        requiresConfirmation: Bool,
        handoffSummary: String,
        action: AgentAction? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.skillID = skillID
        self.integrationKey = integrationKey
        self.skillKind = skillKind
        self.shortcutRecipeID = shortcutRecipeID
        self.requiredCapabilities = requiredCapabilities
        self.riskTier = riskTier
        self.requiresConfirmation = requiresConfirmation
        self.handoffSummary = handoffSummary
        self.action = action
    }
}

extension Array where Element == AgentToolInvocationCandidate {
    func containsAction(kind: AgentActionKind?) -> Bool {
        guard let kind else { return false }
        return contains { $0.action?.kind == kind }
    }
}
