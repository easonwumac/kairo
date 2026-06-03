import XCTest
@testable import KairoCore

final class KairoBackendAPITests: XCTestCase {
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

    func testLocalModelBackendAPIForwardsManagementCallsThroughCoreService() async throws {
        let service = try await makeLocalModelSettingsService()
        let api = KairoLocalModelBackendService(localModelSettingsService: service)

        var status = try await api.status()
        XCTAssertEqual(status.availableModels.map(\.id), ["qwen-small", "llama-stale"])
        XCTAssertNil(status.selectedModelID)
        XCTAssertEqual(status.preference, .automatic)

        try await api.selectModel(id: "qwen-small")
        try await api.setPreference(.preferLocal)

        status = try await api.status()
        XCTAssertEqual(status.selectedModelID, "qwen-small")
        XCTAssertEqual(status.preference, .preferLocal)

        let cleanedModelIDs = try await api.cleanupStaleDownloadingRecords()
        XCTAssertEqual(cleanedModelIDs, ["llama-stale"])

        try await api.deleteModel(id: "qwen-small")
        status = try await api.status()
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.installedModels.contains { $0.modelID == "qwen-small" })
    }

    func testLocalModelBackendAPIFailsClosedWhenServiceIsUnavailable() async throws {
        let api = KairoLocalModelBackendService(localModelSettingsService: nil)

        do {
            _ = try await api.status()
            XCTFail("Expected local model API status to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }

        do {
            try await api.selectModel(id: "qwen-small")
            XCTFail("Expected local model API selection to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    func testEnvironmentBackendAPIExposesLocalModelManagementFacade() async throws {
        let environment = KairoEnvironment.preview()

        do {
            _ = try await environment.backendAPI.localModels.status()
            XCTFail("Expected preview backend local model API to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    private func makeLocalModelSettingsService() async throws -> LocalModelSettingsService {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let qwenURL = modelsDirectory.appendingPathComponent("qwen-small.gguf")
        try Data("installed-model".utf8).write(to: qwenURL)
        let staleURL = modelsDirectory.appendingPathComponent("llama-stale.gguf")
        let stalePartialURL = staleURL.appendingPathExtension("download")
        try Data("partial-model".utf8).write(to: stalePartialURL)

        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small"),
                makeLocalModelManifest(id: "llama-stale")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: qwenURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "llama-stale",
            version: "1.0",
            status: .downloading,
            fileURL: staleURL,
            installedSizeBytes: 0,
            sha256: "def456"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        return LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)
    }

    private func makeLocalModelManifest(id: String) -> LocalModelManifest {
        LocalModelManifest(
            id: id,
            displayName: "Qwen Small Test",
            family: "Qwen",
            version: "1.0",
            parameterCount: "0.8B",
            quantization: "Q4",
            fileSizeBytes: 512,
            installedSizeBytes: 1024,
            contextWindow: 2048,
            tokenizerID: "qwen-test-tokenizer",
            licenseName: "Apache-2.0",
            licenseURL: URL(string: "https://example.com/license")!,
            minOSVersion: "17.0",
            minDeviceClass: "A15",
            minRAMGB: 4,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: URL(string: "https://example.com/model.gguf")!,
            sha256: "abc123",
            safetyPolicyVersion: "2026.1",
            deprecated: false
        )
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
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
