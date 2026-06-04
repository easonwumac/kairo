import XCTest
@testable import KairoCore

final class KairoLocalModelBackendAPITests: XCTestCase {
    func testLocalModelBackendAPIForwardsManagementCallsThroughCoreService() async throws {
        let service = try await makeBackendTestLocalModelSettingsService()
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

        do {
            _ = try await api.latestBenchmarkResult(for: "qwen-small")
            XCTFail("Expected local model API benchmark lookup to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }

        do {
            _ = try await api.runBenchmark(
                modelID: "qwen-small",
                prompt: "Measure local inference.",
                generatedTokenTarget: 16
            )
            XCTFail("Expected local model API benchmark run to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    func testLocalModelBackendAPIExposesPersistedBenchmarkEvidence() async throws {
        let registryURL = temporaryBackendTestFileURL(named: "local-model-registry.json")
        let settingsURL = temporaryBackendTestFileURL(named: "local-model-settings.json")
        let benchmarkURL = temporaryBackendTestFileURL(named: "local-model-benchmarks.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: LocalModelManifest.qwen35Tiny.id,
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let settingsService = LocalModelSettingsService(
            catalog: .kairoDefault,
            installRegistry: registry,
            settingsStore: try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        )
        let benchmarkStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let benchmarkService = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: benchmarkStore,
            engine: DeterministicLocalModelBenchmarkEngine(
                runtime: .gguf,
                generationTokensPerSecond: 42.5,
                promptTokensPerSecond: 118.25,
                peakMemoryMB: 900
            )
        )
        let api = KairoLocalModelBackendService(
            localModelSettingsService: settingsService,
            localModelBenchmarkService: benchmarkService
        )

        let initialResult = try await api.latestBenchmarkResult(for: LocalModelManifest.qwen35Tiny.id)
        XCTAssertNil(initialResult)

        let result = try await api.runBenchmark(
            modelID: LocalModelManifest.qwen35Tiny.id,
            prompt: "Measure local inference.",
            generatedTokenTarget: 32
        )

        XCTAssertEqual(result.modelID, LocalModelManifest.qwen35Tiny.id)
        XCTAssertEqual(result.runtime, .gguf)
        XCTAssertEqual(result.generatedTokens, 32)
        XCTAssertEqual(result.generationTokensPerSecond, 42.5)
        XCTAssertEqual(result.promptTokensPerSecond, 118.25)
        XCTAssertEqual(result.peakMemoryMB, 900)
        XCTAssertFalse(result.isReferenceOnlyForIOS)

        let latestResult = try await api.latestBenchmarkResult(for: LocalModelManifest.qwen35Tiny.id)
        XCTAssertEqual(latestResult, result)

        let reloadedStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let persistedResult = await reloadedStore.latestResult(for: LocalModelManifest.qwen35Tiny.id)
        XCTAssertEqual(persistedResult, result)
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
}
