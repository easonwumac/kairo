#if canImport(SwiftUI)
import Foundation

public struct ChatFeatureDependencies {
    public var historyStore: any ChatHistoryStore
    public var shareImportAPI: any KairoShareImportAPI
    public var actionInboxAPI: any KairoActionInboxAPI
    public var chatAPI: any KairoChatAPI
    public var actionAPI: any KairoActionAPI
    public var infoPageStore: InfoPageStore?
    public var localModelSettingsService: LocalModelSettingsService?
    public var openAISettingsService: OpenAISettingsService?
    public var localModelChatRuntimeAvailable: Bool
    public var actionDescriptorProvider: any AgentActionDescriptorProviding
    public var threadCompactor: (any ChatThreadCompacting)?
    public var knowledgeAssetAPI: (any KairoKnowledgeAssetAPI)?
    public var chatAttachmentRootDirectory: URL?

    public init(
        historyStore: any ChatHistoryStore,
        shareImportAPI: any KairoShareImportAPI,
        actionInboxAPI: any KairoActionInboxAPI,
        chatAPI: any KairoChatAPI,
        actionAPI: any KairoActionAPI,
        infoPageStore: InfoPageStore? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        openAISettingsService: OpenAISettingsService? = nil,
        localModelChatRuntimeAvailable: Bool = false,
        actionDescriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider(),
        threadCompactor: (any ChatThreadCompacting)? = nil,
        knowledgeAssetAPI: (any KairoKnowledgeAssetAPI)? = nil,
        chatAttachmentRootDirectory: URL? = nil
    ) {
        self.historyStore = historyStore
        self.shareImportAPI = shareImportAPI
        self.actionInboxAPI = actionInboxAPI
        self.chatAPI = chatAPI
        self.actionAPI = actionAPI
        self.infoPageStore = infoPageStore
        self.localModelSettingsService = localModelSettingsService
        self.openAISettingsService = openAISettingsService
        self.localModelChatRuntimeAvailable = localModelChatRuntimeAvailable
        self.actionDescriptorProvider = actionDescriptorProvider
        self.threadCompactor = threadCompactor
        self.knowledgeAssetAPI = knowledgeAssetAPI
        self.chatAttachmentRootDirectory = chatAttachmentRootDirectory
    }
}

public protocol ChatFeatureDependencyComposing: Sendable {
    func makeDependencies(
        historyStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        chatAPI: (any KairoChatAPI)?,
        shareImportAPI: (any KairoShareImportAPI)?,
        actionInboxAPI: (any KairoActionInboxAPI)?,
        actionAPI: (any KairoActionAPI)?,
        actionExecutor: (any ActionExecutor)?,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService?,
        localModelChatRuntimeAvailable: Bool,
        actionDescriptorProvider: any AgentActionDescriptorProviding
    ) -> ChatFeatureDependencies
}

public struct DefaultChatFeatureDependencyComposer: ChatFeatureDependencyComposing {
    public init() {}

    public func makeDependencies(
        historyStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        chatAPI: (any KairoChatAPI)?,
        shareImportAPI: (any KairoShareImportAPI)?,
        actionInboxAPI: (any KairoActionInboxAPI)?,
        actionAPI: (any KairoActionAPI)?,
        actionExecutor: (any ActionExecutor)?,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService?,
        localModelChatRuntimeAvailable: Bool,
        actionDescriptorProvider: any AgentActionDescriptorProviding
    ) -> ChatFeatureDependencies {
        ChatFeatureDependencies(
            historyStore: historyStore,
            shareImportAPI: shareImportAPI ?? KairoShareImportBackendService(shareIngestionQueue: shareIngestionQueue),
            actionInboxAPI: actionInboxAPI ?? KairoActionInboxBackendService(shareIngestionQueue: shareIngestionQueue),
            chatAPI: chatAPI ?? UnavailableChatAPI(),
            actionAPI: actionAPI ?? KairoActionBackendService(
                actionExecutor: actionExecutor ?? SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
            ),
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
            actionDescriptorProvider: actionDescriptorProvider
        )
    }
}

public struct ChatFeatureDependencyFactory: Sendable {
    private let composer: any ChatFeatureDependencyComposing

    public init(composer: any ChatFeatureDependencyComposing = DefaultChatFeatureDependencyComposer()) {
        self.composer = composer
    }

    public func makeDependencies(
        historyStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        credentialStore: any CredentialStore,
        chatAPI: (any KairoChatAPI)?,
        shareImportAPI: (any KairoShareImportAPI)?,
        actionInboxAPI: (any KairoActionInboxAPI)? = nil,
        actionAPI: (any KairoActionAPI)?,
        actionExecutor: any ActionExecutor,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService? = nil,
        infoPageStore: InfoPageStore? = nil,
        localModelChatRuntimeAvailable: Bool,
        actionDescriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider()
    ) -> ChatFeatureDependencies {
        var deps = composer.makeDependencies(
            historyStore: historyStore,
            shareIngestionQueue: shareIngestionQueue,
            chatAPI: chatAPI,
            shareImportAPI: shareImportAPI,
            actionInboxAPI: actionInboxAPI,
            actionAPI: actionAPI,
            actionExecutor: actionExecutor,
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService ?? OpenAISettingsService(credentialStore: credentialStore),
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
            actionDescriptorProvider: actionDescriptorProvider
        )
        deps.infoPageStore = infoPageStore
        return deps
    }
}

private struct UnavailableChatAPI: KairoChatAPI {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        _ = message
        _ = attachments
        _ = privacyMode
        throw AIProviderError.localInferenceUnavailable(
            KairoL10n.string("chat.error.localInference.reason.runtimeUnavailable")
        )
    }

    func respond(
        to message: String,
        attachments: [ChatAttachment],
        conversationID: String?,
        conversationHistory: [AIConversationTurn],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        _ = message
        _ = attachments
        _ = conversationID
        _ = conversationHistory
        _ = privacyMode
        throw AIProviderError.localInferenceUnavailable(
            KairoL10n.string("chat.error.localInference.reason.runtimeUnavailable")
        )
    }
}

public extension KairoEnvironment {
    var chatFeatureDependencies: ChatFeatureDependencies {
        var deps = ChatFeatureDependencyFactory().makeDependencies(
            historyStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            credentialStore: credentialStore,
            chatAPI: backendAPI.chat,
            shareImportAPI: backendAPI.shareImports,
            actionInboxAPI: backendAPI.actionInbox,
            actionAPI: backendAPI.actions,
            actionExecutor: actionExecutor,
            localModelSettingsService: localModelSettingsService,
            infoPageStore: sharedInfoPageStore,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable
        )
        deps.threadCompactor = DefaultChatThreadCompactor(summarizer: aiProvider)
        deps.knowledgeAssetAPI = backendAPI.knowledgeAssets
        deps.chatAttachmentRootDirectory = chatAttachmentsDirectory
        return deps
    }

}
#endif
