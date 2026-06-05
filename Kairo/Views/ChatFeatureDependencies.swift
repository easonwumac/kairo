#if canImport(SwiftUI)
import Foundation

public struct ChatFeatureDependencies {
    public var historyStore: any ChatHistoryStore
    public var shareImportAPI: any KairoShareImportAPI
    public var chatAPI: any KairoChatAPI
    public var actionAPI: any KairoActionAPI
    public var localModelSettingsService: LocalModelSettingsService?
    public var openAISettingsService: OpenAISettingsService?
    public var localModelChatRuntimeAvailable: Bool

    public init(
        historyStore: any ChatHistoryStore = InMemoryChatHistoryStore(),
        shareImportAPI: any KairoShareImportAPI = KairoShareImportBackendService(shareIngestionQueue: InMemoryShareIngestionQueue()),
        chatAPI: any KairoChatAPI = KairoChatBackendService(agent: AgentCore()),
        actionAPI: any KairoActionAPI = KairoActionBackendService(
            actionExecutor: SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        ),
        localModelSettingsService: LocalModelSettingsService? = nil,
        openAISettingsService: OpenAISettingsService? = nil,
        localModelChatRuntimeAvailable: Bool = false
    ) {
        self.historyStore = historyStore
        self.shareImportAPI = shareImportAPI
        self.chatAPI = chatAPI
        self.actionAPI = actionAPI
        self.localModelSettingsService = localModelSettingsService
        self.openAISettingsService = openAISettingsService
        self.localModelChatRuntimeAvailable = localModelChatRuntimeAvailable
    }
}

public extension KairoEnvironment {
    var chatFeatureDependencies: ChatFeatureDependencies {
        ChatFeatureDependencies(
            historyStore: chatHistoryStore,
            shareImportAPI: backendAPI.shareImports,
            chatAPI: backendAPI.chat,
            actionAPI: backendAPI.actions,
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: OpenAISettingsService(credentialStore: credentialStore),
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable
        )
    }
}
#endif
