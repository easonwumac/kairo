import XCTest
import Foundation
import CryptoKit
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
        let signedCatalog = try signedRemoteModelCatalogJSON(
            minimumSafetyPolicyVersion: "2026.2",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen3-5-0-8b-q4-k-m",
                    displayName: "Qwen3.5 0.8B Q4_K_M",
                    version: "1.1.0"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: indexURL,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

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
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "unsafe-model",
                    displayName: "Unsafe Model",
                    downloadURL: "http://example.com/unsafe.gguf"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected unsafe model catalog to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .unsafeDownloadURL(modelID: "unsafe-model", url: "http://example.com/unsafe.gguf"))
        }
    }

    func testLocalModelCatalogServiceRejectsInvalidCatalogSignature() async throws {
        var signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        signedCatalog.json = signedCatalog.json.replacingOccurrences(of: "Qwen Small", with: "Tampered Qwen")
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected invalid catalog signature to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .invalidSignature)
        }
    }

    func testLocalModelCatalogServiceRejectsCatalogWhenSigningKeyIsUnknown() async throws {
        let body = remoteModelCatalogJSON(
            signingKeyID: "unknown-key",
            signature: "signed-catalog-placeholder",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: body)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: LocalModelCatalogTrustStore(
                trustedKeys: [
                    LocalModelTrustedSigningKey(
                        keyID: "release-2026-q2",
                        algorithm: "p256-sha256",
                        status: .active
                    )
                ]
            )
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected unknown signing key to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .unknownSigningKey("unknown-key"))
        }
    }

    func testLocalModelCatalogServiceRejectsCatalogWhenSigningKeyIsRevoked() async throws {
        let body = remoteModelCatalogJSON(
            signingKeyID: "release-2026-q1",
            signature: "signed-catalog-placeholder",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: body)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: LocalModelCatalogTrustStore(
                trustedKeys: [
                    LocalModelTrustedSigningKey(
                        keyID: "release-2026-q1",
                        algorithm: "p256-sha256",
                        status: .revoked
                    ),
                    LocalModelTrustedSigningKey(
                        keyID: "release-2026-q2",
                        algorithm: "p256-sha256",
                        status: .active
                    )
                ]
            )
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected revoked signing key to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .revokedSigningKey("release-2026-q1"))
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

    func testLocalModelRoutingAIProviderDoesNotCallCloudWhenLocalOnlyHasNoModel() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .localOnly,
            installedAndSelectedModelID: nil
        )
        let cloudProvider = RecordingAIProvider()
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: cloudProvider,
            localModelSettingsService: service
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply."
        ))) { error in
            XCTAssertEqual(error as? AIProviderError, .unsupported)
        }

        let completionCallCount = await cloudProvider.completionCallCount
        XCTAssertEqual(completionCallCount, 0)
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

    func testLocalModelBenchmarkServiceSurfacesRuntimeUnavailableReason() async throws {
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
            engine: UnavailableLocalModelBenchmarkEngine(reason: "Runtime not shipped in this beta.")
        )

        do {
            _ = try await service.runBenchmark(modelID: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected unavailable runtime to fail closed.")
        } catch let error as LocalModelBenchmarkError {
            XCTAssertEqual(error, .runtimeUnavailable("Runtime not shipped in this beta."))
        }
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

    func testLocalModelReplyCheckSurfacesRuntimeUnavailableReason() async throws {
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
            runtime: UnavailableLocalModelReplyCheckRuntime(reason: "Runtime not shipped in this beta.")
        )

        do {
            _ = try await service.runReplyCheck(modelID: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected unavailable reply runtime to fail closed.")
        } catch let error as LocalModelReplyCheckError {
            XCTAssertEqual(error, .runtimeUnavailable("Runtime not shipped in this beta."))
        }
    }

    func testLocalModelExternalCommandRuntimeRunsDownloadedQwenThroughLlamaCLI() async throws {
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
        let commandRunner = LocalModelFakeCommandRunner(result: LocalModelCommandRunResult(
            stdout: "Local model reply is alive.\n",
            stderr: """
            llama_perf_context_print: prompt eval time = 80.00 ms / 16 tokens (5.00 ms per token, 200.00 tokens per second)
            llama_perf_context_print: eval time = 1200.00 ms / 48 runs (25.00 ms per token, 40.00 tokens per second)
            """,
            exitCode: 0,
            durationSeconds: 1.2
        ))
        let runtime = LocalModelExternalCommandRuntime(
            configuration: .llamaCLI(
                executableURL: URL(fileURLWithPath: "/tmp/llama-cli"),
                defaultGeneratedTokenTarget: 48
            ),
            commandRunner: commandRunner
        )
        let replyService = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: runtime
        )

        let reply = try await replyService.runReplyCheck(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Reply with one sentence."
        )

        XCTAssertEqual(reply.modelID, "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(reply.runtime, .gguf)
        XCTAssertEqual(reply.runtimePackage, "llama.cpp CLI")
        XCTAssertEqual(reply.responseText, "Local model reply is alive.")
        XCTAssertEqual(reply.generatedTokens, 48)
        XCTAssertEqual(reply.generationTokensPerSecond, 40, accuracy: 0.1)
        XCTAssertTrue(reply.notes.contains("does not bundle weights"))

        let firstInvocation = try await commandRunner.invocation(at: 0)
        XCTAssertEqual(firstInvocation.executableURL.path, "/tmp/llama-cli")
        XCTAssertEqual(firstInvocation.arguments, [
            "-m",
            modelURL.path,
            "-p",
            "Reply with one sentence.",
            "-n",
            "48",
            "--no-display-prompt"
        ])

        let benchmarkStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let benchmarkService = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: benchmarkStore,
            engine: runtime
        )
        let benchmark = try await benchmarkService.runBenchmark(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Benchmark Kairo local drafting.",
            generatedTokenTarget: 32
        )

        XCTAssertEqual(benchmark.runtime, .gguf)
        XCTAssertEqual(benchmark.runtimePackage, "llama.cpp CLI")
        XCTAssertEqual(benchmark.promptTokens, 16)
        XCTAssertEqual(benchmark.generatedTokens, 48)
        XCTAssertEqual(benchmark.promptTokensPerSecond, 200, accuracy: 0.1)
        XCTAssertEqual(benchmark.generationTokensPerSecond, 40, accuracy: 0.1)
        XCTAssertFalse(benchmark.isReferenceOnlyForIOS)
        let secondInvocation = try await commandRunner.invocation(at: 1)
        XCTAssertEqual(secondInvocation.arguments, [
            "-m",
            modelURL.path,
            "-p",
            "Benchmark Kairo local drafting.",
            "-n",
            "32",
            "--no-display-prompt"
        ])
    }

    func testLocalModelExternalCommandRuntimeBuildsQwenMLXReferenceCommand() async throws {
        let modelURL = temporaryFileURL(named: "qwen3-5-0-8b-mlx")
        let commandRunner = LocalModelFakeCommandRunner(result: LocalModelCommandRunResult(
            stdout: """
            Prompt: 8 tokens, 512.0 tokens-per-sec
            Generation: 24 tokens, 286.0 tokens-per-sec
            Qwen MLX response is alive.
            """,
            stderr: "",
            exitCode: 0,
            durationSeconds: 0.2
        ))
        let runtime = LocalModelExternalCommandRuntime(
            configuration: .mlxLMGenerate(
                pythonExecutableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                defaultGeneratedTokenTarget: 24
            ),
            commandRunner: commandRunner
        )
        let result = try await runtime.generateReply(
            model: .qwen35Tiny,
            installRecord: LocalModelInstallRecord(
                modelID: LocalModelManifest.qwen35Tiny.id,
                version: LocalModelManifest.qwen35Tiny.version,
                status: .installed,
                fileURL: modelURL,
                installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
                sha256: LocalModelManifest.qwen35Tiny.sha256
            ),
            prompt: "Ping Kairo."
        )

        XCTAssertEqual(result.runtime, .mlx)
        XCTAssertEqual(result.runtimePackage, "mlx-lm")
        XCTAssertEqual(result.responseText, "Qwen MLX response is alive.")
        XCTAssertEqual(result.generatedTokens, 24)
        XCTAssertEqual(result.generationTokensPerSecond, 286, accuracy: 0.1)

        let invocation = try await commandRunner.invocation(at: 0)
        XCTAssertEqual(invocation.arguments, [
            "-m",
            "mlx_lm.generate",
            "--model",
            "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
            "--prompt",
            "Ping Kairo.",
            "--max-tokens",
            "24"
        ])
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

    func testLocalModelSettingsRowExposesDownloadStorageAndPurposePolicy() throws {
        let row = LocalModelSettingsRow(
            model: LocalModelManifest.qwen35Tiny,
            installRecord: nil,
            isSelected: false
        )

        XCTAssertEqual(
            row.downloadApprovalText,
            "User-triggered download · 503.1 MB · Apache-2.0"
        )
        XCTAssertEqual(
            row.storagePolicyText,
            "Stored in Application Support/LocalModels · Excluded from iCloud backup"
        )
        XCTAssertEqual(
            row.purposeBoundaryText,
            "Offline chat, drafts, summaries, and Q&A only · no tools, web, account actions, or regulated advice"
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

    func testLocalModelDownloadProgressStateMapsPhasesAndCancellationSupport() {
        let preparing = LocalModelDownloadProgressState(modelID: "qwen-small", fractionCompleted: 0.05)
        let downloading = LocalModelDownloadProgressState(modelID: "qwen-small", fractionCompleted: 0.5)
        let verifying = LocalModelDownloadProgressState(modelID: "qwen-small", fractionCompleted: 0.95)

        XCTAssertEqual(preparing.phase, .preparing)
        XCTAssertEqual(downloading.phase, .downloading)
        XCTAssertEqual(verifying.phase, .verifying)
        XCTAssertTrue(preparing.allowsCancellation)
        XCTAssertEqual(verifying.displayText, "驗證中 95%")
    }

    func testVerifiedLocalModelDownloaderReportsProgressMilestones() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelMockHTTPClient(statusCode: 200, body: "model-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let progressRecorder = ProgressRecorder()
        _ = try await downloader.download(manifest) { progress in
            progressRecorder.append(progress)
        }

        let progressValues = progressRecorder.values()
        XCTAssertEqual(progressValues, [0.05, 0.55, 0.9, 1.0])
    }

    func testVerifiedLocalModelDownloaderCancelsAndCleansUpPartialState() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelCancellingHTTPClient(),
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
            XCTFail("Expected download cancellation to throw.")
        } catch let error as LocalModelDownloadError {
            XCTAssertEqual(error, .cancelled)
        }

        let record = await registry.record(for: manifest.id)
        XCTAssertNil(record)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelsDirectory.appendingPathComponent("qwen-small-1.0.gguf").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelsDirectory.appendingPathComponent("qwen-small-1.0.gguf.download").path))
    }

    func testLocalModelInstallRegistryCleansUpStaleDownloadingRecordsAfterRestart() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let destinationURL = modelsDirectory.appendingPathComponent("qwen-small-1.0.gguf")
        let partialURL = destinationURL.appendingPathExtension("download")
        try Data("existing-model".utf8).write(to: destinationURL)
        try Data("partial-download".utf8).write(to: partialURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .downloading,
            fileURL: destinationURL,
            installedSizeBytes: 0,
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        ))

        let cleanedModelIDs = try await registry.cleanupStaleDownloadingRecords()

        let cleanedRecord = await registry.record(for: "qwen-small")
        XCTAssertEqual(cleanedModelIDs, ["qwen-small"])
        XCTAssertNil(cleanedRecord)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialURL.path))
    }

    func testVerifiedLocalModelDownloaderExcludesModelDirectoryAndInstalledFileFromBackup() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelMockHTTPClient(statusCode: 200, body: "model-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let installedURL = try await downloader.download(manifest, progress: nil)

        let directoryValues = try modelsDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        let fileValues = try installedURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(directoryValues.isExcludedFromBackup, true)
        XCTAssertEqual(fileValues.isExcludedFromBackup, true)
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

    func testLocalModelRoutingProviderFailsClosedForPrivateChatWithoutLocalModel() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .automatic,
            installedAndSelectedModelID: nil
        )
        let cloudProvider = RecordingAIProvider()
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: cloudProvider,
            localModelSettingsService: service
        )
        let request = AICompletionRequest(
            systemPrompt: "system",
            userPrompt: "Summarize this sensitive note",
            privacyMode: .privateChat
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(request)) { error in
            XCTAssertEqual(error as? AIProviderError, .unsupported)
        }
        let completionCallCount = await cloudProvider.completionCalls()
        XCTAssertEqual(completionCallCount, 0)
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
        signingKeyID: String = "kairo-models-2026",
        signature: String = "signed-catalog-placeholder",
        minimumSafetyPolicyVersion: String = "2026.1",
        modelsJSON: [String]
    ) -> String {
        """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-06-02T00:00:00Z",
          "signingKeyID": "\(signingKeyID)",
          "signature": "\(signature)",
          "sourceRepository": "https://github.com/easonwumac/kairo-models",
          "minimumSafetyPolicyVersion": "\(minimumSafetyPolicyVersion)",
          "models": [
            \(modelsJSON.joined(separator: ",\n"))
          ]
        }
        """
    }

    private func signedRemoteModelCatalogJSON(
        signingKeyID: String = "kairo-models-2026",
        minimumSafetyPolicyVersion: String = "2026.1",
        modelsJSON: [String]
    ) throws -> (json: String, trustStore: LocalModelCatalogTrustStore) {
        let signingKey = P256.Signing.PrivateKey()
        let unsignedJSON = remoteModelCatalogJSON(
            signingKeyID: signingKeyID,
            signature: "",
            minimumSafetyPolicyVersion: minimumSafetyPolicyVersion,
            modelsJSON: modelsJSON
        )
        let unsignedCatalog = try LocalModelCatalog.decode(Data(unsignedJSON.utf8))
        let signedCatalog = try LocalModelCatalog.signedForTesting(
            catalog: unsignedCatalog,
            keyID: signingKeyID,
            signingKey: signingKey
        )
        let trustStore = LocalModelCatalogTrustStore(trustedKeys: [
            LocalModelTrustedSigningKey(
                keyID: signingKeyID,
                algorithm: "p256-sha256",
                status: .active,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        return (String(data: try signedCatalog.encoded(), encoding: .utf8) ?? "{}", trustStore)
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

private actor LocalModelCancellingHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        _ = request
        throw CancellationError()
    }
}

private actor RecordingAIProvider: AIProvider {
    private(set) var completionCallCount = 0

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        _ = request
        completionCallCount += 1
        return AICompletionResponse(message: "unexpected cloud call")
    }

    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        return AIEmbeddingResponse(vector: [0])
    }

    func completionCalls() -> Int {
        completionCallCount
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private var storage: [Double] = []
    private let lock = NSLock()

    func append(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }

    func values() -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private enum LocalModelMockHTTPClientError: Error {
    case missingRequest
}

private actor LocalModelFakeCommandRunner: LocalModelCommandRunner {
    private let result: LocalModelCommandRunResult
    private var invocations: [Invocation] = []

    init(result: LocalModelCommandRunResult) {
        self.result = result
    }

    func run(
        executableURL: URL,
        arguments: [String],
        timeoutSeconds: Double
    ) async throws -> LocalModelCommandRunResult {
        invocations.append(Invocation(
            executableURL: executableURL,
            arguments: arguments,
            timeoutSeconds: timeoutSeconds
        ))
        return result
    }

    func invocation(at index: Int) throws -> Invocation {
        guard invocations.indices.contains(index) else {
            throw LocalModelFakeCommandRunnerError.missingInvocation(index)
        }
        return invocations[index]
    }

    struct Invocation: Equatable, Sendable {
        var executableURL: URL
        var arguments: [String]
        var timeoutSeconds: Double
    }
}

private enum LocalModelFakeCommandRunnerError: Error {
    case missingInvocation(Int)
}
