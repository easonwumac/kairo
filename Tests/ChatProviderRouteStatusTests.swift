import XCTest
@testable import KairoCore

final class ChatProviderRouteStatusTests: XCTestCase {
    @MainActor
    func testChatViewModelConvenienceInitializerUsesInjectedDependencyComposer() async throws {
        let viewModel = ChatViewModel(dependencyComposer: StubChatFeatureDependencyComposer())

        await viewModel.send("hello")

        XCTAssertEqual(viewModel.currentThread.messages.last?.text, "stub-composer-response")
    }

    @MainActor
    func testChatViewModelConvenienceInitializerLeavesActionExecutorCompositionToDependencyComposer() async throws {
        let composer = RecordingChatFeatureDependencyComposer()
        _ = ChatViewModel(dependencyComposer: composer)

        XCTAssertEqual(composer.receivedNilActionExecutor, true)
    }

    func testChatFeatureDependencyFactoryPreservesInjectedActionDescriptorProvider() throws {
        let descriptorProvider = FixedActionDescriptorProvider(kind: .unsupportedSandboxAction)
        let dependencies = ChatFeatureDependencyFactory().makeDependencies(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            credentialStore: InMemoryCredentialStore(),
            chatAPI: StubChatAPI(),
            shareImportAPI: EmptyShareImportAPI(),
            actionAPI: NoopActionAPI(),
            actionExecutor: NoopActionExecutor(),
            localModelSettingsService: nil,
            localModelChatRuntimeAvailable: false,
            actionDescriptorProvider: descriptorProvider
        )

        XCTAssertEqual(
            dependencies.actionDescriptorProvider.descriptor(for: .createReminderDraft)?.kind,
            .unsupportedSandboxAction
        )
    }

    @MainActor
    func testChatRouteStatusReflectsOpenAIKeySaveAndDelete() async throws {
        let credentials = InMemoryCredentialStore()
        let settingsService = OpenAISettingsService(credentialStore: credentials)
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: makeProviderRouteChatAPI(),
            openAISettingsService: settingsService
        )

        await viewModel.refreshProviderRouteStatus()
        XCTAssertEqual(
            viewModel.providerRouteStatus.title,
            KairoL10n.string("chat.provider.route.title", KairoL10n.string("chat.provider.route.cloud"))
        )
        XCTAssertEqual(
            viewModel.providerRouteStatus.warning,
            KairoL10n.string("chat.provider.warning.openAIKeyMissing", "OpenAI")
        )
        XCTAssertEqual(
            viewModel.providerRouteStatus.detail,
            KairoL10n.string("chat.provider.detail.cloudKeyMissing", "OpenAI")
        )

        try await settingsService.saveAPIKey("sk-test-chat-route")
        await viewModel.refreshProviderRouteStatus()
        XCTAssertNil(viewModel.providerRouteStatus.warning)
        XCTAssertEqual(
            viewModel.providerRouteStatus.detail,
            KairoL10n.string("chat.provider.detail.cloudConfigured", "OpenAI")
        )

        try await settingsService.deleteAPIKey()
        await viewModel.refreshProviderRouteStatus()
        XCTAssertEqual(
            viewModel.providerRouteStatus.warning,
            KairoL10n.string("chat.provider.warning.openAIKeyMissing", "OpenAI")
        )
    }

    private func makeProviderRouteChatAPI() -> any KairoChatAPI {
        KairoChatBackendService(
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
        )
    }
}

private struct StubChatFeatureDependencyComposer: ChatFeatureDependencyComposing {
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
    ) -> ChatFeatureDependencies {
        ChatFeatureDependencies(
            historyStore: historyStore,
            shareImportAPI: EmptyShareImportAPI(),
            chatAPI: StubChatAPI(),
            actionAPI: NoopActionAPI(),
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
            actionDescriptorProvider: actionDescriptorProvider
        )
    }
}

private final class RecordingChatFeatureDependencyComposer: ChatFeatureDependencyComposing, @unchecked Sendable {
    private(set) var receivedNilActionExecutor: Bool?

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
    ) -> ChatFeatureDependencies {
        receivedNilActionExecutor = actionExecutor == nil
        return ChatFeatureDependencies(
            historyStore: historyStore,
            shareImportAPI: EmptyShareImportAPI(),
            chatAPI: StubChatAPI(),
            actionAPI: NoopActionAPI(),
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
            actionDescriptorProvider: actionDescriptorProvider
        )
    }
}

private struct StubChatAPI: KairoChatAPI {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        AICompletionResponse(message: "stub-composer-response")
    }
}

private struct EmptyShareImportAPI: KairoShareImportAPI {
    func importPendingShares(limit: Int) async throws -> KairoShareImportResult {
        KairoShareImportResult(attachments: [], suggestedPrompt: nil, importedItemIDs: [])
    }

    func clearImportedShares(ids: [UUID], attachments: [ChatAttachment]) async throws {}
}

private struct NoopActionAPI: KairoActionAPI {
    func preview(_ action: AgentAction) async -> KairoActionPreview {
        KairoActionPreview(action: action, decision: SafetyPolicyDecision(allowed: true, requiresConfirmation: false, reason: ""))
    }

    func confirm(_ action: AgentAction) async throws -> ActionExecutionResult {
        ActionExecutionResult(completed: true, message: "noop")
    }
}

private struct NoopActionExecutor: ActionExecutor {
    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult {
        ActionExecutionResult(completed: true, message: "noop")
    }
}

private struct FixedActionDescriptorProvider: AgentActionDescriptorProviding {
    var kind: AgentActionKind

    func descriptor(for kind: AgentActionKind) -> SandboxActionDescriptor? {
        SandboxActionDescriptor(
            kind: self.kind,
            displayName: "Injected",
            description: "Injected descriptor.",
            capability: .appIntents,
            permissionRequirement: .userInitiated,
            riskTier: .tier0ReadOnly,
            supportStatus: .implemented
        )
    }
}
