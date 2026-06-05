import Foundation

public protocol AgentPrimaryToolCandidateCollecting: Sendable {
    func candidates(
        for request: AgentToolInvocationRequest,
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        appIntegrationActionMapper: any AppIntegrationActionMapping,
        appIntegrationActionParser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentPrimaryToolCandidateCollector: AgentPrimaryToolCandidateCollecting {
    public init() {}

    public func candidates(
        for request: AgentToolInvocationRequest,
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        appIntegrationActionMapper: any AppIntegrationActionMapping,
        appIntegrationActionParser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> [AgentToolInvocationCandidate] {
        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: installedSkillCandidates(
            normalizedText: normalizedText,
            skillCatalog: skillCatalog,
            parser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            installedSkillCandidateMapper: installedSkillCandidateMapper,
            safetyPolicyEngine: safetyPolicyEngine
        ))
        candidates.append(contentsOf: appIntegrationCandidates(
            request: request,
            normalizedText: normalizedText,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            appIntegrationActionMapper: appIntegrationActionMapper,
            parser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            appIntegrationCandidateMapper: appIntegrationCandidateMapper
        ))
        candidates.append(contentsOf: legacyIntegrationCandidates(
            normalizedText: normalizedText,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            parser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            legacyIntegrationCandidateMapper: legacyIntegrationCandidateMapper
        ))
        return candidates
    }

    private func installedSkillCandidates(
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        safetyPolicyEngine: SafetyPolicyEngine
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

    private func appIntegrationCandidates(
        request: AgentToolInvocationRequest,
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
                userText: request.userText,
                normalizedText: normalizedText,
                parser: parser,
                actionMapper: appIntegrationActionMapper
            )
        }
    }

    private func legacyIntegrationCandidates(
        normalizedText: String,
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping
    ) -> [AgentToolInvocationCandidate] {
        integrationRegistry.oauthConnectorsNotMigrated(to: appIntegrationSkillCatalog).compactMap { integration in
            legacyIntegrationCandidateMapper.candidate(
                for: integration,
                normalizedText: normalizedText,
                matcher: candidateMatcher,
                parser: parser
            )
        }
    }
}
