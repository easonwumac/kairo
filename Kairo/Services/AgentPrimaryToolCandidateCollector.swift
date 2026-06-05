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
    private let installedSkillCandidateCollector: any AgentInstalledSkillCandidateCollecting
    private let appIntegrationSkillCandidateCollector: any AgentAppIntegrationSkillCandidateCollecting
    private let legacyIntegrationCandidateCollector: any AgentLegacyIntegrationCandidateCollecting

    public init(
        installedSkillCandidateCollector: any AgentInstalledSkillCandidateCollecting = DefaultAgentInstalledSkillCandidateCollector(),
        appIntegrationSkillCandidateCollector: any AgentAppIntegrationSkillCandidateCollecting = DefaultAgentAppIntegrationSkillCandidateCollector(),
        legacyIntegrationCandidateCollector: any AgentLegacyIntegrationCandidateCollecting = DefaultAgentLegacyIntegrationCandidateCollector()
    ) {
        self.installedSkillCandidateCollector = installedSkillCandidateCollector
        self.appIntegrationSkillCandidateCollector = appIntegrationSkillCandidateCollector
        self.legacyIntegrationCandidateCollector = legacyIntegrationCandidateCollector
    }

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
        candidates.append(contentsOf: installedSkillCandidateCollector.candidates(
            normalizedText: normalizedText,
            skillCatalog: skillCatalog,
            parser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            installedSkillCandidateMapper: installedSkillCandidateMapper,
            safetyPolicyEngine: safetyPolicyEngine
        ))
        candidates.append(contentsOf: appIntegrationSkillCandidateCollector.candidates(
            userText: request.userText,
            normalizedText: normalizedText,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            appIntegrationActionMapper: appIntegrationActionMapper,
            parser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            appIntegrationCandidateMapper: appIntegrationCandidateMapper
        ))
        candidates.append(contentsOf: legacyIntegrationCandidateCollector.candidates(
            normalizedText: normalizedText,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            parser: appIntegrationActionParser,
            candidateMatcher: candidateMatcher,
            legacyIntegrationCandidateMapper: legacyIntegrationCandidateMapper
        ))
        return candidates
    }
}
