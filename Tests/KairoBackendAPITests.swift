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

    func testChatBackendServiceFactoryBuildsAgentDependencyBundle() async throws {
        let memory = MemoryRecord(
            title: "Factory agent memory",
            summary: "Dependency bundle memory",
            content: "Factory-built agent dependencies should use the injected memory store.",
            source: .manual
        )
        let memoryStore = InMemoryMemoryStore(seed: [memory])
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Agent bundle response"))
        let environment = KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: provider
        )
        let dependencies = KairoChatBackendServiceFactory(dependencies: environment)
            .makeAgentCoreDependencies()
        let agent = AgentCore(dependencies: dependencies)

        let response = try await agent.respond(to: "Factory agent memory")
        let captured = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(captured)

        XCTAssertEqual(response.message, "Agent bundle response")
        XCTAssertEqual(capturedRequest.memoryContext.map(\.id), [memory.id])
    }

    func testRecipeBackendServiceFactoryBuildsRunnerDependencyBundle() async throws {
        let recipe = KairoRecipe(
            id: "factory-ask-recipe",
            title: "Factory Ask Recipe",
            summary: "Checks recipe runner dependency composition.",
            steps: [
                KairoRecipeStep(
                    id: "ask",
                    title: "Ask",
                    kind: .askKairo,
                    input: .literal("Use injected provider")
                )
            ],
            requiredCapabilities: [],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let recipeStore = InMemoryKairoRecipeStore(recipes: [recipe])
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Recipe bundle response"))
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: provider,
            kairoRecipeStore: recipeStore
        )
        let dependencies = KairoRecipeBackendServiceFactory(dependencies: environment)
            .makeRecipeRunnerDependencies()
        let api = KairoRecipeBackendService(dependencies: dependencies)

        let result = try await api.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))
        let captured = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(captured)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepResults.first?.outputText, "Recipe bundle response")
        XCTAssertEqual(capturedRequest.userPrompt, "Use injected provider")
    }

    func testSettingsBackendServiceFactoryBuildsSettingsAPIFromInjectedDependencies() async throws {
        let credentialStore = InMemoryCredentialStore()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            oauthClientConfigurations: [
                "custom-mail": OAuthConnectorClientConfiguration(
                    clientID: "custom-client",
                    redirectURI: "kairo://oauth/custom-mail/callback"
                )
            ]
        )
        let settingsAPI = KairoSettingsBackendServiceFactory(dependencies: environment).makeSettingsAPI()

        try await settingsAPI.saveOpenAIAPIKey("settings-factory-key")
        let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let options = try await settingsAPI.oauthLoginOptions()

        XCTAssertEqual(savedKey, "settings-factory-key")
        XCTAssertEqual(options.map(\.integrationKey), ["custom-mail"])
        XCTAssertEqual(options.first?.readiness, .readyToAuthorize)
    }

    func testAccessBackendServiceFactoryBuildsAccessAPIFromInjectedDependencies() async throws {
        let toolCatalog = BuiltInPhoneToolCatalog(tools: [
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        ])
        let appIntegrationSkillCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .googleMapsDirectionsHandoff))
        ])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            permissionService: StubPermissionService(),
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
        let accessAPI = KairoAccessBackendServiceFactory(dependencies: environment).makeAccessAPI()

        let tools = await accessAPI.tools()
        let integrations = await accessAPI.appIntegrations()

        XCTAssertEqual(tools.map(\.toolID), [.calendarWrite])
        XCTAssertEqual(tools.first?.readiness, .needsPermission)
        XCTAssertEqual(integrations.map(\.skillID), [.googleMapsDirectionsHandoff])
        XCTAssertEqual(integrations.first?.readiness, .available)
    }

    func testChatBackendServiceFactoryBuildsChatAPIFromInjectedDependencies() async throws {
        let calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        let toolCatalog = BuiltInPhoneToolCatalog(tools: [calendarTool])
        let appIntegrationSkillCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .whatsappMessageHandoff))
        ])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
        let chatAPI = KairoChatBackendServiceFactory(dependencies: environment).makeChatAPI()

        let calendarResponse = try await chatAPI.respond(
            to: "建立行程：週五 10:00 Kairo roadmap review",
            attachments: [],
            privacyMode: .standard
        )
        let handoffResponse = try await chatAPI.respond(
            to: "Send this update with WhatsApp",
            attachments: [],
            privacyMode: .standard
        )

        XCTAssertEqual(calendarResponse.proposedActions.map(\.kind), [.createCalendarDraft])
        let candidate = try XCTUnwrap(handoffResponse.toolCandidates.first { $0.integrationKey == "whatsapp" })
        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertNil(candidate.action)
    }

    func testRecipeBackendServiceFactoryBuildsRecipeAPIFromInjectedDependencies() async throws {
        let recipeStore = InMemoryKairoRecipeStore()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            kairoRecipeStore: recipeStore
        )
        let recipeAPI = KairoRecipeBackendServiceFactory(dependencies: environment).makeRecipeAPI()
        let recipe = KairoRecipe(
            id: "factory-noop-recipe",
            title: "Factory Noop Recipe",
            summary: "Recipe backend factory wiring.",
            steps: [
                KairoRecipeStep(
                    id: "noop",
                    title: "No operation",
                    kind: .noOp,
                    input: .literal("factory")
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )

        try await recipeAPI.save(recipe)
        let savedRecipes = try await recipeStore.listRecipes()
        let result = try await recipeAPI.run(KairoRecipeRunRequest(
            recipeID: "factory-noop-recipe",
            surface: .appIntent,
            input: nil,
            dryRun: true,
            userConfirmed: false
        ))

        XCTAssertEqual(savedRecipes.map(\.id), ["factory-noop-recipe"])
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.recipeID, "factory-noop-recipe")
    }

    func testShareImportBackendServiceFactoryBuildsShareImportAPIFromInjectedDependencies() async throws {
        let rootDirectory = temporaryDirectory(named: "KairoShareImportFactory")
        let sharedFilesDirectory = rootDirectory.appendingPathComponent("SharedFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedFilesDirectory, withIntermediateDirectories: true)
        let copiedFileURL = sharedFilesDirectory.appendingPathComponent("factory-share.txt")
        let externalFileURL = rootDirectory.appendingPathComponent("external-share.txt")
        try Data("copied share".utf8).write(to: copiedFileURL)
        try Data("external share".utf8).write(to: externalFileURL)
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.file(
                    url: copiedFileURL,
                    displayName: "factory-share.txt",
                    uniformTypeIdentifier: "public.plain-text",
                    byteCount: 12
                ),
                builder.file(
                    url: externalFileURL,
                    displayName: "external-share.txt",
                    uniformTypeIdentifier: "public.plain-text",
                    byteCount: 14
                )
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            shareIngestionQueue: queue,
            sharedFilesDirectory: sharedFilesDirectory
        )
        let shareImportAPI = KairoShareImportBackendServiceFactory(dependencies: environment).makeShareImportAPI()

        let imported = try await shareImportAPI.importPendingShares(limit: 10)
        XCTAssertEqual(imported.importedItemIDs, [item.id])

        try await shareImportAPI.clearImportedShares(
            ids: imported.importedItemIDs,
            attachments: imported.attachments
        )
        let remaining = try await queue.pendingItems(limit: 10)

        XCTAssertTrue(remaining.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: copiedFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFileURL.path))
    }

    func testActionBackendServiceFactoryBuildsActionAPIFromInjectedDependencies() async throws {
        let actionExecutor = AllowingBackendActionExecutor()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            actionExecutor: actionExecutor
        )
        let actionAPI = KairoActionBackendServiceFactory(dependencies: environment).makeActionAPI()
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User confirmed a reminder preview.",
            payload: .reminder(ReminderDraft(
                title: "Review factory wiring",
                notes: nil,
                dueDate: nil
            )),
            riskTier: .tier2LowRiskWrite
        )

        let preview = await actionAPI.preview(action)
        let result = try await actionAPI.confirm(action)
        let executedKinds = await actionExecutor.executedKinds()
        let confirmations = await actionExecutor.confirmations()

        XCTAssertTrue(preview.decision.requiresConfirmation)
        XCTAssertTrue(result.completed)
        XCTAssertEqual(executedKinds, [.createReminderDraft])
        XCTAssertEqual(confirmations, [true])
    }

    func testDeletionBackendServiceFactoryBuildsDeletionAPIFromInjectedDependencies() async throws {
        let threadID = UUID(uuidString: "66666666-6666-6666-6666-666666666666")!
        let memoryID = UUID(uuidString: "77777777-7777-7777-7777-777777777777")!
        let chatHistoryStore = InMemoryChatHistoryStore(seed: [
            ChatThread(id: threadID, messages: [
                ChatMessage(role: .user, text: "Factory delete thread")
            ])
        ])
        let memoryStore = InMemoryMemoryStore(seed: [
            MemoryRecord(
                id: memoryID,
                title: "Factory memory",
                summary: "Deletion backend factory wiring.",
                content: "Factory deletion content",
                source: .manual
            )
        ])
        let credentialStore = InMemoryCredentialStore()
        let auditLogger = InMemoryAuditLogger()
        let environment = KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            chatHistoryStore: chatHistoryStore,
            auditLogger: auditLogger
        )
        let deletionAPI = KairoDeletionBackendServiceFactory(dependencies: environment).makeDeletionAPI()

        try await credentialStore.saveSecret("factory-openai-key", for: CredentialKey.openAIAPIKey)
        try await auditLogger.record(AuditEvent(
            actionKind: .saveMemory,
            memoryIDs: [memoryID],
            capabilityKeys: [.memory],
            usedCloudModel: false,
            requiredConfirmation: true,
            userConfirmed: true,
            result: .completed
        ))
        try await deletionAPI.deleteChatThread(id: threadID)
        try await deletionAPI.purgeDeletedChatThreads()
        try await deletionAPI.deleteMemory(id: memoryID)
        try await deletionAPI.purgeDeletedMemories()
        try await deletionAPI.deleteOpenAIAPIKey()
        try await deletionAPI.clearAuditLog()

        let deletedThread = try await chatHistoryStore.thread(id: threadID)
        let memories = try await memoryStore.list(limit: 10)
        let openAIAPIKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertNil(deletedThread)
        XCTAssertTrue(memories.isEmpty)
        XCTAssertNil(openAIAPIKey)
        XCTAssertTrue(auditEvents.isEmpty)
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

    func testKairoEnvironmentDefaultsIntegrationRegistryFromInjectedAppIntegrationSkillCatalog() throws {
        let injectedCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .todoistTaskAPI))
        ])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            appIntegrationSkillCatalog: injectedCatalog
        )

        let todoist = try XCTUnwrap(environment.oauthConnectorRegistry.integration(for: "todoist"))
        XCTAssertEqual(todoist.oauth?.providerKey, "todoist")
        XCTAssertEqual(environment.oauthConnectorRegistry.integrations.filter { $0.key == "todoist" }.count, 1)
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

    func testBackendCompositionSharesInjectedIntegrationRegistryWithChatFallbackCandidates() async throws {
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )

        let response = try await environment.backendAPI.chat.respond(
            to: "Open Custom Mail for this account",
            attachments: [],
            privacyMode: .standard
        )

        let candidate = try XCTUnwrap(response.toolCandidates.first { $0.integrationKey == "custom-mail" })
        XCTAssertEqual(candidate.source, .integrationRegistry)
        XCTAssertNil(candidate.action)
    }

    func testChatBackendFactoryBuildsCandidatePlanningBundleFromEnvironmentIntegrations() throws {
        let injectedCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .whatsappMessageHandoff))
        ])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory response")),
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            appIntegrationSkillCatalog: injectedCatalog
        )
        let candidatePlanning = KairoChatBackendServiceFactory(dependencies: environment)
            .makeToolCandidatePlanningDependencies()
        let planner = AgentToolInvocationPlanner(
            skillCatalog: AgentSkillCatalog(skills: []),
            dependencies: AgentToolInvocationPlannerDependencies(candidatePlanning: candidatePlanning)
        )

        let whatsappPlan = planner.plan(for: AgentToolInvocationRequest(userText: "Send with WhatsApp"))
        let registryPlan = planner.plan(for: AgentToolInvocationRequest(userText: "Open Custom Mail"))

        let whatsappCandidate = try XCTUnwrap(whatsappPlan.candidates.first { $0.integrationKey == "whatsapp" })
        let registryCandidate = try XCTUnwrap(registryPlan.candidates.first { $0.integrationKey == "custom-mail" })
        XCTAssertEqual(whatsappCandidate.source, .appIntegrationCatalog)
        XCTAssertEqual(registryCandidate.source, .integrationRegistry)
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
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            oauthClientConfigurations: [
                "custom-mail": OAuthConnectorClientConfiguration(
                    clientID: "custom-client",
                    redirectURI: "kairo://oauth/custom-mail/callback"
                )
            ]
        )

        let dependencies = environment.settingsFeatureDependencies

        try await dependencies.settingsService.saveAPIKey("openai-test-key")
        let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertEqual(savedKey, "openai-test-key")
        XCTAssertEqual(dependencies.oauthClientConfigurations["custom-mail"]?.clientID, "custom-client")
        XCTAssertEqual(dependencies.oauthConnectorRegistry.oauthConnectors.map(\.key), ["custom-mail"])
        XCTAssertNotNil(dependencies.deletionAPI)
    }

    func testSettingsFeatureDependencyFactoryWiresCredentialStoreAndOAuthBoundary() async throws {
        let credentialStore = InMemoryCredentialStore()
        let dependencies = SettingsFeatureDependencyFactory().makeDependencies(
            credentialStore: credentialStore,
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            oauthClientConfigurations: [
                "custom-mail": OAuthConnectorClientConfiguration(
                    clientID: "custom-client",
                    redirectURI: "kairo://oauth/custom-mail/callback"
                )
            ],
            oauthWebAuthenticationRunner: nil
        )

        try await dependencies.openAIKeyCoordinator.saveAPIKey("openai-test-key")
        let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let loginOptions = try await dependencies.oauthCoordinator.loginOptions()

        XCTAssertEqual(savedKey, "openai-test-key")
        XCTAssertEqual(dependencies.oauthConnectorRegistry.oauthConnectors.map(\.key), ["custom-mail"])
        XCTAssertEqual(dependencies.oauthClientConfigurations["custom-mail"]?.clientID, "custom-client")
        XCTAssertNil(dependencies.oauthWebAuthenticationRunner)
        XCTAssertEqual(loginOptions.map(\.providerKey), ["custom-mail"])
        XCTAssertEqual(loginOptions.map(\.readiness), [.readyToAuthorize])
    }

    func testSettingsFeatureDependencyFactoryDefaultsToHarnessOAuthRegistry() throws {
        let dependencies = SettingsFeatureDependencyFactory().makeDependencies(
            credentialStore: InMemoryCredentialStore(),
            oauthWebAuthenticationRunner: nil
        )

        let gmail = try XCTUnwrap(dependencies.oauthConnectorRegistry.integration(for: "gmail-google-workspace"))
        let notion = try XCTUnwrap(dependencies.oauthConnectorRegistry.integration(for: "notion"))
        let todoist = try XCTUnwrap(dependencies.oauthConnectorRegistry.integration(for: "todoist"))
        let github = try XCTUnwrap(dependencies.oauthConnectorRegistry.integration(for: "github"))

        XCTAssertEqual(gmail.oauth?.providerKey, "google")
        XCTAssertEqual(notion.oauth?.providerKey, "notion")
        XCTAssertEqual(todoist.oauth?.providerKey, "todoist")
        XCTAssertEqual(github.oauth?.providerKey, "github")
    }

    func testSettingsFeatureDependencyFactoryOwnsDefaultCredentialAndOAuthComposition() async throws {
        let dependencies = SettingsFeatureDependencyFactory().makeDependencies(
            oauthWebAuthenticationRunner: nil
        )

        try await dependencies.settingsService.saveAPIKey("factory-default-openai-key")
        let savedKey = try await dependencies.credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let todoist = try XCTUnwrap(dependencies.oauthConnectorRegistry.integration(for: "todoist"))

        XCTAssertEqual(savedKey, "factory-default-openai-key")
        XCTAssertEqual(todoist.oauth?.providerKey, "todoist")
        XCTAssertNil(dependencies.oauthWebAuthenticationRunner)
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

    func testChatFeatureDependencyFactoryWiresCredentialStoreAndRuntimeBoundaries() async throws {
        let credentialStore = InMemoryCredentialStore()
        let historyStore = InMemoryChatHistoryStore()
        let dependencies = ChatFeatureDependencyFactory().makeDependencies(
            historyStore: historyStore,
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            credentialStore: credentialStore,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(
                    memoryStore: InMemoryMemoryStore(),
                    aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Factory chat"))
                )
            ),
            shareImportAPI: KairoShareImportBackendService(shareIngestionQueue: InMemoryShareIngestionQueue()),
            actionAPI: KairoActionBackendService(actionExecutor: AllowingBackendActionExecutor()),
            actionExecutor: AllowingBackendActionExecutor(),
            localModelSettingsService: nil,
            localModelChatRuntimeAvailable: true
        )

        try await dependencies.openAISettingsService?.saveAPIKey("openai-chat-factory-key")
        let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let response = try await dependencies.chatAPI.respond(
            to: "factory",
            attachments: [],
            privacyMode: .standard
        )
        let thread = ChatThread(messages: [
            ChatMessage(role: .user, text: "Factory thread")
        ])
        try await dependencies.historyStore.saveThread(thread)
        let savedThreads = try await historyStore.listThreads(limit: 10)

        XCTAssertEqual(savedThreads.map(\.id), [thread.id])
        XCTAssertEqual(savedKey, "openai-chat-factory-key")
        XCTAssertEqual(response.message, "Factory chat")
        XCTAssertTrue(dependencies.localModelChatRuntimeAvailable)
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

    func testMemoryFeatureDependencyFactoryWiresMemoryAPI() async throws {
        let memoryStore = InMemoryMemoryStore()
        let dependencies = MemoryFeatureDependencyFactory().makeDependencies(
            memoryAPI: KairoMemoryBackendService(memoryStore: memoryStore)
        )
        let memory = MemoryRecord(
            title: "Factory memory",
            summary: "Created through memory factory.",
            content: "Memory dependency factory wiring",
            source: .manual
        )

        try await dependencies.memoryAPI.save(memory)
        let searchResults = try await dependencies.memoryAPI.search(query: "factory", limit: 10)
        let export = try await dependencies.memoryAPI.export(limit: 10)

        XCTAssertEqual(searchResults.map(\.id), [memory.id])
        XCTAssertEqual(export.records.map(\.id), [memory.id])
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

    func testKairoEnvironmentUsesInjectedShortcutDemoRecipeRunnerForAutomations() async throws {
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            shortcutDemoRecipeRunner: FixedShortcutDemoRecipeRunner()
        )

        let demoRecipe = try XCTUnwrap(ShortcutDemoCatalog.default.recipe(id: "daily-briefing"))
        let demoRun = try await environment.automationsFeatureDependencies.shortcutDemoRecipeRunner.runSample(demoRecipe)

        XCTAssertEqual(demoRun.recipeID, "injected-runner")
        XCTAssertTrue(demoRun.steps.isEmpty)
    }

    func testAutomationsFeatureDependencyFactoryWiresRecipeAPIAndShortcutDemoRunner() async throws {
        let recipeStore = InMemoryKairoRecipeStore()
        let memoryStore = InMemoryMemoryStore()
        let dependencies = AutomationsFeatureDependencyFactory().makeDependencies(
            recipeStore: recipeStore,
            memoryStore: memoryStore
        )
        let recipe = KairoRecipe(
            id: "factory-recipe",
            title: "Factory Recipe",
            summary: "Factory dependency wiring",
            steps: [
                KairoRecipeStep(
                    id: "noop",
                    title: "No operation",
                    kind: .noOp,
                    input: .literal("factory")
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )

        try await dependencies.recipeAPI.save(recipe)
        let demoRecipe = try XCTUnwrap(ShortcutDemoCatalog.default.recipe(id: "save-shared-text"))
        _ = try await dependencies.shortcutDemoRecipeRunner.runSample(demoRecipe)
        let savedRecipes = try await recipeStore.listRecipes()
        let memories = try await memoryStore.list(limit: 10)

        XCTAssertEqual(savedRecipes.map(\.id), ["factory-recipe"])
        XCTAssertEqual(memories.count, 1)
    }

    #if canImport(SwiftUI)
    func testAutomationsViewLeavesDefaultStoreAndCatalogCompositionToDependencyComposer() throws {
        let composer = RecordingAutomationsFeatureDependencyComposer()
        _ = AutomationsView(dependencyComposer: composer)

        XCTAssertEqual(composer.receivedNilRecipeStore, true)
        XCTAssertEqual(composer.receivedNilToolCatalog, true)
        XCTAssertEqual(composer.receivedNilAppIntegrationSkillCatalog, true)
    }
    #endif

    func testAutomationsFeatureDependencyComposerCanInjectIntegrationCatalogBoundary() async throws {
        let composer: any AutomationsFeatureDependencyComposing = AutomationsFeatureDependencyFactory()
        let recipe = KairoRecipe(
            id: "automations-composer-catalog-gate",
            title: "Automations Composer Catalog Gate",
            summary: "Automations feature composition must not bypass injected integration catalog.",
            steps: [
                KairoRecipeStep(
                    id: "mail",
                    title: "Prepare Mail Handoff",
                    kind: .enqueueActionDraft,
                    input: .literal("Draft an email to alex@example.com"),
                    integrationSkillID: .appleMailHandoff
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let dependencies = composer.makeDependencies(
            recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]),
            memoryStore: InMemoryMemoryStore(),
            aiProvider: nil,
            toolCatalog: BuiltInPhoneToolCatalog(),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )

        let result = try await dependencies.recipeAPI.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.proposedActions.isEmpty)
        XCTAssertFalse(result.stepResults.first?.success ?? true)
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

    func testAccessFeatureDependencyFactoryWiresAccessAndSkillBoundaries() async throws {
        let accessAPI = KairoAccessBackendService(permissionService: StubPermissionService())
        let skillManagerService = try await makeBackendTestAgentSkillManagerService()
        let marketplaceCatalogService = try KairoUITestingSkillFactory.marketplaceCatalogService()
        let initialCatalog = AgentSkillCatalog(skills: [
            AgentSkill.marketplaceTemplate(
                id: "factory-skill",
                displayName: "Factory Skill",
                summary: "Factory wiring skill.",
                requiredCapabilities: [.appIntents],
                downloadURL: URL(string: "https://example.com/factory-skill.json")!
            )
        ])

        let dependencies = AccessFeatureDependencyFactory().makeDependencies(
            accessAPI: accessAPI,
            skillManagerService: skillManagerService,
            marketplaceCatalogService: marketplaceCatalogService,
            initialSkillCatalog: initialCatalog
        )

        let injectedAccessAPI = try XCTUnwrap(dependencies.accessAPI)
        let injectedSkillManagerService = try XCTUnwrap(dependencies.skillManagerService)
        let injectedMarketplaceCatalogService = try XCTUnwrap(dependencies.marketplaceCatalogService)
        let tools = await injectedAccessAPI.tools()
        let skillCatalog = try await injectedSkillManagerService.catalog()
        let remoteCatalog = try await injectedMarketplaceCatalogService.fetchCatalog()

        XCTAssertTrue(tools.contains { $0.toolID == .reminderWrite })
        XCTAssertFalse(skillCatalog.skills.isEmpty)
        XCTAssertEqual(dependencies.initialSkillCatalog.skills.map(\.id), ["factory-skill"])
        XCTAssertEqual(remoteCatalog.catalog.skills.map(\.id), [
            "marketplace-weather-briefing",
            "marketplace-qwen-oauth-workflow"
        ])
    }

    func testAccessFeatureDependencyFactoryCarriesInjectedCapabilityRegistry() {
        let registry = CapabilityRegistry(capabilities: [
            Capability(
                key: .memory,
                displayName: "Injected Memory",
                description: "Injected capability registry entry.",
                permission: .none,
                status: .available,
                isMVP: true
            )
        ])
        let dependencies = AccessFeatureDependencyFactory().makeDependencies(
            capabilityRegistry: registry
        )

        XCTAssertEqual(dependencies.capabilityRegistry.capabilities, registry.capabilities)
    }

    func testKairoEnvironmentBuildsRootOpenURLHandlerForOAuthCallbacks() async throws {
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: temporaryBackendTestFileURL(named: "oauth-callback-previews.json")
        )
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Composer response")),
            oauthConnectorRegistry: IntegrationRegistry(integrations: [
                backendTestOAuthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
            ]),
            oauthConnectorCallbackStore: callbackStore,
            oauthClientConfigurations: [
                "custom-mail": OAuthConnectorClientConfiguration(
                    clientID: "custom-client",
                    redirectURI: "kairo://oauth/custom-mail/callback"
                )
            ]
        )

        let openURLHandler = try XCTUnwrap(environment.rootFeatureDependencies.openURLHandler)
        try await openURLHandler.handle(
            URL(string: "kairo://oauth/custom-mail/callback?code=sample-code&state=state-123")!
        )
        let storedPreview = await callbackStore.latestPreview(for: "custom-mail")
        let preview = try XCTUnwrap(storedPreview)

        XCTAssertEqual(preview.providerKey, "custom-mail")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-code".count)
    }

    func testRootFeatureDependencyFactoryDefaultsToHarnessOAuthRegistryForCallbacks() async throws {
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: temporaryBackendTestFileURL(named: "factory-default-oauth-callback-previews.json")
        )
        let dependencies = RootFeatureDependencyFactory().makeDependencies(
            oauthConnectorCallbackStore: callbackStore,
            credentialStore: InMemoryCredentialStore()
        )

        let openURLHandler = try XCTUnwrap(dependencies.openURLHandler)
        try await openURLHandler.handle(
            URL(string: "kairo://oauth/todoist/callback?code=sample-code&state=state-123")!
        )
        let storedPreview = await callbackStore.latestPreview(for: "todoist")
        let preview = try XCTUnwrap(storedPreview)

        XCTAssertEqual(preview.integrationKey, "todoist")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-code".count)
    }

    func testRootFeatureDependencyFactoryUsesInjectedOAuthLoginServiceForCallbacks() async throws {
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: temporaryBackendTestFileURL(named: "factory-oauth-callback-previews.json")
        )
        let loginService = CapturingOAuthLoginService()
        let dependencies = RootFeatureDependencyFactory().makeDependencies(
            oauthConnectorCallbackStore: callbackStore,
            credentialStore: InMemoryCredentialStore(),
            oauthLoginService: loginService
        )

        let callbackURL = URL(string: "kairo://oauth/custom-mail/callback?code=sample-code&state=state-123")!
        let openURLHandler = try XCTUnwrap(dependencies.openURLHandler)
        try await openURLHandler.handle(callbackURL)

        let handledURLs = await loginService.handledCallbackURLs()
        XCTAssertEqual(handledURLs, [callbackURL])
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

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    }
}

