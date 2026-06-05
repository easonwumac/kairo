import Foundation

public struct AgentToolInvocationPlannerDependencies: Sendable {
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var appIntegrationActionMapper: any AppIntegrationActionMapping
    public var appIntegrationActionParser: any AgentToolInvocationActionParsing
    public var visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding
    public var writeActionCandidateProvider: any AgentWriteActionCandidateProviding
    public var candidateMatcher: any AgentToolInvocationCandidateMatching
    public var installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping
    public var legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping
    public var appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping
    public var candidatePipeline: any AgentToolInvocationCandidatePipelining
    public var candidateFilter: any AgentToolCandidateFiltering
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding = DefaultAgentVisibleHandoffCandidateProvider(),
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding = DefaultAgentWriteActionCandidateProvider(),
        candidateMatcher: any AgentToolInvocationCandidateMatching = DefaultAgentToolInvocationCandidateMatcher(),
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping = DefaultLegacyIntegrationToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        candidateFilter: (any AgentToolCandidateFiltering)? = nil,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionMapper = appIntegrationActionMapper
        self.appIntegrationActionParser = appIntegrationActionParser
        self.visibleHandoffCandidateProvider = visibleHandoffCandidateProvider
        self.writeActionCandidateProvider = writeActionCandidateProvider
        self.candidateMatcher = candidateMatcher
        self.installedSkillCandidateMapper = installedSkillCandidateMapper
        self.legacyIntegrationCandidateMapper = legacyIntegrationCandidateMapper
        self.appIntegrationCandidateMapper = appIntegrationCandidateMapper
        self.candidatePipeline = candidatePipeline
        self.candidateFilter = candidateFilter ?? PhoneToolCandidateFilter(
            actionGate: BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        )
        self.safetyPolicyEngine = safetyPolicyEngine
    }
}
