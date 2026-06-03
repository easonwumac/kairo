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

    func testSkillBackendAPIForwardsLifecycleThroughSkillManager() async throws {
        let service = try await makeAgentSkillManagerService()
        let api = KairoSkillBackendService(agentSkillManagerService: service)
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")
        let manifestJSON = try encodeManifestJSON(manifest)

        let preview = try await api.previewInstall(jsonString: manifestJSON)
        XCTAssertEqual(preview.skillID, "marketplace-weather-briefing")
        XCTAssertEqual(preview.installationChange, AgentSkillInstallationChange.install)
        XCTAssertTrue(preview.compatibilityReport.isInstallable)

        let installed = try await api.installManifest(jsonString: manifestJSON)
        XCTAssertEqual(installed.installationStatus, AgentSkillInstallationStatus.installed)
        var catalog = try await api.catalog()
        XCTAssertTrue(catalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        let disabled = try await api.disableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(disabled?.installationStatus, AgentSkillInstallationStatus.disabled)
        var effectiveCatalog = try await api.effectiveCatalog()
        XCTAssertFalse(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        let enabled = try await api.enableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(enabled?.installationStatus, AgentSkillInstallationStatus.installed)
        effectiveCatalog = try await api.effectiveCatalog()
        XCTAssertTrue(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        try await api.removeSkill(id: "marketplace-weather-briefing")
        catalog = try await api.catalog()
        XCTAssertNil(catalog.skill(id: "marketplace-weather-briefing"))
    }

    func testSkillBackendAPIRequiresExplicitUserDraftCapabilityAndConfirmationPolicy() async throws {
        let service = try await makeAgentSkillManagerService()
        let api = KairoSkillBackendService(agentSkillManagerService: service)

        let draft = try await api.createUserSkillDraft(AgentSkillDraftRequest(
            displayName: "Kairo Inbox Triage",
            summary: "Drafts a visible inbox triage plan from approved OAuth connector data.",
            kind: .custom,
            requiredCapabilities: [.externalConnectors],
            confirmationPolicy: .previewRequired,
            compatibilityRequirements: AgentSkillCompatibilityRequirements(requiredOAuthProviderKeys: ["google"])
        ))

        XCTAssertEqual(draft.id, "user-kairo-inbox-triage")
        XCTAssertEqual(draft.source, .userCreated)
        XCTAssertEqual(draft.installationStatus, .disabled)
        XCTAssertEqual(draft.requiredCapabilities, [.externalConnectors])
        XCTAssertEqual(draft.confirmationPolicy, .previewRequired)

        do {
            _ = try await api.createUserSkillDraft(AgentSkillDraftRequest(
                displayName: "Missing Capability",
                summary: "Should fail closed.",
                kind: .custom,
                requiredCapabilities: [],
                confirmationPolicy: .previewRequired
            ))
            XCTFail("Expected skill draft without explicit capabilities to fail closed.")
        } catch {
            XCTAssertEqual(error as? AgentSkillDraftError, .missingCapabilitySelection)
        }

        do {
            _ = try await api.createUserSkillDraft(AgentSkillDraftRequest(
                displayName: "Missing Confirmation",
                summary: "Should fail closed.",
                kind: .custom,
                requiredCapabilities: [.appIntents],
                confirmationPolicy: nil
            ))
            XCTFail("Expected skill draft without confirmation policy to fail closed.")
        } catch {
            XCTAssertEqual(error as? AgentSkillDraftError, .missingConfirmationPolicy)
        }
    }

    func testSkillBackendAPIBlocksIncompatibleMarketplaceSkillsFromExecutableCatalog() async throws {
        let service = try await makeAgentSkillManagerService(runtimeContext: AgentSkillRuntimeContext(
            iosVersion: "17.0",
            grantedEntitlements: [],
            connectedOAuthProviderKeys: [],
            installedLocalModelIDs: []
        ))
        let api = KairoSkillBackendService(agentSkillManagerService: service)
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires both a connected OAuth provider and a local model.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/qwen-oauth-workflow.json")!,
            kind: .localModel
        )
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")
        let manifestJSON = try encodeManifestJSON(manifest)

        let preview = try await api.previewInstall(jsonString: manifestJSON)
        XCTAssertFalse(preview.compatibilityReport.isInstallable)
        let blockingKinds = preview.compatibilityReport.blockingIssues.map { issue in issue.kind }
        XCTAssertEqual(blockingKinds, [.missingOAuthProvider, .missingLocalModel])

        do {
            _ = try await api.installManifest(jsonString: manifestJSON)
            XCTFail("Expected compatibility-blocked skill install to fail closed.")
        } catch let error as AgentSkillInstallError {
            guard case .compatibilityBlocked(let skillID, _) = error else {
                return XCTFail("Expected compatibilityBlocked, got \(error)")
            }
            XCTAssertEqual(skillID, "marketplace-qwen-oauth-workflow")
        }

        let effectiveCatalog = try await api.effectiveCatalog()
        XCTAssertFalse(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-qwen-oauth-workflow"))
    }

    func testSkillBackendAPIFailsClosedWhenServiceIsUnavailable() async throws {
        let api = KairoSkillBackendService(agentSkillManagerService: nil)

        do {
            _ = try await api.catalog()
            XCTFail("Expected skill API catalog to fail closed without a configured service.")
        } catch let error as KairoSkillAPIError {
            XCTAssertEqual(error, .unavailable)
        }

        do {
            try await api.removeSkill(id: "marketplace-weather-briefing")
            XCTFail("Expected skill API remove to fail closed without a configured service.")
        } catch let error as KairoSkillAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    func testSettingsBackendAPIManagesOpenAIKeyWithoutLeakingSecrets() async throws {
        let credentials = InMemoryCredentialStore()
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: credentials),
            oauthLoginCenter: OAuthConnectorLoginCenter(credentialStore: credentials)
        )

        var status = try await api.openAIStatus()
        XCTAssertFalse(status.hasAPIKey)

        let dryRun = try await api.dryRunOpenAIAPIKey(" openai-test-key-1234567890 ")
        XCTAssertFalse(dryRun.usesSavedKey)
        XCTAssertEqual(dryRun.redactedKey, "open...7890")
        XCTAssertTrue(dryRun.message.contains("No network request was sent"))
        let unsavedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertNil(unsavedOpenAIKey)

        try await api.saveOpenAIAPIKey(" openai-live-key-abcdef1234 ")
        status = try await api.openAIStatus()
        XCTAssertTrue(status.hasAPIKey)
        let savedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertEqual(savedOpenAIKey, "openai-live-key-abcdef1234")

        let savedDryRun = try await api.dryRunOpenAIAPIKey(nil)
        XCTAssertTrue(savedDryRun.usesSavedKey)
        XCTAssertEqual(savedDryRun.redactedKey, "open...1234")

        try await api.deleteOpenAIAPIKey()
        status = try await api.openAIStatus()
        XCTAssertFalse(status.hasAPIKey)
        let deletedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertNil(deletedOpenAIKey)
    }

    func testSettingsBackendAPIManagesOAuthLoginWithoutPersistingAuthorizationCode() async throws {
        let fileURL = temporaryFileURL(named: "oauth-callbacks.json")
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(fileURL: fileURL)
        let credentials = InMemoryCredentialStore()
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: credentials),
            oauthLoginCenter: OAuthConnectorLoginCenter(
                credentialStore: credentials,
                clientConfigurations: [
                    "google": OAuthConnectorClientConfiguration(
                        clientID: "google-client",
                        redirectURI: "kairo://oauth/google/callback",
                        scopes: ["openid", "email"]
                    )
                ],
                callbackStore: callbackStore
            )
        )

        let options = try await api.oauthLoginOptions()
        let googleOption = try XCTUnwrap(options.first { $0.providerKey == "google" })
        XCTAssertEqual(googleOption.readiness, .readyToAuthorize)
        XCTAssertTrue(googleOption.canStartAuthorization)

        let session = try await api.makeOAuthAuthorizationSession(
            for: "gmail-google-workspace",
            state: "state-123",
            codeVerifier: "verifier-123"
        )
        XCTAssertEqual(session.providerKey, "google")
        XCTAssertTrue(session.authorizationURL.absoluteString.contains("client_id=google-client"))
        XCTAssertFalse(session.authorizationURL.absoluteString.contains("sample-sensitive-code"))

        let preview = try await api.previewOAuthCallback(
            URL(string: "kairo://oauth/google/callback?code=sample-sensitive-code&state=state-123")!
        )
        XCTAssertEqual(preview.providerKey, "google")
        XCTAssertEqual(preview.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-sensitive-code".count)
        XCTAssertFalse(preview.settingsStatusText.contains("sample-sensitive-code"))

        let storedJSON = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(storedJSON.contains("sample-sensitive-code"))
        XCTAssertTrue(storedJSON.contains(#""authorizationCodeLength":21"#))

        try await credentials.saveSecret(
            try OAuthTokenSet(accessToken: "oauth-token", scopes: ["openid"]).encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "google")
        )
        var connectedOptions = try await api.oauthLoginOptions()
        XCTAssertEqual(connectedOptions.first { $0.providerKey == "google" }?.readiness, .connected)

        try await api.disconnectOAuthProvider(providerKey: "google")
        let disconnectedToken = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "google"))
        XCTAssertNil(disconnectedToken)
        connectedOptions = try await api.oauthLoginOptions()
        XCTAssertEqual(connectedOptions.first { $0.providerKey == "google" }?.readiness, .readyToAuthorize)
    }

    func testAccessBackendAPIResolvesPermissionStatusesWithoutRequestingPrompts() async throws {
        let permissions = RecordingPermissionService(statuses: [
            .calendar: .denied,
            .reminders: .restricted,
            .notifications: .unknown,
            .contacts: .available
        ])
        let api = KairoAccessBackendService(permissionService: permissions)

        let capabilities = await api.capabilities()
        let statuses = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.key, $0.status) })

        XCTAssertEqual(statuses[.calendar], .denied)
        XCTAssertEqual(statuses[.reminders], .restricted)
        XCTAssertEqual(statuses[.notifications], .unknown)
        XCTAssertEqual(statuses[.contacts], .available)
        XCTAssertTrue(capabilities.contains { $0.key == .chat && $0.status == .available })
        let requestedCapabilities = await permissions.requestedCapabilities()
        XCTAssertEqual(requestedCapabilities, [])
    }

    func testAccessBackendAPIForwardsExplicitPermissionRequests() async throws {
        let permissions = RecordingPermissionService(
            statuses: [.notifications: .unknown],
            requestResults: [.notifications: .denied]
        )
        let api = KairoAccessBackendService(permissionService: permissions)

        let initialStatus = await api.status(for: .notifications)
        let requestedStatus = try await api.request(.notifications)

        XCTAssertEqual(initialStatus, .unknown)
        XCTAssertEqual(requestedStatus, .denied)
        let requestedCapabilities = await permissions.requestedCapabilities()
        XCTAssertEqual(requestedCapabilities, [.notifications])
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

    private func makeAgentSkillManagerService(
        runtimeContext: AgentSkillRuntimeContext = .permissive
    ) async throws -> AgentSkillManagerService {
        let storeURL = temporaryFileURL(named: "agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        return AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            runtimeContext: runtimeContext
        )
    }

    private func encodeManifestJSON(_ manifest: AgentSkillManifest) throws -> String {
        let data = try JSONEncoder().encode(manifest)
        return String(decoding: data, as: UTF8.self)
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

private actor RecordingPermissionService: PermissionService {
    private var statuses: [CapabilityKey: CapabilityStatus]
    private let requestResults: [CapabilityKey: CapabilityStatus]
    private var requests: [CapabilityKey] = []

    init(
        statuses: [CapabilityKey: CapabilityStatus],
        requestResults: [CapabilityKey: CapabilityStatus] = [:]
    ) {
        self.statuses = statuses
        self.requestResults = requestResults
    }

    func status(for capability: CapabilityKey) async -> CapabilityStatus {
        if let status = statuses[capability] {
            return status
        }
        return await StubPermissionService().status(for: capability)
    }

    func request(_ capability: CapabilityKey) async throws -> CapabilityStatus {
        requests.append(capability)
        let result = requestResults[capability] ?? statuses[capability] ?? .unknown
        statuses[capability] = result
        return result
    }

    func requestedCapabilities() -> [CapabilityKey] {
        requests
    }
}
