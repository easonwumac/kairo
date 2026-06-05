import Foundation

public struct AgentPrimaryToolCandidateContext: Sendable {
    public var request: AgentToolInvocationRequest
    public var normalizedText: String
    public var skillCatalog: AgentSkillCatalog
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var appIntegrationActionMapper: any AppIntegrationActionMapping
    public var appIntegrationActionParser: any AgentToolInvocationActionParsing
    public var candidateMatcher: any AgentToolInvocationCandidateMatching
    public var installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping
    public var legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping
    public var appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        request: AgentToolInvocationRequest,
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
    ) {
        self.request = request
        self.normalizedText = normalizedText
        self.skillCatalog = skillCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionMapper = appIntegrationActionMapper
        self.appIntegrationActionParser = appIntegrationActionParser
        self.candidateMatcher = candidateMatcher
        self.installedSkillCandidateMapper = installedSkillCandidateMapper
        self.legacyIntegrationCandidateMapper = legacyIntegrationCandidateMapper
        self.appIntegrationCandidateMapper = appIntegrationCandidateMapper
        self.safetyPolicyEngine = safetyPolicyEngine
    }
}

public protocol AgentPrimaryToolCandidateCollecting: Sendable {
    func candidates(in context: AgentPrimaryToolCandidateContext) -> [AgentToolInvocationCandidate]
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

    public func candidates(in context: AgentPrimaryToolCandidateContext) -> [AgentToolInvocationCandidate] {
        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: installedSkillCandidateCollector.candidates(
            normalizedText: context.normalizedText,
            skillCatalog: context.skillCatalog,
            parser: context.appIntegrationActionParser,
            candidateMatcher: context.candidateMatcher,
            installedSkillCandidateMapper: context.installedSkillCandidateMapper,
            safetyPolicyEngine: context.safetyPolicyEngine
        ))
        candidates.append(contentsOf: appIntegrationSkillCandidateCollector.candidates(
            userText: context.request.userText,
            normalizedText: context.normalizedText,
            appIntegrationSkillCatalog: context.appIntegrationSkillCatalog,
            appIntegrationActionMapper: context.appIntegrationActionMapper,
            parser: context.appIntegrationActionParser,
            candidateMatcher: context.candidateMatcher,
            appIntegrationCandidateMapper: context.appIntegrationCandidateMapper
        ))
        candidates.append(contentsOf: legacyIntegrationCandidateCollector.candidates(
            normalizedText: context.normalizedText,
            integrationRegistry: context.integrationRegistry,
            appIntegrationSkillCatalog: context.appIntegrationSkillCatalog,
            parser: context.appIntegrationActionParser,
            candidateMatcher: context.candidateMatcher,
            legacyIntegrationCandidateMapper: context.legacyIntegrationCandidateMapper
        ))
        return candidates
    }
}
