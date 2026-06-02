import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KairoCore

final class KairoCoreTests: XCTestCase {
    func testMemoryStoreSearchesSavedMemory() async throws {
        let store = InMemoryMemoryStore()
        let memory = MemoryRecord(
            title: "Project Kairo",
            summary: "iOS agent with memory",
            content: "Kairo can remember user-approved content.",
            source: .manual
        )

        try await store.save(memory)
        let results = try await store.search(query: "agent", limit: 10)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, memory.id)
    }

    func testJSONFileMemoryStorePersistsSavedMemory() async throws {
        let fileURL = temporaryFileURL(named: "memory-store.json")
        let memory = MemoryRecord(
            title: "Persistent Memory",
            summary: "Stored on disk",
            content: "Kairo should preserve user-approved memory between launches.",
            source: .manual,
            tags: ["persistence"]
        )

        let firstStore = try await JSONFileMemoryStore(fileURL: fileURL)
        try await firstStore.save(memory)

        let secondStore = try await JSONFileMemoryStore(fileURL: fileURL)
        let results = try await secondStore.search(query: "preserve", limit: 10)

        XCTAssertEqual(results.map(\.id), [memory.id])
    }

    func testJSONFileMemoryStoreSoftDeletesMemory() async throws {
        let fileURL = temporaryFileURL(named: "memory-delete.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let memory = MemoryRecord(
            title: "Delete Me",
            summary: "Soft delete test",
            content: "This should disappear from active lists.",
            source: .manual
        )

        try await store.save(memory)
        try await store.delete(id: memory.id)

        let listed = try await store.list(limit: 10)
        let searched = try await store.search(query: "disappear", limit: 10)

        XCTAssertTrue(listed.isEmpty)
        XCTAssertTrue(searched.isEmpty)
        let rawData = try Data(contentsOf: fileURL)
        let rawText = String(data: rawData, encoding: .utf8) ?? ""
        XCTAssertTrue(rawText.contains(memory.id.uuidString))
        XCTAssertTrue(rawText.contains("deletedAt"))
    }

    func testSafetyPolicyRequiresConfirmationForWrites() {
        let engine = SafetyPolicyEngine()
        let action = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "User asked to remember this.",
            payload: .text("Remember this"),
            riskTier: .tier2LowRiskWrite
        )

        let decision = engine.evaluate(action)

        XCTAssertTrue(decision.allowed)
        XCTAssertTrue(decision.requiresConfirmation)
    }

    func testOpenAISettingsServiceSavesAndDeletesAPIKey() async throws {
        let credentials = InMemoryCredentialStore()
        let service = OpenAISettingsService(credentialStore: credentials)

        let initialStatus = try await service.status()
        XCTAssertFalse(initialStatus.hasAPIKey)

        try await service.saveAPIKey("  test-key  ")
        let savedStatus = try await service.status()
        let savedSecret = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertTrue(savedStatus.hasAPIKey)
        XCTAssertEqual(savedSecret, "test-key")

        try await service.deleteAPIKey()
        let deletedStatus = try await service.status()
        XCTAssertFalse(deletedStatus.hasAPIKey)
    }

    func testKairoPathsBuildsApplicationSupportMemoryURL() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.memoryStoreURL.lastPathComponent, "memory-store.json")
        XCTAssertEqual(paths.memoryStoreURL.deletingLastPathComponent().lastPathComponent, "KairoTests")
        XCTAssertEqual(paths.localModelsDirectory.lastPathComponent, "LocalModels")
        XCTAssertEqual(paths.localModelInstallRegistryURL.lastPathComponent, "install-registry.json")
    }

    func testLocalModelCatalogFiltersDeprecatedAndOldSafetyPolicyModels() throws {
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "available", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "old-policy", safetyPolicyVersion: "2025.9"),
                makeLocalModelManifest(id: "deprecated", safetyPolicyVersion: "2026.2", deprecated: true)
            ]
        )

        let encoded = try catalog.encoded()
        let decoded = try LocalModelCatalog.decode(encoded)
        let available = decoded.availableModels(minimumSafetyPolicyVersion: "2026.1")

        XCTAssertEqual(available.map(\.id), ["available"])
    }

    func testFileBackedLocalModelInstallRegistryPersistsInstalledRecords() async throws {
        let fileURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = fileURL.deletingLastPathComponent().appendingPathComponent("model.gguf")
        let record = LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        )

        let firstRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        try await firstRegistry.upsert(record)

        let secondRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        let persisted = await secondRegistry.record(for: "qwen-small")
        let installedRecords = await secondRegistry.installedRecords()

        XCTAssertEqual(persisted?.modelID, record.modelID)
        XCTAssertEqual(persisted?.version, record.version)
        XCTAssertEqual(persisted?.status, .installed)
        XCTAssertEqual(persisted?.fileURL, record.fileURL)
        XCTAssertEqual(persisted?.installedSizeBytes, record.installedSizeBytes)
        XCTAssertEqual(persisted?.sha256, record.sha256)
        XCTAssertEqual(installedRecords.map(\.modelID), [record.modelID])
    }

    func testLocalFallbackProviderReturnsPlaceholderWithoutActions() async throws {
        let provider = LocalFallbackProvider(installedModelID: "qwen-small")

        let response = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "Draft a note"))

        XCTAssertTrue(response.message.contains("Local fallback (qwen-small)"))
        XCTAssertTrue(response.message.contains("cannot browse the web"))
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testProviderRouterUsesInstalledLocalModelForOfflineEligiblePrompt() async throws {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "Summarize this note")
        let context = ProviderRoutingContext(
            networkAvailable: false,
            taskClass: .summarization,
            localModelInstalled: true
        )

        let decision = router.decision(for: request, context: context)
        let response = try await router.complete(request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .local, reason: .cloudUnavailable))
        XCTAssertTrue(response.message.contains("Local fallback"))
    }

    func testProviderRouterBlocksLocalForToolUseInOfflineMode() async throws {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "Create a calendar event")
        let context = ProviderRoutingContext(
            networkAvailable: false,
            offlineModeEnabled: true,
            taskClass: .toolUse,
            requiresToolUse: true,
            localModelInstalled: true
        )

        let decision = router.decision(for: request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .unavailable, reason: .toolRequired))
        do {
            _ = try await router.complete(request, context: context)
            XCTFail("Expected unsupported route")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .unsupported)
        }
    }

    func testProviderRouterRoutesCurrentInfoToCloudWhenAvailable() {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "What happened today?")
        let context = ProviderRoutingContext(
            networkAvailable: true,
            taskClass: .webCurrentInfo,
            requiresCurrentInfo: true,
            localModelInstalled: true
        )

        let decision = router.decision(for: request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .cloud, reason: .localIncapable))
    }

    func testOpenAIProviderThrowsWhenCredentialIsMissing() async throws {
        let provider = OpenAIProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: MockHTTPClient(statusCode: 200, body: #"{"output_text":"unused"}"#)
        )

        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))
            XCTFail("Expected missingCredential error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingCredential)
        }
    }

    func testOpenAIProviderBuildsAuthorizedResponsesRequestAndParsesOutputText() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let httpClient = MockHTTPClient(statusCode: 200, body: #"{"output_text":"Hello from Kairo"}"#)
        let provider = OpenAIProvider(credentialStore: credentials, httpClient: httpClient)

        let response = try await provider.complete(
            AICompletionRequest(
                systemPrompt: "system",
                userPrompt: "hello",
                memoryContext: [
                    MemoryRecord(title: "Preference", summary: "Likes concise answers", content: "", source: .manual)
                ],
                allowedCapabilities: [.memory, .reminders]
            )
        )

        XCTAssertEqual(response.message, "Hello from Kairo")
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.httpMethod, "POST")

        let body = try XCTUnwrap(request.httpBody)
        let bodyObject = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(bodyObject?["model"] as? String, "gpt-4.1")
        XCTAssertNotNil(bodyObject?["input"])
    }

    func testOpenAIProviderParsesNestedResponsesOutput() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let body = #"{"output":[{"content":[{"text":"Nested"},{"text":"response"}]}]}"#
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(statusCode: 200, body: body)
        )

        let response = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))

        XCTAssertEqual(response.message, "Nested\nresponse")
    }

    func testOpenAIProviderEmbedsText() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(statusCode: 200, body: #"{"data":[{"embedding":[0.1,0.2,0.3]}]}"#)
        )

        let response = try await provider.embed(AIEmbeddingRequest(input: "hello"))

        XCTAssertEqual(response.vector, [0.1, 0.2, 0.3])
    }

    func testOpenAIProviderSanitizesErrorResponses() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(
                statusCode: 429,
                body: #"{"error":{"message":"raw prompt secret should not leak","type":"rate_limit_error"}}"#
            )
        )

        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))
            XCTFail("Expected requestFailed error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .requestFailed("OpenAI request failed with status 429 type=rate_limit_error."))
        }
    }

    func testChatGPTOAuthServiceBuildsPKCEAuthorizationURL() async throws {
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid", "profile"],
                audience: "chatgpt"
            ),
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/callback")
        XCTAssertEqual(query["scope"], "openid profile")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
        XCTAssertEqual(query["audience"], "chatgpt")
    }

    func testJSONFileChatHistoryStorePersistsAndSoftDeletesThreads() async throws {
        let fileURL = temporaryFileURL(named: "chat-history.json")
        let thread = ChatThread(
            title: "Plan UI",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            messages: [
                ChatMessage(role: .user, text: "Improve the chat UI", createdAt: Date(timeIntervalSince1970: 10)),
                ChatMessage(role: .assistant, text: "Let's add history.", createdAt: Date(timeIntervalSince1970: 11))
            ]
        )

        let firstStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        try await firstStore.saveThread(thread)

        let secondStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        let loaded = try await secondStore.thread(id: thread.id)
        let listed = try await secondStore.listThreads(limit: 10)

        XCTAssertEqual(loaded?.messages.map(\.text), ["Improve the chat UI", "Let's add history."])
        XCTAssertEqual(listed.map(\.id), [thread.id])

        try await secondStore.deleteThread(id: thread.id)
        let deletedThread = try await secondStore.thread(id: thread.id)
        let threadsAfterDelete = try await secondStore.listThreads(limit: 10)
        XCTAssertNil(deletedThread)
        XCTAssertTrue(threadsAfterDelete.isEmpty)

        let rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(thread.id.uuidString))
        XCTAssertTrue(rawText.contains("deletedAt"))
    }

    func testChatThreadDerivesTitleFromFirstUserMessage() {
        var thread = ChatThread()
        let message = ChatMessage(role: .user, text: "  Please remember my meeting notes and summarize them later  ")

        thread.append(message, now: message.createdAt)

        XCTAssertEqual(thread.title, "Please remember my meeting notes and summa")
        XCTAssertEqual(thread.lastMessagePreview, "Please remember my meeting notes and summarize them later")
    }

    func testKairoPathsBuildsApplicationSupportChatHistoryURL() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.chatHistoryStoreURL.lastPathComponent, "chat-history.json")
        XCTAssertEqual(paths.chatHistoryStoreURL.deletingLastPathComponent().lastPathComponent, "KairoTests")
    }

    func testSandboxActionCatalogDescribesSupportedIOSActions() {
        let catalog = SandboxActionCatalog()

        XCTAssertEqual(catalog.descriptor(for: .saveMemory)?.supportStatus, .implemented)
        XCTAssertEqual(catalog.descriptor(for: .createReminderDraft)?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(catalog.descriptor(for: .externalAPIRequest)?.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(catalog.supportedDescriptors.map(\.kind).contains(.openURL))
    }

    func testSandboxActionExecutorRequiresConfirmationBeforeSavingMemory() async throws {
        let memoryStore = InMemoryMemoryStore()
        let executor = SandboxActionExecutor(memoryStore: memoryStore)
        let action = AgentAction(
            kind: .saveMemory,
            title: "Remember",
            rationale: "User asked Kairo to remember this.",
            payload: .text("Remember that Kairo can operate sandboxed iOS capabilities."),
            riskTier: .tier2LowRiskWrite
        )

        let unconfirmed = try await executor.execute(action, confirmed: false)
        let memoriesBeforeConfirmation = try await memoryStore.list(limit: 10)
        XCTAssertFalse(unconfirmed.completed)
        XCTAssertTrue(memoriesBeforeConfirmation.isEmpty)

        let confirmed = try await executor.execute(action, confirmed: true)
        let memories = try await memoryStore.search(query: "sandboxed", limit: 10)
        XCTAssertTrue(confirmed.completed)
        XCTAssertEqual(memories.count, 1)
    }

    func testSandboxActionExecutorReturnsScaffoldedResultForOpenURL() async throws {
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        let action = AgentAction(
            kind: .openURL,
            title: "Open URL",
            rationale: "User wants to open a URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertTrue(result.message.contains("UI opener"))
    }

    func testChatGPTOAuthServiceValidatesCallbackAndStoresTokens() async throws {
        let credentials = InMemoryCredentialStore()
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid"]
            ),
            credentialStore: credentials
        )

        let code = try await service.validateCallback(URL(string: "kairo://oauth/callback?code=abc&state=expected")!, expectedState: "expected")
        XCTAssertEqual(code, "abc")

        try await service.storeTokens(OAuthTokenSet(accessToken: "access", refreshToken: "refresh", scopes: ["openid"]))
        let tokens = try await service.loadTokens()
        XCTAssertEqual(tokens?.accessToken, "access")
        XCTAssertEqual(tokens?.refreshToken, "refresh")

        try await service.signOut()
        let signedOutTokens = try await service.loadTokens()
        XCTAssertNil(signedOutTokens)
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func makeLocalModelManifest(
        id: String,
        safetyPolicyVersion: String = "2026.1",
        deprecated: Bool = false
    ) -> LocalModelManifest {
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
            safetyPolicyVersion: safetyPolicyVersion,
            deprecated: deprecated
        )
    }
}

private actor MockHTTPClient: HTTPClient {
    private let statusCode: Int
    private let body: String
    private var capturedRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }

    func lastRequest() throws -> URLRequest {
        guard let capturedRequest else {
            throw MockHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private enum MockHTTPClientError: Error {
    case missingRequest
}
