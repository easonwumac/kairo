import Foundation

public actor AgentCore {
    private let memoryStore: MemoryStore
    private let aiProvider: AIProvider
    private let safetyPolicyEngine: SafetyPolicyEngine
    private let capabilityRegistry: CapabilityRegistry
    private let skillCatalogProvider: AgentSkillCatalogProvider
    private let integrationRegistry: IntegrationRegistry

    public init(
        memoryStore: MemoryStore = InMemoryMemoryStore(),
        aiProvider: AIProvider = MockAIProvider(),
        skillCatalog: AgentSkillCatalog = .default,
        skillCatalogProvider: AgentSkillCatalogProvider? = nil,
        integrationRegistry: IntegrationRegistry = IntegrationRegistry(),
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry()
    ) {
        self.memoryStore = memoryStore
        self.aiProvider = aiProvider
        self.safetyPolicyEngine = safetyPolicyEngine
        self.capabilityRegistry = capabilityRegistry
        self.skillCatalogProvider = skillCatalogProvider ?? .constant(skillCatalog)
        self.integrationRegistry = integrationRegistry
    }

    public func respond(to message: String, attachments: [ChatAttachment] = []) async throws -> AICompletionResponse {
        let memories = try await memoryStore.search(query: message, limit: 8)
        let skillCatalog = try await skillCatalogProvider.catalog()
        let allowedCapabilities = capabilityRegistry.capabilities
            .filter { $0.status == .available || $0.status == .unknown }
            .map(\.key)
        let toolContext = CapabilityPromptContextBuilder(
            capabilityRegistry: capabilityRegistry,
            actionCatalog: SandboxActionCatalog(),
            integrationRegistry: integrationRegistry,
            skillCatalog: skillCatalog
        ).build()
        let toolPlan = AgentToolInvocationPlanner(
            skillCatalog: skillCatalog,
            integrationRegistry: integrationRegistry,
            safetyPolicyEngine: safetyPolicyEngine
        ).plan(for: AgentToolInvocationRequest(userText: message))

        let request = AICompletionRequest(
            systemPrompt: Self.systemPrompt,
            userPrompt: message,
            memoryContext: memories,
            allowedCapabilities: allowedCapabilities,
            attachmentContext: attachments,
            toolContext: toolContext
        )

        let response = try await aiProvider.complete(request)
        let proposedActions = Self.mergeActionPreviews(
            modelActions: response.proposedActions,
            toolActions: toolPlan.proposedActions
        )
        let safeActions = proposedActions.filter { action in
            safetyPolicyEngine.evaluate(action).allowed
        }

        return AICompletionResponse(
            message: response.message,
            proposedActions: safeActions,
            toolCandidates: toolPlan.candidates
        )
    }

    public func remember(_ content: String, title: String? = nil, source: MemorySource = .manual) async throws -> MemoryRecord {
        let memory = MemoryRecord(
            title: title ?? String(content.prefix(40)),
            summary: String(content.prefix(160)),
            content: content,
            source: source
        )
        try await memoryStore.save(memory)
        return memory
    }

    public static let systemPrompt = """
    你是 Kairo，一個有記憶的 iPhone Agent。
    你只能使用使用者明確授權、iOS public API、App sandbox、App Intents、Shortcuts、Share Extension 與外部服務官方 API 允許的能力。
    你不可聲稱可以任意讀取其他 App、偷看螢幕、繞過權限、控制未授權的 iOS 系統功能或使用 private API。
    可執行的 sandbox 動作限於明確支援的儲存記憶、EventKit 提醒事項/行事曆、HomeKit 家庭控制、開啟使用者可見 URL、本機通知，以及使用者授權的 App Intents/Shortcuts/OAuth 整合。
    若使用者要求 iOS sandbox 或目前整合不允許的事，請用 unsupportedSandboxAction 清楚說明限制與安全替代方案，不要假裝已完成。
    對高風險操作，你必須先產生預覽並要求使用者確認。
    """

    private static func mergeActionPreviews(
        modelActions: [AgentAction],
        toolActions: [AgentAction]
    ) -> [AgentAction] {
        var merged = modelActions

        for action in toolActions where !merged.contains(where: { existing in
            existing.kind == action.kind && existing.payload == action.payload
        }) {
            merged.append(action)
        }

        return merged
    }
}
