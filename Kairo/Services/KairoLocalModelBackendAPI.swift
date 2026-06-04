import Foundation

public protocol KairoLocalModelAPI: Sendable {
    func status() async throws -> LocalModelSettingsStatus
    func latestBenchmarkResult(for modelID: String) async throws -> LocalModelBenchmarkRunResult?
    func runBenchmark(
        modelID: String,
        prompt: String,
        generatedTokenTarget: Int
    ) async throws -> LocalModelBenchmarkRunResult
    func selectModel(id: String) async throws
    func clearSelectedModel() async throws
    func setPreference(_ preference: ProviderRoutePreference) async throws
    @discardableResult
    func cleanupStaleDownloadingRecords() async throws -> [String]
    func deleteModel(id: String) async throws
}

public enum KairoLocalModelAPIError: Error, Equatable {
    case unavailable
}

public struct KairoLocalModelBackendService: KairoLocalModelAPI {
    private let localModelSettingsService: LocalModelSettingsService?
    private let localModelBenchmarkService: LocalModelBenchmarkService?

    public init(
        localModelSettingsService: LocalModelSettingsService?,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil
    ) {
        self.localModelSettingsService = localModelSettingsService
        self.localModelBenchmarkService = localModelBenchmarkService
    }

    public func status() async throws -> LocalModelSettingsStatus {
        try await settingsService().status()
    }

    public func latestBenchmarkResult(for modelID: String) async throws -> LocalModelBenchmarkRunResult? {
        try await benchmarkService().latestResult(for: modelID)
    }

    public func runBenchmark(
        modelID: String,
        prompt: String,
        generatedTokenTarget: Int
    ) async throws -> LocalModelBenchmarkRunResult {
        try await benchmarkService().runBenchmark(
            modelID: modelID,
            prompt: prompt,
            generatedTokenTarget: generatedTokenTarget
        )
    }

    public func selectModel(id: String) async throws {
        try await settingsService().selectModel(id: id)
    }

    public func clearSelectedModel() async throws {
        try await settingsService().clearSelectedModel()
    }

    public func setPreference(_ preference: ProviderRoutePreference) async throws {
        try await settingsService().setPreference(preference)
    }

    @discardableResult
    public func cleanupStaleDownloadingRecords() async throws -> [String] {
        try await settingsService().cleanupStaleDownloadingRecords()
    }

    public func deleteModel(id: String) async throws {
        try await settingsService().deleteModel(id: id)
    }

    private func settingsService() throws -> LocalModelSettingsService {
        guard let localModelSettingsService else {
            throw KairoLocalModelAPIError.unavailable
        }
        return localModelSettingsService
    }

    private func benchmarkService() throws -> LocalModelBenchmarkService {
        guard let localModelBenchmarkService else {
            throw KairoLocalModelAPIError.unavailable
        }
        return localModelBenchmarkService
    }
}
