import Foundation

public actor AgentCore {
    private let memoryStore: MemoryStore
    private let aiProvider: AIProvider
    private let safetyPolicyEngine: SafetyPolicyEngine
    private let capabilityRegistry: CapabilityRegistry

    public init(
        memoryStore: MemoryStore = InMemoryMemoryStore(),
        aiProvider: AIProvider = MockAIProvider(),
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry()
    ) {
        self.memoryStore = memoryStore
        self.aiProvider = aiProvider
        self.safetyPolicyEngine = safetyPolicyEngine
        self.capabilityRegistry = capabilityRegistry
    }

    public func respond(to message: String) async throws -> AICompletionResponse {
        let memories = try await memoryStore.search(query: message, limit: 8)
        let allowedCapabilities = capabilityRegistry.capabilities
            .filter { $0.status == .available || $0.status == .unknown }
            .map(\.key)

        let request = AICompletionRequest(
            systemPrompt: Self.systemPrompt,
            userPrompt: message,
            memoryContext: memories,
            allowedCapabilities: allowedCapabilities
        )

        let response = try await aiProvider.complete(request)
        let safeActions = response.proposedActions.filter { action in
            safetyPolicyEngine.evaluate(action).allowed
        }

        return AICompletionResponse(message: response.message, proposedActions: safeActions)
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
    對高風險操作，你必須先產生預覽並要求使用者確認。
    """
}
