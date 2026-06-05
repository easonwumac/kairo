import Foundation

public protocol AgentLegacyIntegrationCandidateCollecting: Sendable {
    func candidates(
        normalizedText: String,
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        parser: any AgentToolInvocationActionParsing,
        candidateMatcher: any AgentToolInvocationCandidateMatching,
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentLegacyIntegrationCandidateCollector: AgentLegacyIntegrationCandidateCollecting {
    public init() {}

    public func candidates(
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
