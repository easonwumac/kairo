import Foundation

public struct AgentToolCandidatePlanningDependencies: Sendable {
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
    public var candidatePipeline: any AgentToolInvocationCandidatePipelining
    public var candidateFilter: any AgentToolCandidateFiltering
    public var safetyPolicyEngine: any ActionSafetyPolicyEvaluating

    public init(
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding = DefaultAgentVisibleHandoffCandidateProvider(),
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding = DefaultAgentWriteActionCandidateProvider(),
        candidateMatcher: any AgentToolInvocationCandidateMatching = DefaultAgentToolInvocationCandidateMatcher(),
        primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting = DefaultAgentPrimaryToolCandidateCollector(),
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping = DefaultLegacyIntegrationToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper(),
        fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending = DefaultAgentFallbackActionCandidateAppender(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        candidateFilter: (any AgentToolCandidateFiltering)? = nil,
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine()
    ) {
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
        self.candidatePipeline = candidatePipeline
        self.candidateFilter = candidateFilter ?? PhoneToolCandidateFilter(
            actionGate: BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        )
        self.safetyPolicyEngine = safetyPolicyEngine
    }
}

public struct AgentToolInvocationPlannerDependencies: Sendable {
    public var candidatePlanning: AgentToolCandidatePlanningDependencies

    public var integrationRegistry: any AppIntegrationRegistryProviding {
        get { candidatePlanning.integrationRegistry }
        set { candidatePlanning.integrationRegistry = newValue }
    }

    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding {
        get { candidatePlanning.appIntegrationSkillCatalog }
        set { candidatePlanning.appIntegrationSkillCatalog = newValue }
    }

    public var appIntegrationActionMapper: any AppIntegrationActionMapping {
        get { candidatePlanning.appIntegrationActionMapper }
        set { candidatePlanning.appIntegrationActionMapper = newValue }
    }

    public var appIntegrationActionParser: any AgentToolInvocationActionParsing {
        get { candidatePlanning.appIntegrationActionParser }
        set { candidatePlanning.appIntegrationActionParser = newValue }
    }

    public var visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding {
        get { candidatePlanning.visibleHandoffCandidateProvider }
        set { candidatePlanning.visibleHandoffCandidateProvider = newValue }
    }

    public var writeActionCandidateProvider: any AgentWriteActionCandidateProviding {
        get { candidatePlanning.writeActionCandidateProvider }
        set { candidatePlanning.writeActionCandidateProvider = newValue }
    }

    public var candidateMatcher: any AgentToolInvocationCandidateMatching {
        get { candidatePlanning.candidateMatcher }
        set { candidatePlanning.candidateMatcher = newValue }
    }

    public var primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting {
        get { candidatePlanning.primaryCandidateCollector }
        set { candidatePlanning.primaryCandidateCollector = newValue }
    }

    public var installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping {
        get { candidatePlanning.installedSkillCandidateMapper }
        set { candidatePlanning.installedSkillCandidateMapper = newValue }
    }

    public var legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping {
        get { candidatePlanning.legacyIntegrationCandidateMapper }
        set { candidatePlanning.legacyIntegrationCandidateMapper = newValue }
    }

    public var appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping {
        get { candidatePlanning.appIntegrationCandidateMapper }
        set { candidatePlanning.appIntegrationCandidateMapper = newValue }
    }

    public var fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending {
        get { candidatePlanning.fallbackActionCandidateAppender }
        set { candidatePlanning.fallbackActionCandidateAppender = newValue }
    }

    public var candidatePipeline: any AgentToolInvocationCandidatePipelining {
        get { candidatePlanning.candidatePipeline }
        set { candidatePlanning.candidatePipeline = newValue }
    }

    public var candidateFilter: any AgentToolCandidateFiltering {
        get { candidatePlanning.candidateFilter }
        set { candidatePlanning.candidateFilter = newValue }
    }

    public var safetyPolicyEngine: any ActionSafetyPolicyEvaluating {
        get { candidatePlanning.safetyPolicyEngine }
        set { candidatePlanning.safetyPolicyEngine = newValue }
    }

    public init(candidatePlanning: AgentToolCandidatePlanningDependencies) {
        self.candidatePlanning = candidatePlanning
    }

    public init(
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        visibleHandoffCandidateProvider: any AgentVisibleHandoffCandidateProviding = DefaultAgentVisibleHandoffCandidateProvider(),
        writeActionCandidateProvider: any AgentWriteActionCandidateProviding = DefaultAgentWriteActionCandidateProvider(),
        candidateMatcher: any AgentToolInvocationCandidateMatching = DefaultAgentToolInvocationCandidateMatcher(),
        primaryCandidateCollector: any AgentPrimaryToolCandidateCollecting = DefaultAgentPrimaryToolCandidateCollector(),
        installedSkillCandidateMapper: any InstalledSkillToolInvocationCandidateMapping = DefaultInstalledSkillToolInvocationCandidateMapper(),
        legacyIntegrationCandidateMapper: any LegacyIntegrationToolInvocationCandidateMapping = DefaultLegacyIntegrationToolInvocationCandidateMapper(),
        appIntegrationCandidateMapper: any AppIntegrationToolInvocationCandidateMapping = DefaultAppIntegrationToolInvocationCandidateMapper(),
        fallbackActionCandidateAppender: any AgentFallbackActionCandidateAppending = DefaultAgentFallbackActionCandidateAppender(),
        candidatePipeline: any AgentToolInvocationCandidatePipelining = DefaultAgentToolInvocationCandidatePipeline(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        candidateFilter: (any AgentToolCandidateFiltering)? = nil,
        safetyPolicyEngine: any ActionSafetyPolicyEvaluating = SafetyPolicyEngine()
    ) {
        self.init(candidatePlanning: AgentToolCandidatePlanningDependencies(
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            appIntegrationActionMapper: appIntegrationActionMapper,
            appIntegrationActionParser: appIntegrationActionParser,
            visibleHandoffCandidateProvider: visibleHandoffCandidateProvider,
            writeActionCandidateProvider: writeActionCandidateProvider,
            candidateMatcher: candidateMatcher,
            primaryCandidateCollector: primaryCandidateCollector,
            installedSkillCandidateMapper: installedSkillCandidateMapper,
            legacyIntegrationCandidateMapper: legacyIntegrationCandidateMapper,
            appIntegrationCandidateMapper: appIntegrationCandidateMapper,
            fallbackActionCandidateAppender: fallbackActionCandidateAppender,
            candidatePipeline: candidatePipeline,
            toolCatalog: toolCatalog,
            candidateFilter: candidateFilter,
            safetyPolicyEngine: safetyPolicyEngine
        ))
    }
}
