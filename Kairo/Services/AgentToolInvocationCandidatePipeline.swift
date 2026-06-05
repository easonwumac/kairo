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
        primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping,
        fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending,
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
        primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting,
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping,
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping,
        fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> [AgentToolInvocationCandidate] {
        var candidates = primaryCandidateCollector.candidates(in: AgentPrimaryToolCandidateContext(
            request: request,
            normalizedText: normalizedText,
            skillCatalog: skillCatalog,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            appIntegrationActionMapper: appIntegrationActionMapper,
            appIntegrationActionParser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            installedSkillCandidateMapper: installedSkillCandidateMapper,
            legacyIntegrationCandidateMapper: legacyIntegrationCandidateMapper,
            appIntegrationCandidateMapper: appIntegrationCandidateMapper,
            safetyPolicyEngine: safetyPolicyEngine
        ))

        fallbackActionCandidateAppender.appendFallbackCandidates(
            to: &candidates,
            userText: request.userText,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser,
            visibleHandoffCandidateProvider: visibleHandoffCandidateProvider,
            writeActionCandidateProvider: writeActionCandidateProvider
        )

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
