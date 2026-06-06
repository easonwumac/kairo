import CryptoKit
import Foundation

private enum KairoUITestingLocalModelFactoryError: Error {
    case invalidRemoteCatalogModelURL
}

public struct KairoUITestingLocalModelComponents: Sendable {
    public var catalog: LocalModelCatalog
    public var catalogService: LocalModelCatalogService
    public var settingsService: LocalModelSettingsService
    public var downloader: any LocalModelDownloader
    public var benchmarkService: LocalModelBenchmarkService
    public var replyCheckService: LocalModelReplyCheckService
    public var aiProvider: any AIProvider
    public var chatRuntimeAvailable: Bool

    public init(
        catalog: LocalModelCatalog,
        catalogService: LocalModelCatalogService,
        settingsService: LocalModelSettingsService,
        downloader: any LocalModelDownloader,
        benchmarkService: LocalModelBenchmarkService,
        replyCheckService: LocalModelReplyCheckService,
        aiProvider: any AIProvider,
        chatRuntimeAvailable: Bool
    ) {
        self.catalog = catalog
        self.catalogService = catalogService
        self.settingsService = settingsService
        self.downloader = downloader
        self.benchmarkService = benchmarkService
        self.replyCheckService = replyCheckService
        self.aiProvider = aiProvider
        self.chatRuntimeAvailable = chatRuntimeAvailable
    }
}

