import Foundation

public actor AgentCore {
    private let memoryContextProvider: any AgentMemoryContextProviding
    private let memoryWriter: any AgentMemoryWriting
    private let aiProvider: AIProvider
    private let skillCatalogProvider: AgentSkillCatalogProvider
    private let toolContextProvider: any AgentCapabilityPromptContextProviding
    private let toolInvocationPlanner: any AgentToolInvocationPlanning
    private let responseActionPlanner: any AgentResponseActionPlanning
    private let completionRequestBuilder: any AgentCompletionRequestBuilding

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
        responseActionPlanner: (any AgentResponseActionPlanning)? = nil,
        completionRequestBuilder: (any AgentCompletionRequestBuilding)? = nil,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        memoryCandidateExtractor: MemoryCandidateExtractor = MemoryCandidateExtractor()
    ) {
        let resolvedActionGate = actionGate ?? BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        self.memoryContextProvider = memoryContextProvider ?? DefaultAgentMemoryContextProvider(memoryStore: memoryStore)
        self.memoryWriter = memoryWriter ?? DefaultAgentMemoryWriter(memoryStore: memoryStore)
        self.aiProvider = aiProvider
        self.skillCatalogProvider = skillCatalogProvider ?? .constant(skillCatalog)
        self.toolContextProvider = toolContextProvider ?? DefaultAgentCapabilityPromptContextProvider(
            capabilityRegistry: capabilityRegistry,
            toolCatalog: toolCatalog,
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
        self.toolInvocationPlanner = toolInvocationPlanner ?? DefaultAgentToolInvocationPlannerProvider(
            integrationRegistry: integrationRegistry,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            toolCatalog: toolCatalog,
            safetyPolicyEngine: safetyPolicyEngine
        )
        self.responseActionPlanner = responseActionPlanner ?? DefaultAgentResponseActionPlanner(
            actionGate: resolvedActionGate,
            safetyPolicyEngine: safetyPolicyEngine,
            memoryCandidateExtractor: memoryCandidateExtractor
        )
        self.completionRequestBuilder = completionRequestBuilder ?? DefaultAgentCompletionRequestBuilder(
            capabilityRegistry: capabilityRegistry,
            systemPrompt: Self.systemPrompt
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
        let toolPlan = toolInvocationPlanner.plan(for: AgentToolInvocationRequest(
            userText: message,
            matchingText: Self.planningText(message: message, attachments: attachments),
            allowsToolUse: privacyMode != .privateChat
        ), skillCatalog: skillCatalog)

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

    private static func planningText(message: String, attachments: [ChatAttachment]) -> String {
        let attachmentText = attachments
            .map(\.promptSummary)
            .joined(separator: "\n")
        guard !attachmentText.isEmpty else { return message }
        return [message, attachmentText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

}
