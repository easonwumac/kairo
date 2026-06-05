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
        historyStore: any ChatHistoryStore,
        shareImportAPI: any KairoShareImportAPI,
        chatAPI: any KairoChatAPI,
        actionAPI: any KairoActionAPI,
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

public protocol ChatFeatureDependencyComposing: Sendable {
    func makeDependencies(
        historyStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        chatAPI: (any KairoChatAPI)?,
        shareImportAPI: (any KairoShareImportAPI)?,
        actionAPI: (any KairoActionAPI)?,
        actionExecutor: any ActionExecutor,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService?,
        localModelChatRuntimeAvailable: Bool
    ) -> ChatFeatureDependencies
}

public struct DefaultChatFeatureDependencyComposer: ChatFeatureDependencyComposing {
    public init() {}

    public func makeDependencies(
        historyStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        chatAPI: (any KairoChatAPI)?,
        shareImportAPI: (any KairoShareImportAPI)?,
        actionAPI: (any KairoActionAPI)?,
        actionExecutor: any ActionExecutor,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService?,
        localModelChatRuntimeAvailable: Bool
    ) -> ChatFeatureDependencies {
        ChatFeatureDependencies(
            historyStore: historyStore,
            shareImportAPI: shareImportAPI ?? KairoShareImportBackendService(shareIngestionQueue: shareIngestionQueue),
            chatAPI: chatAPI ?? UnavailableChatAPI(),
            actionAPI: actionAPI ?? KairoActionBackendService(actionExecutor: actionExecutor),
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable
        )
    }
}

private struct UnavailableChatAPI: KairoChatAPI {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        throw AIProviderError.localInferenceUnavailable(
            KairoL10n.string("chat.error.localInference.reason.runtimeUnavailable")
        )
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
