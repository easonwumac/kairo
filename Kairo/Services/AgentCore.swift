import Foundation

public actor AgentCore {
    private let memoryContextProvider: any AgentMemoryContextProviding
    private let memoryWriter: any AgentMemoryWriting
    private let aiProvider: AIProvider
    private let capabilityRegistry: CapabilityRegistry
    private let skillCatalogProvider: AgentSkillCatalogProvider
    private let toolContextProvider: any AgentCapabilityPromptContextProviding
    private let toolInvocationPlanner: any AgentToolInvocationPlanning
    private let responseActionPlanner: any AgentResponseActionPlanning

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
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        memoryCandidateExtractor: MemoryCandidateExtractor = MemoryCandidateExtractor()
    ) {
        let resolvedActionGate = actionGate ?? BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        self.memoryContextProvider = memoryContextProvider ?? DefaultAgentMemoryContextProvider(memoryStore: memoryStore)
        self.memoryWriter = memoryWriter ?? DefaultAgentMemoryWriter(memoryStore: memoryStore)
        self.aiProvider = aiProvider
        self.capabilityRegistry = capabilityRegistry
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
    }

    public func respond(
        to message: String,
        attachments: [ChatAttachment] = [],
        privacyMode: ChatPrivacyMode = .standard
    ) async throws -> AICompletionResponse {
        let memoryContext = try await memoryContextProvider.context(for: message, privacyMode: privacyMode)
        let skillCatalog = try await skillCatalogProvider.catalog()
        let allowedCapabilities = capabilityRegistry.capabilities
            .filter { $0.status == .available || $0.status == .unknown }
            .map(\.key)
        let toolContext = toolContextProvider.buildToolContext(skillCatalog: skillCatalog)
        let toolPlan = toolInvocationPlanner.plan(for: AgentToolInvocationRequest(
            userText: message,
            matchingText: Self.planningText(message: message, attachments: attachments),
            allowsToolUse: privacyMode != .privateChat
        ), skillCatalog: skillCatalog)

        let request = AICompletionRequest(
            systemPrompt: Self.systemPrompt,
            userPrompt: message,
            memoryContext: memoryContext.relevantMemories,
            allowedCapabilities: allowedCapabilities,
            attachmentContext: attachments,
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

    public static let systemPrompt = """
    你是 Kairo，一個有記憶的 iPhone Agent。
    你只能使用使用者明確授權、iOS public API、App sandbox、App Intents、Shortcuts、Share Extension 與外部服務官方 API 允許的能力。
    你不可聲稱可以任意讀取其他 App、偷看螢幕、繞過權限、控制未授權的 iOS 系統功能或使用 private API。
    可執行的 sandbox 動作限於明確支援的儲存記憶、EventKit 提醒事項/行事曆、開啟使用者可見 URL、本機通知，以及使用者授權的 App Intents/Shortcuts/OAuth 整合。
    HomeKit 在目前 beta 只限 preview/demo/test scaffolding；不要聲稱真實 HomeKit live control 已可用或已完成。
    若使用者要求 iOS sandbox 或目前整合不允許的事，請用 unsupportedSandboxAction 清楚說明限制與安全替代方案，不要假裝已完成。
    對高風險操作，你必須先產生預覽並要求使用者確認。
    """

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
