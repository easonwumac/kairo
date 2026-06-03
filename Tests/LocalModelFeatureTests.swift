import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KairoCore

final class LocalModelFeatureTests: XCTestCase {
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

    func testDefaultLocalModelCatalogExposesPopularStarterModelsForSettings() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let localModelCatalogSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/LocalModelCatalog.swift"),
            encoding: .utf8
        )
        let catalog = LocalModelCatalog.kairoDefault
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)

        XCTAssertEqual(catalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertTrue(localModelCatalogSource.contains("static let kairoStarterModelIDs"))
        XCTAssertTrue(localModelCatalogSource.contains("kairoStarterModels"))
        XCTAssertEqual(availableModels.count, 2)
        XCTAssertEqual(availableModels.map(\.id), [
            "qwen3-5-0-8b-q4-k-m",
            "llama3-2-1b-instruct-q4-k-m"
        ])
        XCTAssertEqual(availableModels.map(\.displayName), [
            "Qwen3.5 0.8B Q4_K_M",
            "Llama 3.2 1B Instruct Q4_K_M"
        ])

        for model in availableModels {
            XCTAssertEqual(model.downloadURL.scheme, "https", model.id)
            XCTAssertEqual(model.downloadURL.host(), "huggingface.co", model.id)
            XCTAssertEqual(model.sha256.count, 64, model.id)
            XCTAssertLessThanOrEqual(model.minRAMGB, 6, model.id)
            XCTAssertEqual(model.runtime, .gguf, model.id)
            XCTAssertTrue(model.capabilities.contains(.offlineChat), model.id)
            XCTAssertTrue(model.disallowedCapabilities.contains(.webCurrentInfo), model.id)
            XCTAssertTrue(model.disallowedCapabilities.contains(.toolUse), model.id)
        }

        let qwenTiny = try XCTUnwrap(availableModels.first { $0.id == "qwen3-5-0-8b-q4-k-m" })
        let ggufBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .gguf })
        let mlxBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .mlx })
        XCTAssertEqual(ggufBenchmark.runtimePackage, "llama.cpp Metal")
        XCTAssertEqual(ggufBenchmark.promptTokens, 512)
        XCTAssertEqual(ggufBenchmark.generatedTokens, 128)
        XCTAssertEqual(ggufBenchmark.trials, 5)
        XCTAssertEqual(ggufBenchmark.promptTokensPerSecond, 8_810, accuracy: 0.1)
        XCTAssertEqual(ggufBenchmark.generationTokensPerSecond, 214, accuracy: 0.1)
        XCTAssertTrue(ggufBenchmark.supportsInAppDownload)
        XCTAssertTrue(ggufBenchmark.isReferenceOnlyForIOS)
        XCTAssertEqual(mlxBenchmark.runtimePackage, "mlx-lm")
        XCTAssertEqual(mlxBenchmark.artifactReference, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertEqual(mlxBenchmark.promptTokensPerSecond, 10_639, accuracy: 0.1)
        XCTAssertEqual(mlxBenchmark.generationTokensPerSecond, 286, accuracy: 0.1)
        XCTAssertEqual(mlxBenchmark.peakMemoryMB, 1_360)
        XCTAssertFalse(mlxBenchmark.supportsInAppDownload)
        XCTAssertTrue(mlxBenchmark.isReferenceOnlyForIOS)
        XCTAssertEqual(mlxBenchmark.sourceURL?.absoluteString, "https://huggingface.co/mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertEqual(qwenTiny.recommendedBenchmarkProfile?.runtime, .mlx)
        XCTAssertTrue(qwenTiny.benchmarkSummaryText?.contains("MLX ref 286 gen tok/s") == true)
        XCTAssertTrue(qwenTiny.benchmarkSummaryText?.contains("iPhone not verified") == true)

        XCTAssertFalse(availableModels.contains { $0.id == "smollm2-1-7b-instruct-q4-k-m" })
    }

    func testLocalModelManifestTransparencyTextIsCompactForSettingsList() throws {
        let qwenTiny = LocalModelManifest.qwen35Tiny
        let text = qwenTiny.manifestTransparencyText

        XCTAssertEqual(text, "huggingface.co · GGUF · Apache-2.0 · iOS 17.0/A15+/4 GB · SHA e8e3882 · policy 2026.1")
        XCTAssertFalse(text.contains("Source:"))
        XCTAssertFalse(text.contains("Runtime:"))
        XCTAssertFalse(text.contains("License:"))
        XCTAssertFalse(text.contains("Requires:"))
    }

    func testLocalModelRuntimePillsKeepDownloadAndMLXStatusReadable() throws {
        let qwenTiny = LocalModelManifest.qwen35Tiny
        let llamaTiny = LocalModelManifest.llama32OneBInstruct

        XCTAssertEqual(qwenTiny.runtimePillTexts, [
            "Download GGUF",
            "A15+/4 GB",
            "MLX ref only"
        ])
        XCTAssertEqual(llamaTiny.runtimePillTexts, [
            "Download GGUF",
            "A15+/4 GB",
            "Device test pending"
        ])
    }

    func testLocalModelCatalogServiceFetchesStandaloneModelRepoCatalog() async throws {
        let indexURL = URL(string: "https://easonwumac.github.io/kairo-models/models.json")!
        let body = remoteModelCatalogJSON(
            minimumSafetyPolicyVersion: "2026.2",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen3-5-0-8b-q4-k-m",
                    displayName: "Qwen3.5 0.8B Q4_K_M",
                    version: "1.1.0"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: body)
        let service = LocalModelCatalogService(indexURL: indexURL, httpClient: httpClient)

        let catalog = try await service.fetchCatalog()
        let request = try await httpClient.lastRequest()

        XCTAssertEqual(LocalModelCatalogService.defaultIndexURL.absoluteString, "https://easonwumac.github.io/kairo-models/models.json")
        XCTAssertEqual(request.url?.absoluteString, "https://easonwumac.github.io/kairo-models/models.json")
        XCTAssertEqual(catalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(catalog.minimumSafetyPolicyVersion, "2026.2")
        XCTAssertEqual(catalog.models.first?.runtime, .gguf)
        XCTAssertEqual(catalog.models.first?.version, "1.1.0")
        XCTAssertEqual(catalog.models.first?.benchmarkProfiles, [])
    }

    func testLocalModelCatalogServiceRejectsUnsafeRemoteModelDownloads() async throws {
        let body = remoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "unsafe-model",
                    displayName: "Unsafe Model",
                    downloadURL: "http://example.com/unsafe.gguf"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: body)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected unsafe model catalog to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .unsafeDownloadURL(modelID: "unsafe-model", url: "http://example.com/unsafe.gguf"))
        }
    }

    func testLocalModelCatalogMergesRemoteModelsWithoutDroppingBuiltInFallbacks() {
        let builtIn = LocalModelCatalog(
            generatedAt: Date(timeIntervalSince1970: 1),
            signingKeyID: "built-in",
            signature: "built-in-signature",
            sourceRepository: URL(string: "https://github.com/easonwumac/kairo"),
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "shared-model", version: "1.0", safetyPolicyVersion: "2026.1"),
                makeLocalModelManifest(id: "built-in-only", version: "1.0", safetyPolicyVersion: "2026.1")
            ]
        )
        let remote = LocalModelCatalog(
            generatedAt: Date(timeIntervalSince1970: 2),
            signingKeyID: "kairo-models-2026",
            signature: "remote-signature",
            sourceRepository: URL(string: "https://github.com/easonwumac/kairo-models"),
            minimumSafetyPolicyVersion: "2026.2",
            models: [
                makeLocalModelManifest(id: "shared-model", version: "2.0", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "remote-only", version: "1.0", safetyPolicyVersion: "2026.2")
            ]
        )

        let merged = builtIn.mergingRemoteCatalog(remote)

        XCTAssertEqual(merged.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(merged.signingKeyID, "kairo-models-2026")
        XCTAssertEqual(merged.minimumSafetyPolicyVersion, "2026.2")
        XCTAssertEqual(merged.models.map(\.id), ["shared-model", "built-in-only", "remote-only"])
        XCTAssertEqual(merged.models.first?.version, "2.0")
        XCTAssertEqual(merged.models.last?.id, "remote-only")
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

    func testFileBackedLocalModelSettingsStorePersistsSelectedModelAndPreference() async throws {
        let fileURL = temporaryFileURL(named: "local-model-settings.json")
        let firstStore = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let initialSettings = await firstStore.settings()
        XCTAssertNil(initialSettings.selectedModelID)
        XCTAssertEqual(initialSettings.preference, .automatic)

        try await firstStore.save(LocalModelSettings(
            selectedModelID: "qwen-small",
            preference: .preferLocal
        ))

        let secondStore = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let persisted = await secondStore.settings()
        XCTAssertEqual(persisted.selectedModelID, "qwen-small")
        XCTAssertEqual(persisted.preference, .preferLocal)
    }

    func testProviderRoutePreferenceBuildsSettingsCopyAndOrdering() {
        XCTAssertEqual(ProviderRoutePreference.settingsChoices, [
            .automatic,
            .preferLocal,
            .preferCloud,
            .localOnly
        ])
        XCTAssertEqual(ProviderRoutePreference.automatic.settingsTitle, "Automatic")
        XCTAssertEqual(ProviderRoutePreference.preferLocal.settingsTitle, "Prefer Local")
        XCTAssertEqual(ProviderRoutePreference.preferCloud.settingsTitle, "Prefer Cloud")
        XCTAssertEqual(ProviderRoutePreference.localOnly.settingsTitle, "Local Only")
        XCTAssertTrue(ProviderRoutePreference.localOnly.settingsDetailText.contains("Never routes"))
        XCTAssertTrue(ProviderRoutePreference.preferLocal.settingsDetailText.contains("eligible"))
    }

    func testChatProviderRouteStatusBuilderExplainsSelectedLocalModelAndWarnings() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let selectedStatus = ChatProviderRouteStatusBuilder.build(from: await service.status())

        XCTAssertEqual(selectedStatus.title, "Route: Prefer Local")
        XCTAssertEqual(selectedStatus.badge, "Local")
        XCTAssertTrue(selectedStatus.detail.contains("Selected local model: Qwen Small Test"))
        XCTAssertTrue(selectedStatus.detail.contains("tools and current info"))
        XCTAssertNil(selectedStatus.warning)

        let warningStatus = ChatProviderRouteStatusBuilder.build(from: LocalModelSettingsStatus(
            selectedModelID: nil,
            selectedModel: nil,
            installedRecord: nil,
            preference: .localOnly,
            availableModels: [makeLocalModelManifest(id: "qwen-small")],
            installedModels: []
        ))

        XCTAssertEqual(warningStatus.title, "Route: Local Only")
        XCTAssertEqual(warningStatus.badge, "Local only")
        XCTAssertEqual(warningStatus.warning, "Local Only is active but no downloaded model is selected.")
    }

    func testLocalModelRoutingAIProviderUsesSelectedLocalModelForEligiblePreferLocalWork() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: MockAIProvider(),
            localModelSettingsService: service
        )

        let response = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply for this message."
        ))

        XCTAssertTrue(response.message.contains("Local fallback (qwen-small)"))
        XCTAssertTrue(response.message.contains("local mode cannot browse the web"))
    }

    func testLocalModelRoutingAIProviderKeepsToolRequestsOnCloudWhenPreferLocal() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: MockAIProvider(),
            localModelSettingsService: service
        )

        let response = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Use HomeKit to turn on the living room light."
        ))

        XCTAssertTrue(response.message.contains("mock 回應"))
        XCTAssertFalse(response.message.contains("Local fallback"))
    }

    func testLocalModelRoutingAIProviderFailsClosedWhenLocalOnlyHasNoModel() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .localOnly,
            installedAndSelectedModelID: nil
        )
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: MockAIProvider(),
            localModelSettingsService: service
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply."
        ))) { error in
            XCTAssertEqual(error as? AIProviderError, .unsupported)
        }
    }

    func testLocalModelSettingsServiceSelectsInstalledModelAndBuildsRoutingContext() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-small.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "old-policy", safetyPolicyVersion: "2025.9")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        try await service.setPreference(.preferLocal)
        try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertEqual(status.selectedModelID, "qwen-small")
        XCTAssertEqual(status.selectedModel?.id, "qwen-small")
        XCTAssertEqual(status.installedRecord?.fileURL, modelURL)
        XCTAssertEqual(status.installedModels.map(\.modelID), ["qwen-small"])
        XCTAssertEqual(status.availableModels.map(\.id), ["qwen-small"])

        let context = await service.routingContext(
            taskClass: .summarization,
            networkAvailable: false,
            minimumSafetyPolicyVersion: "2026.1"
        )
        XCTAssertEqual(context.preference, .preferLocal)
        XCTAssertFalse(context.networkAvailable)
        XCTAssertEqual(context.taskClass, .summarization)
        XCTAssertTrue(context.localModelInstalled)
        XCTAssertEqual(context.localContextWindow, 2048)
    }

    func testLocalModelSettingsServiceDeletesInstalledModelFileRecordAndSelection() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-small.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
            ]
        )
        try FileManager.default.createDirectory(at: modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("model-bytes".utf8).write(to: modelURL)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)
        try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")

        try await service.deleteModel(id: "qwen-small")

        XCTAssertFalse(FileManager.default.fileExists(atPath: modelURL.path))
        let deletedRecord = await registry.record(for: "qwen-small")
        XCTAssertNil(deletedRecord)
        let settings = await store.settings()
        XCTAssertNil(settings.selectedModelID)
        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.localModelInstalled)
    }

    func testLocalModelSettingsServiceRejectsUninstalledOrUnavailableSelections() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "deprecated", safetyPolicyVersion: "2026.2", deprecated: true)
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        do {
            try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")
            XCTFail("Expected uninstalled model selection to fail")
        } catch let error as LocalModelSelectionError {
            XCTAssertEqual(error, .modelNotInstalled("qwen-small"))
        }

        do {
            try await service.selectModel(id: "deprecated", minimumSafetyPolicyVersion: "2026.1")
            XCTFail("Expected unavailable model selection to fail")
        } catch let error as LocalModelSelectionError {
            XCTAssertEqual(error, .modelUnavailable("deprecated"))
        }

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.localModelInstalled)
    }

    func testLocalModelBenchmarkServiceRequiresDownloadedModelBeforeRunning() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let resultStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let service = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: resultStore,
            engine: DeterministicLocalModelBenchmarkEngine(
                runtime: .gguf,
                generationTokensPerSecond: 43,
                promptTokensPerSecond: 120
            )
        )

        do {
            _ = try await service.runBenchmark(
                modelID: "qwen3-5-0-8b-q4-k-m",
                prompt: "Benchmark Kairo local drafting.",
                generatedTokenTarget: 64
            )
            XCTFail("Expected benchmark to require a downloaded local model.")
        } catch let error as LocalModelBenchmarkError {
            XCTAssertEqual(error, .modelNotInstalled("qwen3-5-0-8b-q4-k-m"))
        }

        let persisted = await resultStore.latestResult(for: "qwen3-5-0-8b-q4-k-m")
        XCTAssertNil(persisted)
    }

    func testLocalModelBenchmarkServiceRunsInstalledQwenThroughInjectedEngineAndPersistsResult() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let resultStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let service = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: resultStore,
            engine: DeterministicLocalModelBenchmarkEngine(
                runtime: .gguf,
                generationTokensPerSecond: 43.5,
                promptTokensPerSecond: 121.3,
                peakMemoryMB: 980
            )
        )

        let result = try await service.runBenchmark(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Benchmark Kairo local drafting.",
            generatedTokenTarget: 64
        )

        XCTAssertEqual(result.modelID, "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(result.runtime, .gguf)
        XCTAssertEqual(result.promptTokens, 32)
        XCTAssertEqual(result.generatedTokens, 64)
        XCTAssertEqual(result.promptTokensPerSecond, 121.3)
        XCTAssertEqual(result.generationTokensPerSecond, 43.5)
        XCTAssertEqual(result.peakMemoryMB, 980)
        XCTAssertFalse(result.isReferenceOnlyForIOS)
        XCTAssertTrue(result.summaryText.contains("43.5 gen tok/s"))
        XCTAssertTrue(result.summaryText.contains("121.3 prompt tok/s"))

        let latestResult = await resultStore.latestResult(for: "qwen3-5-0-8b-q4-k-m")
        let persisted = try XCTUnwrap(latestResult)
        XCTAssertEqual(persisted, result)
        let reloadedStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let reloadedResult = await reloadedStore.latestResult(for: "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(reloadedResult, result)
    }

    func testLocalModelReplyCheckRequiresDownloadedModelBeforeRunning() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let service = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: DeterministicLocalModelReplyCheckRuntime(
                responseText: "Local model reply is alive.",
                generationTokensPerSecond: 38
            )
        )

        do {
            _ = try await service.runReplyCheck(
                modelID: "qwen3-5-0-8b-q4-k-m",
                prompt: "Reply with one sentence."
            )
            XCTFail("Expected reply check to require a downloaded local model.")
        } catch let error as LocalModelReplyCheckError {
            XCTAssertEqual(error, .modelNotInstalled("qwen3-5-0-8b-q4-k-m"))
        }
    }

    func testLocalModelReplyCheckRunsInstalledQwenThroughInjectedRuntime() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let service = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: DeterministicLocalModelReplyCheckRuntime(
                responseText: "Local model reply is alive.",
                generationTokensPerSecond: 38.5
            )
        )

        let result = try await service.runReplyCheck(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Reply with one sentence."
        )

        XCTAssertEqual(result.modelID, "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(result.modelDisplayName, "Qwen3.5 0.8B Q4_K_M")
        XCTAssertEqual(result.runtime, .gguf)
        XCTAssertEqual(result.responseText, "Local model reply is alive.")
        XCTAssertEqual(result.generationTokensPerSecond, 38.5)
        XCTAssertTrue(result.summaryText.contains("38.5 gen tok/s"))
        XCTAssertTrue(result.summaryText.contains("Local model reply is alive."))
    }

    func testLocalModelSettingsStatusBuildsSettingsRowsForDownloadSelectAndSelected() throws {
        let selectedManifest = makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
        let downloadableManifest = makeLocalModelManifest(id: "llama-draft", safetyPolicyVersion: "2026.2")
        let installedRecord = LocalModelInstallRecord(
            modelID: selectedManifest.id,
            version: selectedManifest.version,
            status: .installed,
            fileURL: URL(fileURLWithPath: "/tmp/qwen-small.gguf"),
            installedSizeBytes: selectedManifest.installedSizeBytes,
            sha256: selectedManifest.sha256
        )
        let status = LocalModelSettingsStatus(
            selectedModelID: selectedManifest.id,
            selectedModel: selectedManifest,
            installedRecord: installedRecord,
            preference: .preferLocal,
            availableModels: [selectedManifest, downloadableManifest],
            installedModels: [installedRecord]
        )

        let rows = status.settingsRows
        let selectedRow = try XCTUnwrap(rows.first { $0.modelID == selectedManifest.id })
        let downloadableRow = try XCTUnwrap(rows.first { $0.modelID == downloadableManifest.id })

        XCTAssertEqual(rows.map(\.modelID), [selectedManifest.id, downloadableManifest.id])
        XCTAssertEqual(selectedRow.statusText, "已選用")
        XCTAssertEqual(selectedRow.primaryAction, .selected)
        XCTAssertEqual(downloadableRow.statusText, "可下載")
        XCTAssertEqual(downloadableRow.primaryAction, .download)
        XCTAssertTrue(selectedRow.canDelete)
        XCTAssertFalse(downloadableRow.canDelete)
        XCTAssertTrue(selectedRow.detailText.contains("0.8B"))
        XCTAssertTrue(selectedRow.detailText.contains("Q4"))
        XCTAssertTrue(selectedRow.detailText.contains("2K ctx"))
        XCTAssertFalse(selectedRow.detailText.contains("download"))
        XCTAssertFalse(selectedRow.detailText.contains("Apache"))
        XCTAssertNil(downloadableRow.benchmarkSummaryText)
    }

    func testLocalModelSettingsRowBuildsManifestTransparencyText() throws {
        let row = LocalModelSettingsRow(
            model: LocalModelManifest.qwen35Tiny,
            installRecord: nil,
            isSelected: false
        )

        XCTAssertEqual(
            row.manifestTransparencyText,
            "huggingface.co · GGUF · Apache-2.0 · iOS 17.0/A15+/4 GB · SHA e8e3882 · policy 2026.1"
        )
        XCTAssertEqual(
            row.runtimeFitText,
            "Download: GGUF · Fit: A15+/4 GB · MLX ref only"
        )
    }

    func testLocalModelSettingsRowsPreserveCatalogOrderForEqualActions() {
        let qwenManifest = makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
        let llamaManifest = makeLocalModelManifest(id: "llama-draft", safetyPolicyVersion: "2026.2")
        let smolManifest = makeLocalModelManifest(id: "smollm-draft", safetyPolicyVersion: "2026.2")
        let status = LocalModelSettingsStatus(
            selectedModelID: nil,
            selectedModel: nil,
            installedRecord: nil,
            preference: .automatic,
            availableModels: [qwenManifest, llamaManifest, smolManifest],
            installedModels: []
        )

        XCTAssertEqual(status.settingsRows.map(\.modelID), [
            qwenManifest.id,
            llamaManifest.id,
            smolManifest.id
        ])
    }

    func testVerifiedLocalModelDownloaderInstallsModelAndUpdatesRegistry() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: "model-bytes")
        let downloader = VerifiedLocalModelDownloader(
            httpClient: httpClient,
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let installedURL = try await downloader.download(manifest, progress: nil)

        XCTAssertEqual(installedURL.lastPathComponent, "qwen-small-1.0.gguf")
        XCTAssertEqual(try String(contentsOf: installedURL, encoding: .utf8), "model-bytes")
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.url, manifest.downloadURL)
        let record = await registry.record(for: manifest.id)
        XCTAssertEqual(record?.status, .installed)
        XCTAssertEqual(record?.fileURL, installedURL)
        XCTAssertEqual(record?.installedSizeBytes, Int64("model-bytes".utf8.count))
        XCTAssertEqual(record?.sha256, manifest.sha256)
        XCTAssertNotNil(record?.lastVerifiedAt)
    }

    func testVerifiedLocalModelDownloaderFailsClosedWhenChecksumDoesNotMatch() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelMockHTTPClient(statusCode: 200, body: "wrong-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        do {
            _ = try await downloader.download(manifest, progress: nil)
            XCTFail("Expected checksum mismatch")
        } catch let error as LocalModelDownloadError {
            XCTAssertEqual(
                error,
                .checksumMismatch(
                    expected: manifest.sha256,
                    actual: "7c1d387f892b3c965dfc1951e2a92a2149cd103cef25c8ba5d0cc30a3a21063f"
                )
            )
        }

        let record = await registry.record(for: manifest.id)
        XCTAssertEqual(record?.status, .failed)
        XCTAssertTrue(record?.failureReason?.contains("Checksum mismatch") == true)
        XCTAssertTrue((try? FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil))?.isEmpty ?? true)
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

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func makeLocalModelSettingsService(
        preference: ProviderRoutePreference,
        installedAndSelectedModelID: String?
    ) async throws -> LocalModelSettingsService {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.1")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        if let modelID = installedAndSelectedModelID {
            try await registry.upsert(LocalModelInstallRecord(
                modelID: modelID,
                version: "1.0",
                status: .installed,
                fileURL: registryURL.deletingLastPathComponent().appendingPathComponent("\(modelID).gguf"),
                installedSizeBytes: 1024,
                sha256: "abc123"
            ))
            try await service.selectModel(id: modelID)
        }
        try await service.setPreference(preference)
        return service
    }

    private func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ errorHandler: (Error) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected async expression to throw.", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    private func makeLocalModelManifest(
        id: String,
        version: String = "1.0",
        safetyPolicyVersion: String = "2026.1",
        deprecated: Bool = false,
        sha256: String = "abc123"
    ) -> LocalModelManifest {
        LocalModelManifest(
            id: id,
            displayName: "Qwen Small Test",
            family: "Qwen",
            version: version,
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
            sha256: sha256,
            safetyPolicyVersion: safetyPolicyVersion,
            deprecated: deprecated
        )
    }

    private func remoteModelCatalogJSON(
        minimumSafetyPolicyVersion: String = "2026.1",
        modelsJSON: [String]
    ) -> String {
        """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-06-02T00:00:00Z",
          "signingKeyID": "kairo-models-2026",
          "signature": "signed-catalog-placeholder",
          "sourceRepository": "https://github.com/easonwumac/kairo-models",
          "minimumSafetyPolicyVersion": "\(minimumSafetyPolicyVersion)",
          "models": [
            \(modelsJSON.joined(separator: ",\n"))
          ]
        }
        """
    }

    private func remoteModelManifestJSON(
        id: String,
        displayName: String,
        version: String = "1.0.0",
        downloadURL: String = "https://huggingface.co/example/model/resolve/main/model.gguf"
    ) -> String {
        """
        {
          "id": "\(id)",
          "displayName": "\(displayName)",
          "family": "Qwen",
          "version": "\(version)",
          "parameterCount": "0.8B",
          "quantization": "Q4_K_M",
          "runtime": "gguf",
          "fileSizeBytes": 512,
          "installedSizeBytes": 1024,
          "contextWindow": 2048,
          "tokenizerID": "qwen-test-tokenizer",
          "licenseName": "Apache-2.0",
          "licenseURL": "https://example.com/license",
          "minOSVersion": "17.0",
          "minDeviceClass": "A15",
          "minRAMGB": 4,
          "supportedLocales": ["en", "zh-Hant"],
          "capabilities": ["drafts", "summarization", "simpleQuestionAnswer", "offlineChat"],
          "disallowedCapabilities": ["toolUse", "webCurrentInfo", "codeExecution", "accountActions", "regulatedAdvice"],
          "downloadURL": "\(downloadURL)",
          "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "createdAt": "2026-06-02T00:00:00Z",
          "updatedAt": "2026-06-02T00:00:00Z",
          "safetyPolicyVersion": "2026.1",
          "deprecated": false
        }
        """
    }
}

private actor LocalModelMockHTTPClient: HTTPClient {
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
            throw LocalModelMockHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private enum LocalModelMockHTTPClientError: Error {
    case missingRequest
}
