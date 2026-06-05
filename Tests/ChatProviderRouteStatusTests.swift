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
        actionExecutor: any ActionExecutor,
        localModelSettingsService: LocalModelSettingsService?,
        openAISettingsService: OpenAISettingsService?,
        localModelChatRuntimeAvailable: Bool
    ) -> ChatFeatureDependencies {
        ChatFeatureDependencies(
            historyStore: historyStore,
            shareImportAPI: EmptyShareImportAPI(),
            chatAPI: StubChatAPI(),
            actionAPI: NoopActionAPI(),
            localModelSettingsService: localModelSettingsService,
            openAISettingsService: openAISettingsService,
            localModelChatRuntimeAvailable: localModelChatRuntimeAvailable
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
