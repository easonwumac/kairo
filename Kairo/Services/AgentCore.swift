import Foundation

public actor AgentCore {
    private let memoryContextProvider: any AgentMemoryContextProviding
    private let memoryWriter: any AgentMemoryWriting
    private let aiProvider: AIProvider
    private let skillCatalogProvider: AgentSkillCatalogProvider
    private let toolContextProvider: any AgentCapabilityPromptContextProviding
    private let toolInvocationPlanner: any AgentToolInvocationPlanning
    private let toolPlanningRequestBuilder: any AgentToolPlanningRequestBuilding
    private let responseActionPlanner: any AgentResponseActionPlanning
    private let completionRequestBuilder: any AgentCompletionRequestBuilding

    public init(dependencies: AgentCoreDependencies) {
        self.memoryContextProvider = dependencies.memoryContextProvider
        self.memoryWriter = dependencies.memoryWriter
        self.aiProvider = dependencies.aiProvider
        self.skillCatalogProvider = dependencies.skillCatalogProvider
        self.toolContextProvider = dependencies.toolContextProvider
        self.toolInvocationPlanner = dependencies.toolInvocationPlanner
        self.toolPlanningRequestBuilder = dependencies.toolPlanningRequestBuilder
        self.responseActionPlanner = dependencies.responseActionPlanner
        self.completionRequestBuilder = dependencies.completionRequestBuilder
    }

    public init(
        memoryStore: MemoryStore = InMemoryMemoryStore(),
        aiProvider: AIProvider = MockAIProvider(),
        skillCatalog: AgentSkillCatalog = .default,
        skillCatalogProvider: AgentSkillCatalogProvider? = nil,
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        memoryContextProvider: (any AgentMemoryContextProviding)? = nil,
        memoryWriter: (any AgentMemoryWriting)? = nil,
        actionGate: (any PhoneToolActionGating)? = nil,
        toolContextProvider: (any AgentCapabilityPromptContextProviding)? = nil,
        toolInvocationPlanner: (any AgentToolInvocationPlanning)? = nil,
        toolPlanningRequestBuilder: (any AgentToolPlanningRequestBuilding)? = nil,
        responseActionPlanner: (any AgentResponseActionPlanning)? = nil,
        completionRequestBuilder: (any AgentCompletionRequestBuilding)? = nil,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        memoryCandidateExtractor: MemoryCandidateExtractor = MemoryCandidateExtractor()
    ) {
        let resolvedActionGate = actionGate ?? BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        let toolCandidatePlanningDependencies = Self.makeToolCandidatePlanningDependencies(
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            toolCatalog: toolCatalog,
            safetyPolicyEngine: safetyPolicyEngine
        )
        self.init(dependencies: AgentCoreDependencies(
            memoryContextProvider: memoryContextProvider ?? DefaultAgentMemoryContextProvider(memoryStore: memoryStore),
            memoryWriter: memoryWriter ?? DefaultAgentMemoryWriter(memoryStore: memoryStore),
            aiProvider: aiProvider,
            skillCatalogProvider: skillCatalogProvider ?? .constant(skillCatalog),
            toolContextProvider: toolContextProvider ?? DefaultAgentCapabilityPromptContextProvider(
                capabilityRegistry: capabilityRegistry,
                toolCatalog: toolCatalog,
                integrationRegistry: integrationRegistry,
                appIntegrationSkillCatalog: appIntegrationSkillCatalog
            ),
            toolInvocationPlanner: toolInvocationPlanner ?? DefaultAgentToolInvocationPlannerProvider(
                candidatePlanning: toolCandidatePlanningDependencies
            ),
            toolPlanningRequestBuilder: toolPlanningRequestBuilder ?? DefaultAgentToolPlanningRequestBuilder(),
            responseActionPlanner: responseActionPlanner ?? DefaultAgentResponseActionPlanner(
                actionGate: resolvedActionGate,
                safetyPolicyEngine: safetyPolicyEngine,
                memoryCandidateExtractor: memoryCandidateExtractor
            ),
            completionRequestBuilder: completionRequestBuilder ?? DefaultAgentCompletionRequestBuilder(
                capabilityRegistry: capabilityRegistry,
                systemPrompt: Self.systemPrompt
            )
        ))
    }

    private static func makeToolCandidatePlanningDependencies(
        integrationRegistry: any AppIntegrationRegistryProviding,
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding,
        toolCatalog: any BuiltInPhoneToolCatalogProviding,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> AgentToolCandidatePlanningDependencies {
        AgentToolCandidatePlanningDependencies(
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            toolCatalog: toolCatalog,
            safetyPolicyEngine: safetyPolicyEngine
        )
    }

    public func respond(
        to message: String,
        attachments: [ChatAttachment] = [],
        privacyMode: ChatPrivacyMode = .standard
    ) async throws -> AICompletionResponse {
        let memoryContext = try await memoryContextProvider.context(for: message, privacyMode: privacyMode)
        let skillCatalog = try await skillCatalogProvider.catalog()
        let toolContext = toolContextProvider.buildToolContext(skillCatalog: skillCatalog)
        let toolRequest = toolPlanningRequestBuilder.buildToolPlanningRequest(
            message: message,
            attachments: attachments,
            privacyMode: privacyMode
        )
        let toolPlan = toolInvocationPlanner.plan(for: toolRequest, skillCatalog: skillCatalog)

        let request = completionRequestBuilder.buildCompletionRequest(
            message: message,
            attachments: attachments,
            memoryContext: memoryContext,
            toolContext: toolContext,
            privacyMode: privacyMode
        )

        let response = try await aiProvider.complete(request)
        let actionPlan = responseActionPlanner.planActions(for: AgentResponseActionPlanningRequest(
            userMessage: message,
            modelActions: response.proposedActions,
            toolCandidates: toolPlan.candidates,
            memoryContext: memoryContext,
            privacyMode: privacyMode
        ))

        return AICompletionResponse(
            message: response.message,
            proposedActions: actionPlan.proposedActions,
            toolCandidates: actionPlan.toolCandidates,
            memoryContextCount: memoryContext.relevantMemories.count
        )
    }

    public func remember(_ content: String, title: String? = nil, source: MemorySource = .manual) async throws -> MemoryRecord {
        try await memoryWriter.remember(content, title: title, source: source)
    }

    public static let systemPrompt = DefaultAgentCompletionRequestBuilder.defaultSystemPrompt

}
