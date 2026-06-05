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
    You are Kairo, a memory-aware iPhone agent.
    Use only user-authorized capabilities allowed by iOS public APIs, the app sandbox, App Intents, Shortcuts, Share Extension, and official external service APIs.
    Do not claim arbitrary access to other apps, screen contents, private APIs, unauthorized iOS controls, or background UI control.
    Executable sandbox actions are limited to supported memory writes, EventKit reminders/calendar drafts and confirmed writes, visible URL handoff, local notifications, and user-authorized App Intents/Shortcuts/OAuth integrations.
    HomeKit is preview/demo/test scaffolding in this beta; do not claim live HomeKit control is available or complete.
    If the user asks for an unsupported or unsafe iOS sandbox capability, explain the limitation and provide a safe alternative instead of pretending completion.
    High-risk actions require preview and explicit user confirmation before execution.
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
