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

    func testProductionBackendServiceFactoryBuildsServicesFromInjectedDependencies() async throws {
        let memoryStore = InMemoryMemoryStore()
        let environment = KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response"))
        )
        let factory = ProductionKairoBackendServiceFactory(dependencies: environment)
        let memory = MemoryRecord(
            title: "Factory memory",
            summary: "Created through factory-built memory API",
            content: "Factory dependency wiring",
            source: .manual
        )

        try await factory.makeMemoryAPI().save(memory)
        let saved = try await memoryStore.list(limit: 10)
        let response = try await factory.makeChatAPI().respond(
            to: "factory",
            attachments: [],
            privacyMode: .standard
        )

        XCTAssertEqual(saved.map(\.id), [memory.id])
        XCTAssertEqual(response.message, "Factory response")
    }

    func testBackendCompositionSharesInjectedPhoneToolCatalogAcrossAccessAndChat() async throws {
        let calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        let toolCatalog = BuiltInPhoneToolCatalog(tools: [calendarTool])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            toolCatalog: toolCatalog
        )

        let accessTools = await environment.backendAPI.access.tools()
        let chatResponse = try await environment.backendAPI.chat.respond(
            to: "建立行程：週五 10:00 Kairo roadmap review",
            attachments: [],
            privacyMode: .standard
        )

        XCTAssertEqual(accessTools.map(\.toolID), [.calendarWrite])
        XCTAssertEqual(chatResponse.proposedActions.map(\.kind), [.createCalendarDraft])
    }

    func testKairoEnvironmentExposesDefaultAppIntegrationSkillCatalogForCompositionRoot() throws {
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response"))
        )

        XCTAssertNotNil(environment.appIntegrationSkillCatalog.skill(id: .appleMailHandoff))
        XCTAssertNotNil(environment.appIntegrationSkillCatalog.skill(id: .googleMapsDirectionsHandoff))
        XCTAssertFalse(environment.appIntegrationSkillCatalog.executableSkills.contains { $0.id == .gmailDraftAPI })
    }

    func testKairoEnvironmentAcceptsInjectedAppIntegrationSkillCatalog() throws {
        let injectedCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .appleMessagesHandoff))
        ])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            appIntegrationSkillCatalog: injectedCatalog
        )

        XCTAssertEqual(environment.appIntegrationSkillCatalog.skills.map(\.id), [.appleMessagesHandoff])
        XCTAssertNil(environment.appIntegrationSkillCatalog.skill(id: .appleMailHandoff))
    }

    func testBackendCompositionSharesInjectedAppIntegrationSkillCatalogWithChat() async throws {
        let injectedCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .whatsappMessageHandoff))
        ])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            appIntegrationSkillCatalog: injectedCatalog
        )

        let response = try await environment.backendAPI.chat.respond(
            to: "Send this update with WhatsApp",
            attachments: [],
            privacyMode: .standard
        )

        let candidate = try XCTUnwrap(response.toolCandidates.first { $0.integrationKey == "whatsapp" })
        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertNil(candidate.action)
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

    func testBackendModuleComposerUsesEnvironmentOAuthConnectorRegistry() async throws {
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            oauthClientConfigurations: [
                "custom-mail": OAuthConnectorClientConfiguration(
                    clientID: "custom-client",
                    redirectURI: "kairo://oauth/custom-mail/callback"
                ),
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        )

        let options = try await environment.backendAPI.settings.oauthLoginOptions()

        XCTAssertEqual(options.map(\.integrationKey), ["custom-mail"])
        XCTAssertEqual(options.first?.readiness, .readyToAuthorize)
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

    func testKairoEnvironmentBuildsAutomationsFeatureDependenciesForCompositionRoot() async throws {
        let recipeStore = InMemoryKairoRecipeStore()
        let memoryStore = InMemoryMemoryStore()
        let environment = KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            kairoRecipeStore: recipeStore
        )
        let dependencies = environment.automationsFeatureDependencies
        let recipe = KairoRecipe(
            id: "composition-recipe",
            title: "Composition Recipe",
            summary: "Recipe feature dependency wiring",
            steps: [
                KairoRecipeStep(
                    id: "noop",
                    title: "No operation",
                    kind: .noOp,
                    input: .literal("composition")
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )

        try await dependencies.recipeAPI.save(recipe)
        let saved = try await recipeStore.listRecipes()

        XCTAssertEqual(saved.map(\.id), ["composition-recipe"])

        let demoRecipe = try XCTUnwrap(ShortcutDemoCatalog.default.recipe(id: "save-shared-text"))
        let demoRun = try await dependencies.shortcutDemoRecipeRunner.runSample(demoRecipe)
        let memories = try await memoryStore.list(limit: 10)

        XCTAssertEqual(demoRun.recipeID, demoRecipe.id)
        XCTAssertEqual(demoRun.steps.map(\.nodeKind), [.saveMemory, .extractTasks])
        XCTAssertEqual(memories.count, 1)
    }

    func testKairoEnvironmentBuildsAccessFeatureDependenciesForCompositionRoot() async throws {
        let skillManagerService = try await makeBackendTestAgentSkillManagerService()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            agentSkillManagerService: skillManagerService
        )

        let dependencies = environment.accessFeatureDependencies
        let catalog = try await XCTUnwrap(dependencies.skillManagerService).catalog()
        let accessAPI = try XCTUnwrap(dependencies.accessAPI)
        let tools = await accessAPI.tools()
        let integrations = await accessAPI.appIntegrations()

        XCTAssertFalse(catalog.skills.isEmpty)
        XCTAssertTrue(tools.contains { $0.toolID == .reminderWrite })
        XCTAssertTrue(integrations.contains { $0.skillID == .googleMapsDirectionsHandoff })
        XCTAssertNil(dependencies.marketplaceCatalogService)
    }

    func testKairoEnvironmentBuildsRootOpenURLHandlerForOAuthCallbacks() async throws {
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: temporaryBackendTestFileURL(named: "oauth-callback-previews.json")
        )
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            oauthConnectorCallbackStore: callbackStore,
            oauthClientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        )

        let openURLHandler = try XCTUnwrap(environment.rootFeatureDependencies.openURLHandler)
        try await openURLHandler.handle(
            URL(string: "kairo://oauth/google/callback?code=sample-code&state=state-123")!
        )
        let storedPreview = await callbackStore.latestPreview(for: "google")
        let preview = try XCTUnwrap(storedPreview)

        XCTAssertEqual(preview.providerKey, "google")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-code".count)
    }

    private func backendTestOAuthIntegration(key: String, displayName: String, providerKey: String) -> AppIntegration {
        AppIntegration(
            key: key,
            displayName: displayName,
            category: .communication,
            surfaces: [.oauthAPI],
            requiredCapabilities: [.externalConnectors],
            oauth: OAuthConnectorMetadata(
                providerKey: providerKey,
                authorizationEndpoint: URL(string: "https://example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://example.com/oauth/token")!,
                defaultScopes: ["read"],
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Test connector scopes only."
            ),
            sandboxNotes: "Test connector.",
            status: .requiresBackend
        )
    }
}
