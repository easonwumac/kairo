import Foundation

public protocol AgentToolInvocationCandidatePipelining: Sendable {
    func candidates(
        for request: AgentToolInvocationRequest,
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        appIntegrationActionMapper: any AppIntegrationActionMapping,
        appIntegrationActionParser: any AgentToolInvocationActionParsing,
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding,
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentToolInvocationCandidatePipeline: AgentToolInvocationCandidatePipelining {
    public init() {}

    public func candidates(
        for request: AgentToolInvocationRequest,
        normalizedText: String,
        skillCatalog: AgentSkillCatalog,
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        appIntegrationActionMapper: any AppIntegrationActionMapping,
        appIntegrationActionParser: any AgentToolInvocationActionParsing,
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding,
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> [AgentToolInvocationCandidate] {
        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: skillCatalog.installedSkills.compactMap { skill in
            installedSkillCandidateMapper.candidate(
                for: skill,
                normalizedText: normalizedText,
                matcher: candidateMatcher,
                parser: appIntegrationActionParser,
                safetyPolicyEngine: safetyPolicyEngine
            )
        })
        candidates.append(contentsOf: appIntegrationSkillCatalog.skills.compactMap { skill in
            guard candidateMatcher.matches(appIntegrationSkill: skill, normalizedText: normalizedText, parser: appIntegrationActionParser) else {
                return nil
            }
            return appIntegrationCandidateMapper.candidate(
                for: skill,
                userText: request.userText,
                normalizedText: normalizedText,
                parser: appIntegrationActionParser,
                actionMapper: appIntegrationActionMapper
            )
        })

        candidates.append(contentsOf: integrationRegistry.oauthConnectorsNotMigrated(to: appIntegrationSkillCatalog).compactMap { integration in
            return legacyIntegrationCandidateMapper.candidate(
                for: integration,
                normalizedText: normalizedText,
                matcher: candidateMatcher,
                parser: appIntegrationActionParser
            )
        })

        for handoffCandidate in visibleHandoffCandidateProvider.candidates(
            userText: request.userText,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        ) where !candidates.containsAction(kind: handoffCandidate.action?.kind) {
            candidates.append(handoffCandidate)
        }

        for writeCandidate in writeActionCandidateProvider.candidates(
            userText: request.userText,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        ) where !candidates.containsAction(kind: writeCandidate.action?.kind) {
            candidates.append(writeCandidate)
        }

        return uniqueCandidates(candidates)
    }

    private func uniqueCandidates(_ candidates: [AgentToolInvocationCandidate]) -> [AgentToolInvocationCandidate] {
        var seen: Set<String> = []
        var result: [AgentToolInvocationCandidate] = []

        for candidate in candidates where !seen.contains(candidate.id) {
            seen.insert(candidate.id)
            result.append(candidate)
        }

        return result
    }
}
