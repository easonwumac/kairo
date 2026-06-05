import XCTest
@testable import KairoCore

final class KairoBackendAPITests: XCTestCase {
    func testBackendAPIExposesProductionModuleRegistryForCoreComposition() throws {
        XCTAssertEqual(
            KairoBackendModuleRegistry.production.modules.map(\.id),
            KairoBackendModuleID.allCases
        )
        XCTAssertTrue(KairoBackendModuleRegistry.production.modules.allSatisfy { !$0.boundarySummary.isEmpty })

        let api = KairoBackendAPI(
            chat: KairoChatBackendService(agent: AgentCore()),
            memory: KairoMemoryBackendService(memoryStore: InMemoryMemoryStore()),
            recipes: KairoRecipeBackendService(recipeStore: InMemoryKairoRecipeStore()),
            shareImports: KairoShareImportBackendService(shareIngestionQueue: InMemoryShareIngestionQueue()),
            actions: KairoActionBackendService(
                actionExecutor: AllowingBackendActionExecutor()
            ),
            deletion: KairoDeletionBackendService(
                chatHistoryStore: InMemoryChatHistoryStore(),
                memoryStore: InMemoryMemoryStore(),
                credentialStore: InMemoryCredentialStore(),
                auditLogger: InMemoryAuditLogger()
            ),
            localModels: KairoLocalModelBackendService(localModelSettingsService: nil),
            skills: KairoSkillBackendService(agentSkillManagerService: nil),
            settings: KairoSettingsBackendService(
                openAISettingsService: OpenAISettingsService(credentialStore: InMemoryCredentialStore()),
                oauthLoginCenter: OAuthConnectorLoginCenter(credentialStore: InMemoryCredentialStore())
            ),
            access: KairoAccessBackendService(permissionService: StubPermissionService())
        )

        XCTAssertEqual(api.moduleRegistry, KairoBackendModuleRegistry.production)
    }

    func testBackendModuleComposerMountsModulesFromDependencyContainer() async throws {
        let skillManagerService = try await makeBackendTestAgentSkillManagerService()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            chatHistoryStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            kairoRecipeStore: InMemoryKairoRecipeStore(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger(),
            agentSkillManagerService: skillManagerService
        )
        let registry = KairoBackendModuleRegistry(modules: [
            KairoBackendModuleDescriptor(
                id: .chat,
                displayName: "Mounted Chat",
                boundarySummary: "Test-only backend module registry."
            )
        ])

        let api = KairoBackendModuleComposer(dependencies: environment)
            .makeBackendAPI(moduleRegistry: registry)

        XCTAssertEqual(api.moduleRegistry, registry)
        let response = try await api.chat.respond(to: "compose", attachments: [], privacyMode: .standard)
        XCTAssertEqual(response.message, "Composer response")
        _ = try await api.skills.catalog()

        do {
            _ = try await api.localModels.status()
            XCTFail("Expected unmounted local model service to fail closed.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    func testBackendModuleComposerUsesEnvironmentOAuthClientConfigurations() async throws {
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            oauthClientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ]
        )

        let options = try await environment.backendAPI.settings.oauthLoginOptions()
        let chatGPT = try XCTUnwrap(options.first { $0.providerKey == "chatgpt" })

        XCTAssertEqual(chatGPT.readiness, .readyToAuthorize)
        XCTAssertTrue(chatGPT.canStartAuthorization)
    }

    func testKairoEnvironmentBuildsSettingsFeatureDependenciesForCompositionRoot() async throws {
        let credentialStore = InMemoryCredentialStore()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            oauthClientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ]
        )

        let dependencies = environment.settingsFeatureDependencies

        try await dependencies.settingsService.saveAPIKey("openai-test-key")
        let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertEqual(savedKey, "openai-test-key")
        XCTAssertEqual(dependencies.oauthClientConfigurations["chatgpt"]?.clientID, "chatgpt-client")
        XCTAssertNotNil(dependencies.deletionAPI)
    }

    @MainActor
    func testKairoEnvironmentBuildsChatFeatureDependenciesForCompositionRoot() async throws {
        let chatHistoryStore = InMemoryChatHistoryStore()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            chatHistoryStore: chatHistoryStore
        )
        let dependencies = environment.chatFeatureDependencies
        let thread = ChatThread(messages: [
            ChatMessage(role: .user, text: "Saved thread")
        ])

        try await chatHistoryStore.saveThread(thread)
        let viewModel = ChatViewModel(dependencies: dependencies)
        await viewModel.load()
        await viewModel.send("compose")

        XCTAssertEqual(viewModel.threads.first?.id, thread.id)
        XCTAssertEqual(viewModel.currentThread.messages.last?.text, "Composer response")
    }

    func testKairoEnvironmentBuildsMemoryFeatureDependenciesForCompositionRoot() async throws {
        let memoryStore = InMemoryMemoryStore()
        let environment = KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response"))
        )
        let dependencies = environment.memoryFeatureDependencies
        let memory = MemoryRecord(
            title: "Composition",
            summary: "Memory feature dependency wiring",
            content: "Memory feature composition",
            source: .manual
        )

        try await dependencies.memoryAPI.save(memory)
        let saved = try await memoryStore.list(limit: 10)

        XCTAssertEqual(saved.map(\.id), [memory.id])
    }

}
