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
    public var actionDescriptorProvider: any AgentActionDescriptorProviding

    public init(
        historyStore: any ChatHistoryStore,
        shareImportAPI: any KairoShareImportAPI,
        chatAPI: any KairoChatAPI,
        actionAPI: any KairoActionAPI,
        localModelSettingsService: LocalModelSettingsService? = nil,
        openAISettingsService: OpenAISettingsService? = nil,
        localModelChatRuntimeAvailable: Bool = false,
        actionDescriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider()
    ) {
        self.historyStore = historyStore
        self.shareImportAPI = shareImportAPI
        self.chatAPI = chatAPI
        self.actionAPI = actionAPI
        self.localModelSettingsService = localModelSettingsService
        self.openAISettingsService = openAISettingsService
        self.localModelChatRuntimeAvailable = localModelChatRuntimeAvailable
        self.actionDescriptorProvider = actionDescriptorProvider
    }
}

public protocol ChatFeatureDependencyComposing: Sendable {
    func makeDependencies(
        historyStore: any ChatHistoryStore,
        shareIngestionQueue: any ShareIngestionQueue,
        chatAPI: (any KairoChatAPI)?,
        shareImportAPI: (any KairoShareImportAPI)?,
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
        actionAPI: (any KairoActionAPI)?,
        actionExecutor: any ActionExecutor,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService? = nil,
        localModelChatRuntimeAvailable: Bool,
        actionDescriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider()
    ) -> ChatFeatureDependencies {
        composer.makeDependencies(
            historyStore: historyStore,
            shareIngestionQueue: shareIngestionQueue,
            chatAPI: chatAPI,
            shareImportAPI: shareImportAPI,
            actionAPI: actionAPI,
            actionExecutor: actionExecutor,
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService ?? OpenAISettingsService(credentialStore: credentialStore),
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
            actionDescriptorProvider: actionDescriptorProvider
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
        ChatFeatureDependencyFactory().makeDependencies(
            historyStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            credentialStore: credentialStore,
            chatAPI: backendAPI.chat,
            shareImportAPI: backendAPI.shareImports,
            actionAPI: backendAPI.actions,
            actionExecutor: actionExecutor,
            localModelSettingsService: localModelSettingsService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable
        )
    }
}
#endif
