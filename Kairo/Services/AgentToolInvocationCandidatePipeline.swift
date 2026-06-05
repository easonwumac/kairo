import Foundation

public struct AgentToolInvocationCandidatePipelineContext: Sendable {
    public var request: AgentToolInvocationRequest
    public var normalizedText: String
    public var skillCatalog: AgentSkillCatalog
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var appIntegrationActionMapper: any AppIntegrationActionMapping
    public var appIntegrationActionParser: any AgentToolInvocationActionParsing
    public var visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding
    public var writeActionCandidateProvider: any AgentWriteActionCandidateProviding
    public var candidateMatcher: any AgentToolInvocationCandidateMatching
    public var primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting
    public var installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping
    public var legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping
    public var appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping
    public var fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        request: AgentToolInvocationRequest,
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
    ) {
        self.request = request
        self.normalizedText = normalizedText
        self.skillCatalog = skillCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionMapper = appIntegrationActionMapper
        self.appIntegrationActionParser = appIntegrationActionParser
        self.visibleHandoffCandidateProvider = visibleHandoffCandidateProvider
        self.writeActionCandidateProvider = writeActionCandidateProvider
        self.candidateMatcher = candidateMatcher
        self.primaryCandidateCollector = primaryCandidateCollector
        self.installedSkillCandidateMapper = installedSkillCandidateMapper
        self.legacyIntegrationCandidateMapper = legacyIntegrationCandidateMapper
        self.appIntegrationCandidateMapper = appIntegrationCandidateMapper
        self.fallbackActionCandidateAppender = fallbackActionCandidateAppender
        self.safetyPolicyEngine = safetyPolicyEngine
    }
}

public protocol AgentToolInvocationCandidatePipelining: Sendable {
    func candidates(in context: AgentToolInvocationCandidatePipelineContext) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentToolInvocationCandidatePipeline: AgentToolInvocationCandidatePipelining {
    public init() {}

    public func candidates(in context: AgentToolInvocationCandidatePipelineContext) -> [AgentToolInvocationCandidate] {
        var candidates = context.primaryCandidateCollector.candidates(in: AgentPrimaryToolCandidateContext(
            request: context.request,
            normalizedText: context.normalizedText,
            skillCatalog: context.skillCatalog,
            integrationRegistry: context.integrationRegistry,
            appIntegrationSkillCatalog: context.appIntegrationSkillCatalog,
            appIntegrationActionMapper: context.appIntegrationActionMapper,
            appIntegrationActionParser: context.appIntegrationActionParser,
            candidateMatcher: context.candidateMatcher,
            installedSkillCandidateMapper: context.installedSkillCandidateMapper,
            legacyIntegrationCandidateMapper: context.legacyIntegrationCandidateMapper,
            appIntegrationCandidateMapper: context.appIntegrationCandidateMapper,
            safetyPolicyEngine: context.safetyPolicyEngine
        ))

        context.fallbackActionCandidateAppender.appendFallbackCandidates(
            to: &candidates,
            userText: context.request.userText,
            normalizedText: context.normalizedText,
            parser: context.appIntegrationActionParser,
            visibleHandoffCandidateProvider: context.visibleHandoffCandidateProvider,
            writeActionCandidateProvider: context.writeActionCandidateProvider
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
