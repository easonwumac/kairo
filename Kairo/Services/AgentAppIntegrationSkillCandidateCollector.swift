import Foundation

public protocol AgentAppIntegrationSkillCandidateCollecting: Sendable {
    func candidates(
        userText: String,
        normalizedText: String,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        appIntegrationActionMapper: any AppIntegrationActionMapping,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentAppIntegrationSkillCandidateCollector: AgentAppIntegrationSkillCandidateCollecting {
    public init() {}

    public func candidates(
        userText: String,
        normalizedText: String,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        appIntegrationActionMapper: any AppIntegrationActionMapping,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping
    ) -> [AgentToolInvocationCandidate] {
        appIntegrationSkillCatalog.skills.compactMap { skill in
            guard candidateMatcher.matches(appIntegrationSkill: skill, normalizedText: normalizedText, parser: parser) else {
                return nil
            }
            return appIntegrationCandidateMapper.candidate(
                for: skill,
                userText: userText,
                normalizedText: normalizedText,
                parser: parser,
                actionMapper: appIntegrationActionMapper
            )
        }
    }
}