public struct KairoUITestingLocalModelFactory: Sendable {
    public var rootDirectory: URL
    public var seedInstalledLocalModel: Bool
    public var seedExpandedLocalModelCatalog: Bool
    public var selectInstalledLocalModel: Bool
    public var routePreference: ProviderRoutePreference?
    public var installedLocalModelFileURL: URL?
    public var replyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)?
    public var benchmarkEngineOverride: (any LocalModelBenchmarkEngine)?

    public init(
        rootDirectory: URL,
        seedInstalledLocalModel: Bool = false,
        seedExpandedLocalModelCatalog: Bool = false,
        selectInstalledLocalModel: Bool = false,
        routePreference: ProviderRoutePreference? = nil,
        installedLocalModelFileURL: URL? = nil,
        replyCheckRuntimeOverride: (any LocalModelReplyCheckRuntime)? = nil,
        benchmarkEngineOverride: (any LocalModelBenchmarkEngine)? = nil
    ) {
        self.rootDirectory = rootDirectory
        self.seedInstalledLocalModel = seedInstalledLocalModel
        self.seedExpandedLocalModelCatalog = seedExpandedLocalModelCatalog
        self.selectInstalledLocalModel = selectInstalledLocalModel
        self.routePreference = routePreference
        self.installedLocalModelFileURL = installedLocalModelFileURL
        self.replyCheckRuntimeOverride = replyCheckRuntimeOverride
        self.benchmarkEngineOverride = benchmarkEngineOverride
    }

    public func makeComponents() async throws -> KairoUITestingLocalModelComponents {
        let catalog = try makeCatalog()
        let catalogService = try Self.makeCatalogService(catalog: catalog)
        let installRegistry = try await FileBackedLocalModelInstallRegistry(
            fileURL: localModelsDirectory.appendingPathComponent("install-registry.json")
        )
        if seedInstalledLocalModel {
            try await seedInstalledModel(in: installRegistry)
        }
        let settingsStore = try await FileBackedLocalModelSettingsStore(
            fileURL: localModelsDirectory.appendingPathComponent("settings.json")
        )
        let settingsService = LocalModelSettingsService(
            catalog: catalog,
            installRegistry: installRegistry,
            settingsStore: settingsStore
        )
        let downloader = KairoUITestingLocalModelDownloader(
            installRegistry: installRegistry,
            modelsDirectory: localModelsDirectory
        )
        if selectInstalledLocalModel {
            try await settingsService.selectModel(id: LocalModelManifest.qwen25HalfBInstruct.id)
        }
        if let routePreference {
            try await settingsService.setPreference(routePreference)
        }
        let benchmarkStore = try await FileBackedLocalModelBenchmarkStore(
            fileURL: localModelsDirectory.appendingPathComponent("benchmarks.json")
        )
        let inferenceCacheStore = try await FileBackedLocalModelInferenceCacheStore(
            directoryURL: localModelsDirectory.appendingPathComponent("InferenceCache", isDirectory: true)
        )
        let benchmarkService = LocalModelBenchmarkService(
            catalog: catalog,
            installRegistry: installRegistry,
            resultStore: benchmarkStore,
            inferenceCacheStore: inferenceCacheStore,
            engine: benchmarkEngineOverride ?? UnavailableLocalModelBenchmarkEngine()
        )
        let usesLocalModelRoute = seedInstalledLocalModel
            || selectInstalledLocalModel
            || routePreference == .localOnly
            || routePreference == .preferLocal
        let replyRuntime: any LocalModelReplyCheckRuntime = replyCheckRuntimeOverride
            ?? (usesLocalModelRoute
                ? UnavailableLocalModelReplyCheckRuntime()
                : DeterministicLocalModelReplyCheckRuntime(
                    responseText: "Local model reply is alive.",
                    generationTokensPerSecond: 38.5
                ))
        let replyCheckService = LocalModelReplyCheckService(
            catalog: catalog,
            installRegistry: installRegistry,
            runtime: replyRuntime
        )
        let aiProvider: any AIProvider
        if usesLocalModelRoute || replyCheckRuntimeOverride != nil {
            aiProvider = LocalModelRoutingAIProvider(
                cloudProvider: MockAIProvider(),
                localModelSettingsService: settingsService,
                localProvider: LocalModelRuntimeAIProvider(
                    localModelSettingsService: settingsService,
                    runtime: replyRuntime
                ),
                localRuntimeAvailable: replyCheckRuntimeOverride != nil
            )
        } else {
            aiProvider = MockAIProvider()
        }

        return KairoUITestingLocalModelComponents(
            catalog: catalog,
            catalogService: catalogService,
            settingsService: settingsService,
            downloader: downloader,
            benchmarkService: benchmarkService,
            replyCheckService: replyCheckService,
            aiProvider: aiProvider,
            chatRuntimeAvailable: replyCheckRuntimeOverride != nil
        )
    }

    private var localModelsDirectory: URL {
        rootDirectory.appendingPathComponent("LocalModels", isDirectory: true)
    }

    private func makeCatalog() throws -> LocalModelCatalog {
        guard seedExpandedLocalModelCatalog else {
            return .kairoDefault
        }
        return try LocalModelCatalog.kairoDefault.mergingRemoteCatalog(LocalModelCatalog(
            generatedAt: Date(timeIntervalSince1970: 1_767_225_600),
            signingKeyID: "kairo-ui-testing-expanded-local-models",
            signature: "unsigned-ui-testing-placeholder",
            sourceRepository: URL(string: "https://github.com/easonwumac/kairo-models"),
            minimumSafetyPolicyVersion: LocalModelCatalog.kairoDefault.minimumSafetyPolicyVersion,
            models: [Self.remoteCatalogModel()]
        ))
    }

    private func seedInstalledModel(in installRegistry: FileBackedLocalModelInstallRegistry) async throws {
        let defaultInstalledModelURL = localModelsDirectory.appendingPathComponent("qwen2-5-0-5b-instruct-q4-k-m.gguf")
        let installedModelURL: URL
        if let installedLocalModelFileURL {
            try FileManager.default.createDirectory(
                at: defaultInstalledModelURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if FileManager.default.fileExists(atPath: defaultInstalledModelURL.path) {
                try FileManager.default.removeItem(at: defaultInstalledModelURL)
            }
            try FileManager.default.copyItem(at: installedLocalModelFileURL, to: defaultInstalledModelURL)
            installedModelURL = defaultInstalledModelURL
        } else {
            installedModelURL = defaultInstalledModelURL
        }
        try await installRegistry.upsert(LocalModelInstallRecord(
            modelID: LocalModelManifest.qwen25HalfBInstruct.id,
            version: LocalModelManifest.qwen25HalfBInstruct.version,
            status: .installed,
            fileURL: installedModelURL,
            installedSizeBytes: LocalModelManifest.qwen25HalfBInstruct.installedSizeBytes,
            sha256: LocalModelManifest.qwen25HalfBInstruct.sha256
        ))
    }

    private static func remoteCatalogModel() throws -> LocalModelManifest {
        guard let licenseURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0"),
              let downloadURL = URL(string: "https://example.com/kairo/remote-catalog-test-model-q4_k_m.gguf")
        else {
            throw KairoUITestingLocalModelFactoryError.invalidRemoteCatalogModelURL
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

    private static func makeCatalogService(catalog: LocalModelCatalog = .kairoDefault) throws -> LocalModelCatalogService {
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
}

private actor KairoUITestingLocalModelDownloader: LocalModelDownloader {
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let modelsDirectory: URL

    init(
        installRegistry: FileBackedLocalModelInstallRegistry,
        modelsDirectory: URL
    ) {
        self.installRegistry = installRegistry
        self.modelsDirectory = modelsDirectory
    }

    func download(_ manifest: LocalModelManifest, progress: (@Sendable (Double) -> Void)?) async throws -> URL {
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let destinationURL = modelsDirectory.appendingPathComponent("\(manifest.id)-ui-testing.gguf")
        progress?(0.15)
        try await installRegistry.upsert(LocalModelInstallRecord(
            modelID: manifest.id,
            version: manifest.version,
            status: .downloading,
            fileURL: destinationURL,
            installedSizeBytes: 0,
            sha256: manifest.sha256
        ))

        try await Task.sleep(for: .milliseconds(120))
        progress?(0.65)
        let placeholder = Data("kairo-ui-testing-local-model-\(manifest.id)".utf8)
        try placeholder.write(to: destinationURL, options: [.atomic])
        try await installRegistry.upsert(LocalModelInstallRecord(
            modelID: manifest.id,
            version: manifest.version,
            status: .installed,
            fileURL: destinationURL,
            installedSizeBytes: Int64(placeholder.count),
            sha256: manifest.sha256,
            lastVerifiedAt: Date()
        ))
        progress?(1.0)
        return destinationURL
    }
}