private actor CapturingOAuthLoginService: OAuthConnectorLoginServicing {
    private var callbackURLs: [URL] = []

    func handledCallbackURLs() -> [URL] {
        callbackURLs
    }

    func loginOptions() async throws -> [OAuthConnectorLoginOption] {
        []
    }

    func makeAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession {
        throw OAuthConnectorLoginCenterError.missingIntegration(integrationKey)
    }

    func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        callbackURLs.append(callbackURL)
        return OAuthConnectorCallbackPreview(
            providerKey: "captured",
            integrationKey: "captured",
            state: nil,
            authorizationCodeLength: 0,
            receivedAt: Date(timeIntervalSince1970: 0),
            requiresBackendTokenExchange: true
        )
    }

    func exchangeCallback(
        _ callbackURL: URL,
        expectedState: String,
        codeVerifier: String?
    ) async throws -> OAuthTokenSet {
        throw OAuthConnectorLoginCenterError.missingIntegration(callbackURL.absoluteString)
    }

    func disconnect(providerKey: String) async throws {}
}

private struct FixedShortcutDemoRecipeRunner: ShortcutDemoRecipeRunnerProtocol {
    func runSample(_ recipe: ShortcutDemoRecipe) async throws -> ShortcutDemoRecipeRun {
        ShortcutDemoRecipeRun(
            recipeID: "injected-runner",
            recipeTitle: recipe.title,
            displaySummary: "Injected runner.",
            steps: []
        )
    }
}

