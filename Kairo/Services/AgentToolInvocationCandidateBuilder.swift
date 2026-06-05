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
    private let legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping
    private let appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping

    public init(
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping = DefaultLegacyIntegrationToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper()
    ) {
        self.installedSkillCandidateMapper = installedSkillCandidateMapper
        self.legacyIntegrationCandidateMapper = legacyIntegrationCandidateMapper
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
        legacyIntegrationCandidateMapper.candidate(
            for: integration,
            normalizedText: normalizedText,
            matcher: matcher,
            parser: parser
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
