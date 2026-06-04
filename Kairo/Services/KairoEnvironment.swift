import Foundation
import CryptoKit

public enum KairoSharedAppStorage {
    public static let appName = "Kairo"
    public static let appGroupIdentifier = "group.app.kairo.shared"

    public static func paths(
        appName: String = KairoSharedAppStorage.appName,
        appGroupContainerProvider: (@Sendable (String) -> URL?)? = nil
    ) -> KairoPaths {
        KairoPaths(
            appName: appName,
            appGroupIdentifier: appGroupIdentifier,
            appGroupContainerProvider: appGroupContainerProvider
        )
    }
}

private enum KairoEnvironmentError: Error {
    case invalidUITestingLocalModelURL
}

public struct KairoEnvironment: KairoBackendDependencies {
    public let memoryStore: MemoryStore
    public let credentialStore: CredentialStore
    public let aiProvider: AIProvider
    public let chatHistoryStore: ChatHistoryStore
    public let shareIngestionQueue: ShareIngestionQueue
    public let kairoRecipeStore: any KairoRecipeStore
    public let permissionService: PermissionService
    public let auditLogger: AuditLogger
    public let oauthConnectorCallbackStore: FileBackedOAuthConnectorCallbackStore?
    public let agentSkillManagerService: AgentSkillManagerService?
    public let agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService?
    public let localModelCatalog: LocalModelCatalog
    public let localModelCatalogService: LocalModelCatalogService?
    public let localModelSettingsService: LocalModelSettingsService?
    public let localModelDownloader: (any LocalModelDownloader)?
    public let localModelBenchmarkService: LocalModelBenchmarkService?
    public let localModelReplyCheckService: LocalModelReplyCheckService?
    public let actionExecutor: any ActionExecutor

    public init(
        memoryStore: MemoryStore,
        credentialStore: CredentialStore,
        aiProvider: AIProvider,
        chatHistoryStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        kairoRecipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        permissionService: PermissionService = StubPermissionService(),
        auditLogger: AuditLogger = InMemoryAuditLogger(),
        oauthConnectorCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        agentSkillManagerService: AgentSkillManagerService? = nil,
        agentSkillMarketplaceCatalogService: AgentSkillMarketplaceCatalogService? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        actionExecutor: (any ActionExecutor)? = nil
    ) {
        self.memoryStore = memoryStore
        self.credentialStore = credentialStore
        self.aiProvider = aiProvider
        self.chatHistoryStore = chatHistoryStore
        self.shareIngestionQueue = shareIngestionQueue
        self.kairoRecipeStore = kairoRecipeStore
        self.permissionService = permissionService
        self.auditLogger = auditLogger
        self.oauthConnectorCallbackStore = oauthConnectorCallbackStore
        self.agentSkillManagerService = agentSkillManagerService
        self.agentSkillMarketplaceCatalogService = agentSkillMarketplaceCatalogService
        self.localModelCatalog = localModelCatalog
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.actionExecutor = actionExecutor ?? SandboxActionExecutor(memoryStore: memoryStore, auditLogger: auditLogger)
    }

