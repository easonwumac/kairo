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
    private let installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping
    private let appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping

    public init(
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper()
    ) {
        self.installedSkillCandidateMapper = installedSkillCandidateMapper
        self.appIntegrationCandidateMapper = appIntegrationCandidateMapper
    }

    public func candidate(
        for skill: AgentSkill,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> AgentToolInvocationCandidate? {
        installedSkillCandidateMapper.candidate(
            for: skill,
            normalizedText: normalizedText,
            matcher: matcher,
            parser: parser,
            safetyPolicyEngine: safetyPolicyEngine
        )
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
}
