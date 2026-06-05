import Foundation

public protocol AgentCompletionRequestBuilding: Sendable {
    func buildCompletionRequest(
        message: String,
        attachments: [ChatAttachment],
        memoryContext: AgentMemoryContext,
        toolContext: String?,
        privacyMode: ChatPrivacyMode
    ) -> AICompletionRequest
}

public struct DefaultAgentCompletionRequestBuilder: AgentCompletionRequestBuilding {
    public static let defaultSystemPrompt = """
    你是 Kairo，一個有記憶的 iPhone Agent。
    你只能使用使用者明確授權、iOS public API、App sandbox、App Intents、Shortcuts、Share Extension 與外部服務官方 API 允許的能力。
    你不可聲稱可以任意讀取其他 App、偷看螢幕、繞過權限、控制未授權的 iOS 系統功能或使用 private API。
    可執行的 sandbox 動作限於明確支援的儲存記憶、EventKit 提醒事項/行事曆、開啟使用者可見 URL、本機通知，以及使用者授權的 App Intents/Shortcuts/OAuth 整合。
    HomeKit 在目前 beta 只限 preview/demo/test scaffolding；不要聲稱真實 HomeKit live control 已可用或已完成。
    若使用者要求 iOS sandbox 或目前整合不允許的事，請用 unsupportedSandboxAction 清楚說明限制與安全替代方案，不要假裝已完成。
    對高風險操作，你必須先產生預覽並要求使用者確認。
    """

    private let capabilityRegistry: any CapabilityRegistryProviding
    private let systemPrompt: String

    public init(
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry(),
        systemPrompt: String = Self.defaultSystemPrompt
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.systemPrompt = systemPrompt
    }

    public func buildCompletionRequest(
        message: String,
        attachments: [ChatAttachment],
        memoryContext: AgentMemoryContext,
        toolContext: String?,
        privacyMode: ChatPrivacyMode
    ) -> AICompletionRequest {
        AICompletionRequest(
            systemPrompt: systemPrompt,
            userPrompt: message,
            memoryContext: memoryContext.relevantMemories,
            allowedCapabilities: allowedCapabilities,
            attachmentContext: attachments,
            toolContext: toolContext,
            privacyMode: privacyMode
        )
    }

    private var allowedCapabilities: [CapabilityKey] {
        capabilityRegistry.capabilities
            .filter { $0.status == .available || $0.status == .unknown }
            .map(\.key)
    }
}