    public static func preview() -> KairoEnvironment {
        let credentialStore = InMemoryCredentialStore()
        return KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            chatHistoryStore: InMemoryChatHistoryStore(seed: [ChatThread(messages: [
                ChatMessage(role: .assistant, text: "我是 Kairo。我會記住你選擇交給我的內容，並只操作 iOS sandbox 與公開 API 允許的能力。")
            ])]),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            kairoRecipeStore: InMemoryKairoRecipeStore(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }

    public static func uiTesting(
        resetPersistentState: Bool = true,
        seedInstalledLocalModel: Bool = false,
        seedInstalledWeatherSkill: Bool = false,
        seedExpandedLocalModelCatalog: Bool = false
    ) async throws -> KairoEnvironment {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoUITesting", isDirectory: true)
        if resetPersistentState {
            try? FileManager.default.removeItem(at: rootDirectory)
        }

        let skillStore = try await FileBackedAgentSkillStore(
            fileURL: rootDirectory
                .appendingPathComponent("Skills", isDirectory: true)
                .appendingPathComponent("agent-skills.json")
        )
        let skillManagerService = AgentSkillManagerService(
            store: skillStore,
            builtInCatalog: .defaultWithMarketplaceSamples,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.0",
                grantedEntitlements: [],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: []
            )
        )
        if seedInstalledWeatherSkill {
            try await skillStore.upsert(uiTestingInstalledWeatherSkill(version: "2.0.0"))
        }
        let marketplaceCatalogService = try uiTestingMarketplaceCatalogService()
        let localModelCatalog: LocalModelCatalog
        if seedExpandedLocalModelCatalog {
            localModelCatalog = try LocalModelCatalog.kairoDefault.mergingRemoteCatalog(LocalModelCatalog(
                generatedAt: Date(timeIntervalSince1970: 1_767_225_600),
                signingKeyID: "kairo-ui-testing-expanded-local-models",
                signature: "unsigned-ui-testing-placeholder",
                sourceRepository: URL(string: "https://github.com/easonwumac/kairo-models"),
                minimumSafetyPolicyVersion: LocalModelCatalog.kairoDefault.minimumSafetyPolicyVersion,
                models: [uiTestingRemoteCatalogModel()]
            ))
        } else {
            localModelCatalog = .kairoDefault
        }
        let localModelCatalogService = try uiTestingLocalModelCatalogService(catalog: localModelCatalog)
        let localModelInstallRegistry = try await FileBackedLocalModelInstallRegistry(
            fileURL: rootDirectory
                .appendingPathComponent("LocalModels", isDirectory: true)
                .appendingPathComponent("install-registry.json")
        )
        if seedInstalledLocalModel {
            try await localModelInstallRegistry.upsert(LocalModelInstallRecord(
                modelID: LocalModelManifest.qwen35Tiny.id,
                version: LocalModelManifest.qwen35Tiny.version,
                status: .installed,
                fileURL: rootDirectory
                    .appendingPathComponent("LocalModels", isDirectory: true)
                    .appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf"),
                installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
                sha256: LocalModelManifest.qwen35Tiny.sha256
            ))
        }
        let localModelSettingsStore = try await FileBackedLocalModelSettingsStore(
            fileURL: rootDirectory
                .appendingPathComponent("LocalModels", isDirectory: true)
                .appendingPathComponent("settings.json")
        )
        let localModelSettingsService = LocalModelSettingsService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            settingsStore: localModelSettingsStore
        )
        let localModelBenchmarkStore = try await FileBackedLocalModelBenchmarkStore(
            fileURL: rootDirectory
                .appendingPathComponent("LocalModels", isDirectory: true)
                .appendingPathComponent("benchmarks.json")
        )
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore
        )
        let localModelReplyCheckService = LocalModelReplyCheckService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            runtime: DeterministicLocalModelReplyCheckRuntime(
                responseText: "Local model reply is alive.",
                generationTokensPerSecond: 38.5
            )
        )
        let credentialStore = InMemoryCredentialStore()
        let oauthCallbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: rootDirectory
                .appendingPathComponent("OAuth", isDirectory: true)
                .appendingPathComponent("callback-previews.json")
        )
        let kairoRecipeStore = try await FileBackedKairoRecipeStore(
            fileURL: rootDirectory
                .appendingPathComponent("Recipes", isDirectory: true)
                .appendingPathComponent("kairo-recipes.json")
        )
        let memoryStore = InMemoryMemoryStore()
        let auditLogger = InMemoryAuditLogger()

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            chatHistoryStore: InMemoryChatHistoryStore(seed: [ChatThread(messages: [
                ChatMessage(role: .assistant, text: "UI testing Kairo environment loaded.")
            ])]),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            kairoRecipeStore: kairoRecipeStore,
            permissionService: StubPermissionService(),
            auditLogger: auditLogger,
            oauthConnectorCallbackStore: oauthCallbackStore,
            agentSkillManagerService: skillManagerService,
            agentSkillMarketplaceCatalogService: marketplaceCatalogService,
            localModelCatalog: localModelCatalog,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelBenchmarkService: localModelBenchmarkService,
            localModelReplyCheckService: localModelReplyCheckService,
            actionExecutor: SandboxActionExecutor(
                memoryStore: memoryStore,
                reminderScheduler: AllowingReminderScheduler(identifier: "ui-testing-reminder-id"),
                calendarScheduler: AllowingCalendarScheduler(identifier: "ui-testing-calendar-event-id"),
                contactScheduler: AllowingContactScheduler(identifier: "ui-testing-contact-id"),
                urlOpener: AllowingURLOpener(),
                notificationScheduler: AllowingNotificationScheduler(identifier: "ui-testing-notification-id"),
                auditLogger: auditLogger
            )
        )
    }

    private static func uiTestingRemoteCatalogModel() throws -> LocalModelManifest {
        guard let licenseURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0"),
              let downloadURL = URL(string: "https://example.com/kairo/remote-catalog-test-model-q4_k_m.gguf")
        else {
            throw KairoEnvironmentError.invalidUITestingLocalModelURL
        }

        return LocalModelManifest(
            id: "remote-catalog-test-model-q4-k-m",
            displayName: "Remote Catalog Test Model Q4_K_M",
            family: "Remote Catalog Test",
            version: "1.0",
            parameterCount: "1B",
            quantization: "Q4_K_M",
            runtime: .gguf,
            fileSizeBytes: 640_000_000,
            installedSizeBytes: 1_000 * 1024 * 1024,
            contextWindow: 8_192,
            tokenizerID: "remote-catalog-test-tokenizer",
            licenseName: "Apache-2.0",
            licenseURL: licenseURL,
            minOSVersion: "17.0",
            minDeviceClass: "A15",
            minRAMGB: 4,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: downloadURL,
            sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            createdAt: Date(timeIntervalSince1970: 1_767_225_600),
            updatedAt: Date(timeIntervalSince1970: 1_767_225_600),
            safetyPolicyVersion: "2026.1"
        )
    }

    private static func uiTestingMarketplaceCatalogService() throws -> AgentSkillMarketplaceCatalogService {
        let indexURL = AgentSkillMarketplaceCatalogService.defaultIndexURL
        let manifestURL = URL(string: "manifests/weather-briefing.json", relativeTo: indexURL)!.absoluteURL
        let qwenWorkflowManifestURL = URL(string: "manifests/qwen-oauth-workflow.json", relativeTo: indexURL)!.absoluteURL
        var weatherSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: manifestURL
        )
        weatherSkill.version = "2.1.0"
        weatherSkill.author = "Kairo Marketplace"

        let manifest = try AgentSkillManifest(
            skill: weatherSkill,
            packageVersion: "2026.6",
            checksum: AgentSkillManifest.sha256Hex(for: weatherSkill),
            signature: AgentSkillManifestSignature(
                keyID: "kairo-test-key",
                algorithm: .ed25519,
                value: "test-signature"
            ),
            changelog: ["Adds storm alerts."]
        )
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        var qwenWorkflowSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires Google OAuth and a downloaded Qwen model before it can be installed.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: qwenWorkflowManifestURL
        )
        qwenWorkflowSkill.version = "1.0.0"
        qwenWorkflowSkill.author = "Kairo Marketplace"
        qwenWorkflowSkill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let qwenWorkflowManifest = try AgentSkillManifest.signedForTesting(
            skill: qwenWorkflowSkill,
            packageVersion: "2026.6"
        )
        let qwenWorkflowManifestJSON = try AgentSkillManifest.encodeJSONString(qwenWorkflowManifest)
        let indexJSON = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API and returns a compact daily plan.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            },
            {
              "id": "marketplace-qwen-oauth-workflow",
              "displayName": "Qwen OAuth Workflow",
              "summary": "Requires Google OAuth and a downloaded Qwen model before it can be installed.",
              "version": "1.0.0",
              "author": "Kairo Marketplace",
              "category": "Local Model",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 2: local model plus OAuth-gated request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/qwen-oauth-workflow.json",
              "screenshots": ["assets/shortcut-toolkit-card.svg"],
              "changelog": ["Adds compatibility gates for OAuth and local model availability."],
              "compatibilityRequirements": {
                "requiredOAuthProviderKeys": ["google"],
                "requiredLocalModelIDs": ["qwen3-5-0-8b-q4-k-m"]
              }
            }
          ]
        }
        """
        let httpClient = StaticHTTPClient(routes: [
            indexURL: StaticHTTPResponse(body: indexJSON),
            manifestURL: StaticHTTPResponse(body: manifestJSON),
            qwenWorkflowManifestURL: StaticHTTPResponse(body: qwenWorkflowManifestJSON)
        ])

        return AgentSkillMarketplaceCatalogService(indexURL: indexURL, httpClient: httpClient)
    }

    private static func uiTestingInstalledWeatherSkill(version: String) -> AgentSkill {
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(
                string: "manifests/weather-briefing.json",
                relativeTo: AgentSkillMarketplaceCatalogService.defaultIndexURL
            )!.absoluteURL
        )
        skill.version = version
        skill.author = "Kairo Marketplace"
        skill.installationStatus = .installed
        return skill
    }

    private static func uiTestingLocalModelCatalogService(catalog: LocalModelCatalog = .kairoDefault) throws -> LocalModelCatalogService {
        let indexURL = LocalModelCatalogService.defaultIndexURL
        let signingKey = P256.Signing.PrivateKey()
        let signedCatalog = try LocalModelCatalog.signedForTesting(
            catalog: catalog,
            keyID: catalog.signingKeyID,
            signingKey: signingKey
        )
        let catalogJSON = String(data: try signedCatalog.encoded(), encoding: .utf8) ?? "{}"
        let httpClient = StaticHTTPClient(routes: [
            indexURL: StaticHTTPResponse(body: catalogJSON)
        ])
        var trustedKeys = LocalModelCatalogService.defaultTrustStore.trustedKeys
        let fixtureKey = LocalModelTrustedSigningKey(
            keyID: signedCatalog.signingKeyID,
            algorithm: "p256-sha256",
            status: .active,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
        )
        if let index = trustedKeys.firstIndex(where: { $0.keyID == signedCatalog.signingKeyID }) {
            trustedKeys[index] = fixtureKey
        } else {
            trustedKeys.append(fixtureKey)
        }
        return LocalModelCatalogService(
            indexURL: indexURL,
            httpClient: httpClient,
            trustStore: LocalModelCatalogTrustStore(trustedKeys: trustedKeys)
        )
    }

    public static func live(
        appName: String = KairoSharedAppStorage.appName,
        appGroupIdentifier: String? = KairoSharedAppStorage.appGroupIdentifier
    ) async throws -> KairoEnvironment {
        let paths = KairoPaths(appName: appName, appGroupIdentifier: appGroupIdentifier)
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let auditLogger = try await FileBackedAuditLogger(fileURL: paths.auditLogURL)
        let chatHistoryStore = try await JSONFileChatHistoryStore(fileURL: paths.chatHistoryStoreURL)
        let shareIngestionQueue = try await JSONFileShareIngestionQueue(fileURL: paths.shareIngestionQueueURL)
        let kairoRecipeStore = try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)
        let agentSkillStore = try await FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)
        let localModelCatalog = LocalModelCatalog.kairoDefault
        let localModelInstallRegistry = try await FileBackedLocalModelInstallRegistry(
            fileURL: paths.localModelInstallRegistryURL
        )
        let localModelSettingsStore = try await FileBackedLocalModelSettingsStore(
            fileURL: paths.localModelSettingsURL
        )
        let localModelSettingsService = LocalModelSettingsService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            settingsStore: localModelSettingsStore
        )
        let localModelDownloader = VerifiedLocalModelDownloader(
            installRegistry: localModelInstallRegistry,
            modelsDirectory: paths.localModelsDirectory
        )
        let localModelBenchmarkStore = try await FileBackedLocalModelBenchmarkStore(fileURL: paths.localModelBenchmarkResultsURL)
        #if os(macOS)
        let localModelCommandRuntime = LocalModelExternalCommandRuntime(
            configuration: .llamaCLI(
                executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/llama-cli")
            ),
            commandRunner: ProcessLocalModelCommandRunner()
        )
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore,
            engine: localModelCommandRuntime
        )
        let localModelReplyCheckService = LocalModelReplyCheckService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            runtime: localModelCommandRuntime
        )
        #else
        let localModelBenchmarkService = LocalModelBenchmarkService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry,
            resultStore: localModelBenchmarkStore
        )
        let localModelReplyCheckService = LocalModelReplyCheckService(
            catalog: localModelCatalog,
            installRegistry: localModelInstallRegistry
        )
        #endif
        let credentialStore = KeychainCredentialStore()
        let aiProvider = LocalModelRoutingAIProvider(
            cloudProvider: OpenAIProvider(credentialStore: credentialStore),
            localModelSettingsService: localModelSettingsService
        )
        let connectedOAuthProviderKeys = try await connectedOAuthProviderKeys(credentialStore: credentialStore)
        let runtimeContext = AgentSkillRuntimeContext.current(
            grantedEntitlements: [],
            connectedOAuthProviderKeys: connectedOAuthProviderKeys,
            installedLocalModelIDs: await localModelInstallRegistry.installedRecords().map(\.modelID)
        )
        let agentSkillManagerService = AgentSkillManagerService(
            store: agentSkillStore,
            builtInCatalog: .defaultWithMarketplaceSamples,
            runtimeContext: runtimeContext
        )
        let agentSkillMarketplaceCatalogService = AgentSkillMarketplaceCatalogService.defaultStandaloneRepository
        let localModelCatalogService = LocalModelCatalogService.defaultStandaloneRepository
        let oauthCallbackStore = try await FileBackedOAuthConnectorCallbackStore(fileURL: paths.oauthConnectorCallbackPreviewsURL)
        let actionExecutor: any ActionExecutor
        #if canImport(UserNotifications)
        actionExecutor = SandboxActionExecutor(
            memoryStore: memoryStore,
            notificationScheduler: UserNotificationScheduler(),
            auditLogger: auditLogger
        )
        #else
        actionExecutor = SandboxActionExecutor(memoryStore: memoryStore, auditLogger: auditLogger)
        #endif

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: aiProvider,
            chatHistoryStore: chatHistoryStore,
            shareIngestionQueue: shareIngestionQueue,
            kairoRecipeStore: kairoRecipeStore,
            permissionService: SystemPermissionService(),
            auditLogger: auditLogger,
            oauthConnectorCallbackStore: oauthCallbackStore,
            agentSkillManagerService: agentSkillManagerService,
            agentSkillMarketplaceCatalogService: agentSkillMarketplaceCatalogService,
            localModelCatalog: localModelCatalog,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelDownloader: localModelDownloader,
            localModelBenchmarkService: localModelBenchmarkService,
            localModelReplyCheckService: localModelReplyCheckService,
            actionExecutor: actionExecutor
        )
    }

    static func connectedOAuthProviderKeys(credentialStore: CredentialStore) async throws -> [String] {
        var providerKeys: [String] = []
        for integration in IntegrationRegistry().oauthConnectors {
            guard let providerKey = integration.oauth?.providerKey else { continue }
            guard let encoded = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: providerKey)) else {
                continue
            }
            if let tokenSet = try OAuthTokenSet.decodeStoredSecret(encoded),
               !tokenSet.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerKeys.append(providerKey)
            }
        }
        return Array(Set(providerKeys)).sorted()
    }
}

public struct KairoPaths: Sendable {
    public let appName: String
    public let appGroupIdentifier: String?
    private let appGroupContainerProvider: @Sendable (String) -> URL?

    public init(
        appName: String = "Kairo",
        appGroupIdentifier: String? = nil,
        appGroupContainerProvider: (@Sendable (String) -> URL?)? = nil
    ) {
        self.appName = appName
        self.appGroupIdentifier = appGroupIdentifier
        self.appGroupContainerProvider = appGroupContainerProvider ?? { identifier in
            Self.defaultAppGroupContainerURL(for: identifier)
        }
    }

    public var applicationSupportDirectory: URL {
        if let appGroupDirectory {
            return appGroupDirectory.appendingPathComponent(appName, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    public var appGroupDirectory: URL? {
        guard let appGroupIdentifier else { return nil }
        return appGroupContainerProvider(appGroupIdentifier)
    }

    public var usesAppGroup: Bool {
        appGroupDirectory != nil
    }

    public var memoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("memory-store.json")
    }

    public var auditLogURL: URL {
        applicationSupportDirectory.appendingPathComponent("audit-log.json")
    }

    public var chatHistoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("chat-history.json")
    }

    public var shareIngestionQueueURL: URL {
        applicationSupportDirectory.appendingPathComponent("share-ingestion-queue.json")
    }

    public var sharedFilesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("SharedFiles", isDirectory: true)
    }

    public var localModelsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("LocalModels", isDirectory: true)
    }

    public var localModelInstallRegistryURL: URL {
        localModelsDirectory.appendingPathComponent("install-registry.json")
    }

    public var localModelSettingsURL: URL {
        localModelsDirectory.appendingPathComponent("settings.json")
    }

    public var localModelBenchmarkResultsURL: URL {
        localModelsDirectory.appendingPathComponent("benchmarks.json")
    }

    public var kairoRecipesDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Recipes", isDirectory: true)
    }

    public var kairoRecipeStoreURL: URL {
        kairoRecipesDirectory.appendingPathComponent("kairo-recipes.json")
    }

    public var agentSkillsDirectory: URL {
        applicationSupportDirectory.appendingPathComponent("Skills", isDirectory: true)
    }

    public var agentSkillStoreURL: URL {
        agentSkillsDirectory.appendingPathComponent("agent-skills.json")
    }

    public var oauthConnectorCallbackPreviewsURL: URL {
        applicationSupportDirectory
            .appendingPathComponent("OAuth", isDirectory: true)
            .appendingPathComponent("callback-previews.json")
    }

    public static func defaultAppGroupContainerURL(for identifier: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