#if canImport(SwiftUI)
private final class RecordingAutomationsFeatureDependencyComposer: AutomationsFeatureDependencyComposing, @unchecked Sendable {
    private(set) var receivedNilRecipeStore: Bool?
    private(set) var receivedNilToolCatalog: Bool?
    private(set) var receivedNilAppIntegrationSkillCatalog: Bool?

    func makeDependencies(
        recipeStore: (any KairoRecipeStore)?,
        memoryStore: (any MemoryStore)?,
        aiProvider: (any AIProvider)?,
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)?,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)?
    ) -> AutomationsFeatureDependencies {
        receivedNilRecipeStore = recipeStore == nil
        receivedNilToolCatalog = toolCatalog == nil
        receivedNilAppIntegrationSkillCatalog = appIntegrationSkillCatalog == nil
        return AutomationsFeatureDependencies(
            recipeAPI: EmptyRecipeAPI(),
            shortcutDemoRecipeRunner: FixedShortcutDemoRecipeRunner()
        )
    }

    func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        memoryStore: (any MemoryStore)?,
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)?,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)?
    ) -> AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: recipeAPI,
            shortcutDemoRecipeRunner: FixedShortcutDemoRecipeRunner()
        )
    }

    func makeDependencies(recipeAPI: any KairoRecipeAPI) -> AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: recipeAPI,
            shortcutDemoRecipeRunner: FixedShortcutDemoRecipeRunner()
        )
    }

    func makeDependencies(
        recipeAPI: any KairoRecipeAPI,
        shortcutDemoRecipeRunner: any ShortcutDemoRecipeRunnerProtocol
    ) -> AutomationsFeatureDependencies {
        AutomationsFeatureDependencies(
            recipeAPI: recipeAPI,
            shortcutDemoRecipeRunner: shortcutDemoRecipeRunner
        )
    }
}

private struct EmptyRecipeAPI: KairoRecipeAPI {
    func listRecipes() async throws -> [KairoRecipe] { [] }
    func recipe(id: String) async throws -> KairoRecipe? { nil }
    func save(_ recipe: KairoRecipe) async throws {}
    func delete(id: String) async throws {}
    func setEnabled(_ enabled: Bool, id: String) async throws {}
    func seedSampleRecipes() async throws -> [KairoRecipe] { [] }
    func run(_ request: KairoRecipeRunRequest) async throws -> KairoRecipeRunResult {
        KairoRecipeRunResult(
            recipeID: request.recipeID,
            startedAt: Date(timeIntervalSince1970: 0),
            finishedAt: Date(timeIntervalSince1970: 0),
            surface: request.surface,
            summary: "",
            stepResults: [],
            proposedActions: [],
            riskTier: .tier0ReadOnly,
            requiresConfirmation: false,
            success: false,
            errorMessage: nil
        )
    }
}
#endif
