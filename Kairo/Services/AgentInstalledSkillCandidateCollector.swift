import Foundation

public protocol AgentInstalledSkillCandidateCollecting: Sendable {
    func candidates(
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentInstalledSkillCandidateCollector: AgentInstalledSkillCandidateCollecting {
    public init() {}

    public func candidates(
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating
    ) -> [AgentToolInvocationCandidate] {
        skillCatalog.installedSkills.compactMap { skill in
            installedSkillCandidateMapper.candidate(
                for: skill,
                normalizedText: normalizedText,
                matcher: candidateMatcher,
                parser: parser,
                safetyPolicyEngine: safetyPolicyEngine
            )
        }
    }
}
