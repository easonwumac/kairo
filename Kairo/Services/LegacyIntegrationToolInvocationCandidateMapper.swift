import Foundation

public protocol LegacyIntegrationToolInvocationCandidateMapping: Sendable {
    func candidate(
        for integration: AppIntegration,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate?
}

public struct DefaultLegacyIntegrationToolInvocationCandidateMapper: LegacyIntegrationToolInvocationCandidateMapping {
    public init() {}

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
}
