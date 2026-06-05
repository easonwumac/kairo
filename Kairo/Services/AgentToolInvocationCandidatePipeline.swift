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
        candidateBuilder: any AgentToolInvocationCandidateBuilding,
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
        candidateBuilder: any AgentToolInvocationCandidateBuilding,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> [AgentToolInvocationCandidate] {
        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: skillCatalog.installedSkills.compactMap { skill in
            candidateBuilder.candidate(
                for: skill,
                normalizedText: normalizedText,
                matcher: candidateMatcher,
                parser: appIntegrationActionParser,
                safetyPolicyEngine: safetyPolicyEngine
            )
        })
        candidates.append(contentsOf: appIntegrationSkillCatalog.skills.compactMap { skill in
            candidateBuilder.candidate(
                for: skill,
                userText: request.userText,
                normalizedText: normalizedText,
                matcher: candidateMatcher,
                parser: appIntegrationActionParser,
                actionMapper: appIntegrationActionMapper
            )
        })

        let migratedIntegrationKeys = Set(appIntegrationSkillCatalog.skills.map(\.integrationKey))
        candidates.append(contentsOf: integrationRegistry.oauthConnectors.compactMap { integration in
            guard !migratedIntegrationKeys.contains(integration.key) else { return nil }
            return candidateBuilder.candidate(
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
