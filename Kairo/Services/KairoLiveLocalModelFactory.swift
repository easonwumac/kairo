import Foundation

public struct KairoLiveLocalModelComponents: Sendable {
    public var catalog: LocalModelCatalog
    public var catalogService: LocalModelCatalogService
    public var settingsService: LocalModelSettingsService
    public var downloader: any LocalModelDownloader
    public var benchmarkService: LocalModelBenchmarkService
    public var replyCheckService: LocalModelReplyCheckService
    public var aiProvider: any AIProvider
    public var chatRuntimeAvailable: Bool
    public var installedModelIDs: [String]

    public init(
        catalog: LocalModelCatalog,
        catalogService: LocalModelCatalogService,
        settingsService: LocalModelSettingsService,
        downloader: any LocalModelDownloader,
        benchmarkService: LocalModelBenchmarkService,
        replyCheckService: LocalModelReplyCheckService,
        aiProvider: any AIProvider,
        chatRuntimeAvailable: Bool,
        installedModelIDs: [String]
    ) {
        self.catalog = catalog
        self.catalogService = catalogService
        self.settingsService = settingsService
        self.downloader = downloader
        self.benchmarkService = benchmarkService
        self.replyCheckService = replyCheckService
        self.aiProvider = aiProvider
        self.chatRuntimeAvailable = chatRuntimeAvailable
        self.installedModelIDs = installedModelIDs
    }
}

public struct KairoLiveLocalModelFactory: Sendable {
    public var paths: KairoPaths
    public var credentialStore: any CredentialStore
    public var replyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)?
    public var benchmarkEngineOverride: (any LocalModelBenchmarkEngine)?

    public init(
        paths: KairoPaths,
        credentialStore: any CredentialStore,
        replyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        benchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
        self.replyCheckRuntimeOverride = replyCheckRuntimeOverride
        self.benchmarkEngineOverride = benchmarkEngineOverride
    }

    public func makeComponents() async throws -> KairoLiveLocalModelComponents {
        let catalog = LocalModelCatalog.kairoDefault
        let installRegistry = try await FileBackedLocalModelInstallRegistry(
            fileURL: paths.localModelInstallRegistryURL
        )
        let settingsStore = try await FileBackedLocalModelSettingsStore(
            fileURL: paths.localModelSettingsURL
        )
        let settingsService = LocalModelSettingsService(
            catalog: catalog,
            installRegistry: installRegistry,
            settingsStore: settingsStore
        )
        let downloader = VerifiedLocalModelDownloader(
            installRegistry: installRegistry,
            modelsDirectory: paths.localModelsDirectory
        )
        let benchmarkStore = try await FileBackedLocalModelBenchmarkStore(
            fileURL: paths.localModelBenchmarkResultsURL
        )
        let runtimeBundle = makeRuntimeBundle()
        let benchmarkService = LocalModelBenchmarkService(
            catalog: catalog,
            installRegistry: installRegistry,
            resultStore: benchmarkStore,
            engine: benchmarkEngineOverride ?? runtimeBundle.benchmarkEngine
        )
        let replyCheckService = LocalModelReplyCheckService(
            catalog: catalog,
            installRegistry: installRegistry,
            runtime: runtimeBundle.replyRuntime
        )
        let aiProvider = LocalModelRoutingAIProvider(
            cloudProvider: OpenAIProvider(credentialStore: credentialStore),
            localModelSettingsService: settingsService,
            localProvider: LocalModelRuntimeAIProvider(
                localModelSettingsService: settingsService,
                runtime: runtimeBundle.replyRuntime
            ),
            localRuntimeAvailable: runtimeBundle.chatRuntimeAvailable
        )

        return KairoLiveLocalModelComponents(
            catalog: catalog,
            catalogService: .defaultStandaloneRepository,
            settingsService: settingsService,
            downloader: downloader,
            benchmarkService: benchmarkService,
            replyCheckService: replyCheckService,
            aiProvider: aiProvider,
            chatRuntimeAvailable: runtimeBundle.chatRuntimeAvailable,
            installedModelIDs: await installRegistry.installedRecords().map(\.modelID)
        )
    }

    private func makeRuntimeBundle() -> LocalModelRuntimeBundle {
        #if os(macOS)
        let commandRuntime = LocalModelExternalCommandRuntime(
            configuration: .llamaCLI(
                executableURL: URL(fileURLWithPath: "/opt/homebrew/bin/llama-cli")
            ),
            commandRunner: ProcessLocalModelCommandRunner()
        )
        return LocalModelRuntimeBundle(
            replyRuntime: replyCheckRuntimeOverride ?? commandRuntime,
            benchmarkEngine: benchmarkEngineOverride ?? commandRuntime,
            chatRuntimeAvailable: true
        )
        #else
        return LocalModelRuntimeBundle(
            replyRuntime: replyCheckRuntimeOverride ?? UnavailableLocalModelReplyCheckRuntime(),
            benchmarkEngine: benchmarkEngineOverride ?? UnavailableLocalModelBenchmarkEngine(),
            chatRuntimeAvailable: replyCheckRuntimeOverride != nil
        )
        #endif
    }
}

private struct LocalModelRuntimeBundle: Sendable {
    var replyRuntime: any LocalModelReplyCheckRuntime
    var benchmarkEngine: any LocalModelBenchmarkEngine
    var chatRuntimeAvailable: Bool
}
