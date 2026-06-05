import Foundation

public protocol AgentToolInvocationCandidateBuilding: Sendable {
    func candidate(
        for skill: AgentSkill,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> AgentToolInvocationCandidate?
    func candidate(
        for integration: AppIntegration,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate?
    func candidate(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        actionMapper: any AppIntegrationActionMapping
    ) -> AgentToolInvocationCandidate?
}

public struct DefaultAgentToolInvocationCandidateBuilder: AgentToolInvocationCandidateBuilding {
    private let appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping

    public init(
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper()
    ) {
        self.appIntegrationCandidateMapper = appIntegrationCandidateMapper
    }

    public func candidate(
        for skill: AgentSkill,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> AgentToolInvocationCandidate? {
        switch skill.kind {
        case .homeKitControl:
            guard matcher.matches(skill: skill, normalizedText: normalizedText, parser: parser) else { return nil }
            let riskTier = skill.action?.riskTier ?? .tier3HighRiskExternal
            let requiresConfirmation = skill.action.map { safetyPolicyEngine.evaluate($0).requiresConfirmation } ?? riskTier.requiresConfirmation
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: riskTier,
                requiresConfirmation: requiresConfirmation,
                handoffSummary: KairoL10n.string("chat.tool.summary.homeKitSkill"),
                action: skill.action
            )
        case .shortcutWorkflow:
            guard matcher.matches(skill: skill, normalizedText: normalizedText, parser: parser) else { return nil }
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                shortcutRecipeID: skill.shortcutRecipeID,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: .tier1Draft,
                requiresConfirmation: true,
                handoffSummary: shortcutHandoffSummary(for: skill)
            )
        case .oauthConnector:
            guard matcher.matches(skill: skill, normalizedText: normalizedText, parser: parser) else { return nil }
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: .tier3HighRiskExternal,
                requiresConfirmation: true,
                handoffSummary: KairoL10n.string("chat.tool.summary.oauthSkill")
            )
        case .custom:
            guard matcher.matches(skill: skill, normalizedText: normalizedText, parser: parser) else { return nil }
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: skill.action?.riskTier ?? .tier1Draft,
                requiresConfirmation: (skill.action?.riskTier ?? .tier1Draft).requiresConfirmation,
                handoffSummary: KairoL10n.string("chat.tool.summary.managedSkill"),
                action: skill.action
            )
        case .localModel:
            return nil
        }
    }

    public func candidate(
        for integration: AppIntegration,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard matcher.matches(integration: integration, normalizedText: normalizedText, parser: parser) else {
            return nil
        }

        return AgentToolInvocationCandidate(
            id: "integration-\(integration.key)",
            title: integration.displayName,
            source: .integrationRegistry,
            integrationKey: integration.key,
            skillKind: .oauthConnector,
            requiredCapabilities: integration.requiredCapabilities,
            riskTier: .tier3HighRiskExternal,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.tool.summary.integration", integration.displayName)
        )
    }

    public func candidate(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        actionMapper: any AppIntegrationActionMapping
    ) -> AgentToolInvocationCandidate? {
        guard matcher.matches(appIntegrationSkill: skill, normalizedText: normalizedText, parser: parser) else {
            return nil
        }
        return appIntegrationCandidateMapper.candidate(
            for: skill,
            userText: userText,
            normalizedText: normalizedText,
            parser: parser,
            actionMapper: actionMapper
        )
    }

    private func shortcutHandoffSummary(for skill: AgentSkill) -> String {
        let boundary = KairoL10n.string("chat.tool.summary.shortcutBoundary")
        guard
            let recipeID = skill.shortcutRecipeID,
            let recipe = ShortcutDemoCatalog.default.recipe(id: recipeID)
        else {
            return boundary
        }
        return "\(boundary) \(recipe.settingsStepSummary). \(recipe.settingsInputSummary). \(recipe.settingsOutputSummary)."
    }
}
