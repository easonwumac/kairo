import XCTest
@testable import KairoCore

final class KairoBackendAPITests: XCTestCase {
    func testBackendAPIExposesProductionModuleRegistryForCoreComposition() throws {
        XCTAssertEqual(
            KairoBackendModuleRegistry.production.modules.map(\.id),
            KairoBackendModuleID.allCases
        )
        XCTAssertEqual(
            KairoBackendModuleRegistry.production.modules.map(\.displayName),
            [
                "Chat",
                "Memory",
                "Internal Recipes",
                "Share Imports",
                "Data Deletion",
                "Local Models",
                "Skill Manager",
                "Settings",
                "Access"
            ]
        )
        XCTAssertTrue(KairoBackendModuleRegistry.production.modules.allSatisfy { !$0.boundarySummary.isEmpty })

        let summariesByID = Dictionary(
            uniqueKeysWithValues: KairoBackendModuleRegistry.production.modules.map { ($0.id, $0.boundarySummary) }
        )
        XCTAssertTrue(summariesByID[.recipes]?.contains("without Apple Shortcut mutation") == true)
        XCTAssertTrue(summariesByID[.shareImports]?.contains("without extension-side actions") == true)
        XCTAssertTrue(summariesByID[.skills]?.contains("effective tool catalog") == true)
        XCTAssertTrue(summariesByID[.localModels]?.contains("explicit download state") == true)
        XCTAssertTrue(summariesByID[.access]?.contains("explicit permission requests") == true)

        let api = KairoBackendAPI(
            chat: KairoChatBackendService(agent: AgentCore()),
            memory: KairoMemoryBackendService(memoryStore: InMemoryMemoryStore()),
            recipes: KairoRecipeBackendService(recipeStore: InMemoryKairoRecipeStore()),
            shareImports: KairoShareImportBackendService(shareIngestionQueue: InMemoryShareIngestionQueue()),
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

    func testChatBackendAPIForwardsPrivacyModeThroughAgentCore() async throws {
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Private response"))
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(
                    title: "Private note",
                    summary: "Should not be queried",
                    content: "private content",
                    source: .manual
                )
            ]),
            aiProvider: provider
        ))

        let response = try await api.respond(
            to: "summarize private content",
            attachments: [],
            privacyMode: .privateChat
        )
        let request = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(request)

        XCTAssertEqual(response.message, "Private response")
        XCTAssertEqual(capturedRequest.privacyMode, .privateChat)
        XCTAssertTrue(capturedRequest.memoryContext.isEmpty)
    }

    func testMemoryBackendAPIForwardsLifecycleAndExportThroughStore() async throws {
        let memoryID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let store = InMemoryMemoryStore()
        let api = KairoMemoryBackendService(memoryStore: store)
        let memory = MemoryRecord(
            id: memoryID,
            title: "Backend boundary",
            summary: "Memory API facade",
            content: "Kairo memory should be reachable through backend API.",
            source: .manual,
            tags: ["backend"]
        )

        try await api.save(memory)
        var listed = try await api.list(limit: 10)
        XCTAssertEqual(listed.map(\.id), [memoryID])

        let searched = try await api.search(query: "boundary", limit: 10)
        XCTAssertEqual(searched.map(\.id), [memoryID])

        let exported = try await api.export(limit: 10)
        XCTAssertEqual(exported.records.map(\.id), [memoryID])

        try await api.delete(id: memoryID)
        listed = try await api.list(limit: 10)
        XCTAssertTrue(listed.isEmpty)

        try await api.purgeDeleted()
        let purgedExport = try await api.export(limit: 10)
        XCTAssertTrue(purgedExport.records.isEmpty)
    }

    func testRecipeBackendAPIForwardsLifecycleAndRunThroughInternalRecipeStore() async throws {
        let store = InMemoryKairoRecipeStore()
        let api = KairoRecipeBackendService(recipeStore: store)
        let recipe = KairoRecipe(
            id: "backend-noop-recipe",
            title: "Backend Noop Recipe",
            summary: "Exercises Kairo-owned internal recipe backend lifecycle.",
            steps: [
                KairoRecipeStep(
                    id: "noop",
                    title: "No operation",
                    kind: .noOp,
                    input: .literal("backend")
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )

        try await api.save(recipe)
        var recipes = try await api.listRecipes()
        XCTAssertEqual(recipes.map(\.id), ["backend-noop-recipe"])
        let loadedRecipe = try await api.recipe(id: "backend-noop-recipe")
        XCTAssertEqual(loadedRecipe?.title, "Backend Noop Recipe")

        let result = try await api.run(KairoRecipeRunRequest(
            recipeID: "backend-noop-recipe",
            surface: .appIntent,
            input: "Run internal recipe",
            dryRun: true,
            userConfirmed: false
        ))
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.recipeID, "backend-noop-recipe")
        XCTAssertEqual(result.proposedActions, [])

        try await api.setEnabled(false, id: "backend-noop-recipe")
        let disabledRun = try await api.run(KairoRecipeRunRequest(
            recipeID: "backend-noop-recipe",
            surface: .appIntent,
            input: nil,
            dryRun: true,
            userConfirmed: false
        ))
        XCTAssertFalse(disabledRun.success)
        XCTAssertEqual(disabledRun.errorMessage, "Recipe disabled.")

        try await api.delete(id: "backend-noop-recipe")
        recipes = try await api.listRecipes()
        XCTAssertTrue(recipes.isEmpty)
    }

    func testRecipeBackendAPISeedsKairoOwnedSamplesWithoutAppleShortcutSideEffects() async throws {
        let store = InMemoryKairoRecipeStore()
        let api = KairoRecipeBackendService(recipeStore: store)

        let samples = try await api.seedSampleRecipes()

        XCTAssertEqual(Set(samples.map(\.id)), ["daily-briefing", "meeting-prep", "shared-text-to-tasks", "keyboard-todo-capture"])
        XCTAssertTrue(samples.allSatisfy { $0.createdBy == .template })
        XCTAssertTrue(samples.allSatisfy(\.isEnabled))
    }

    func testShareImportBackendAPIImportsPendingItemsAndMarksThemImported() async throws {
        let builder = ShareAttachmentBuilder()
        let firstItem = ShareIngestionItem(
            attachments: [
                builder.text("Shared text", displayName: "Note"),
                builder.url(URL(string: "https://example.com/article")!)
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let secondItem = ShareIngestionItem(
            attachments: [
                builder.file(
                    url: URL(fileURLWithPath: "/tmp/brief.pdf"),
                    displayName: "brief.pdf",
                    uniformTypeIdentifier: "com.adobe.pdf",
                    byteCount: 2048
                )
            ],
            sourceApplication: "Files",
            receivedAt: Date(timeIntervalSince1970: 20)
        )
        let queue = InMemoryShareIngestionQueue(seed: [firstItem, secondItem])
        let api = KairoShareImportBackendService(shareIngestionQueue: queue)

        let imported = try await api.importPendingShares(limit: 10)

        XCTAssertEqual(imported.importedItemIDs, [firstItem.id, secondItem.id])
        XCTAssertEqual(imported.attachments.map(\.kind), [.text, .url, .pdf])
        XCTAssertEqual(imported.attachments.map(\.source), [.shareExtension, .shareExtension, .shareExtension])
        XCTAssertEqual(imported.suggestedPrompt, firstItem.suggestedPrompt)
        let remaining = try await queue.pendingItems(limit: 10)
        XCTAssertTrue(remaining.isEmpty)
    }

    func testDeletionBackendAPIDeletesOnDevicePrivacyDataThroughCoreInterfaces() async throws {
        let threadID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let memoryID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let chatStore = InMemoryChatHistoryStore(seed: [
            ChatThread(id: threadID, messages: [
                ChatMessage(role: .user, text: "Private thread")
            ])
        ])
        let memoryStore = InMemoryMemoryStore(seed: [
            MemoryRecord(
                id: memoryID,
                title: "Private memory",
                summary: "Delete through backend API",
                content: "Sensitive user-approved content",
                source: .manual
            )
        ])
        let credentialStore = InMemoryCredentialStore()
        let auditLogger = InMemoryAuditLogger()
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: chatStore,
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            auditLogger: auditLogger
        )

        try await credentialStore.saveSecret("sk-test", for: CredentialKey.openAIAPIKey)
        try await credentialStore.saveSecret(
            try OAuthTokenSet(accessToken: "oauth-token", scopes: ["repo"]).encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "github")
        )
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
        try await deletionAPI.deleteMemory(id: memoryID)
        try await deletionAPI.purgeDeletedMemories()
        try await deletionAPI.deleteOpenAIAPIKey()
        try await deletionAPI.disconnectOAuthProvider(providerKey: "github")
        try await deletionAPI.clearAuditLog()

        let deletedThread = try await chatStore.thread(id: threadID)
        let remainingMemories = try await memoryStore.list(limit: 10)
        let openAIAPIKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let githubToken = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "github"))
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertNil(deletedThread)
        XCTAssertTrue(remainingMemories.isEmpty)
        XCTAssertNil(openAIAPIKey)
        XCTAssertNil(githubToken)
        XCTAssertTrue(auditEvents.isEmpty)
    }

    func testDeletionBackendAPIFailsClosedWhenLocalModelServiceIsUnavailable() async throws {
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: InMemoryChatHistoryStore(),
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            auditLogger: InMemoryAuditLogger()
        )

        do {
            try await deletionAPI.deleteLocalModel(id: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected local model deletion to fail closed without a configured service.")
        } catch let error as KairoDeletionAPIError {
            XCTAssertEqual(error, .localModelDeletionUnavailable)
        }
    }

}

private actor BackendAPICapturingAIProvider: AIProvider {
    private var lastRequest: AICompletionRequest?
    private let response: AICompletionResponse

    init(response: AICompletionResponse) {
        self.response = response
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        lastRequest = request
        return response
    }

    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        return AIEmbeddingResponse(vector: [])
    }

    func capturedRequest() -> AICompletionRequest? {
        lastRequest
    }
}
