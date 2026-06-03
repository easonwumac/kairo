import Foundation

public protocol KairoLocalModelAPI: Sendable {
    func status() async throws -> LocalModelSettingsStatus
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

    public init(localModelSettingsService: LocalModelSettingsService?) {
        self.localModelSettingsService = localModelSettingsService
    }

    public func status() async throws -> LocalModelSettingsStatus {
        try await service().status()
    }

    public func selectModel(id: String) async throws {
        try await service().selectModel(id: id)
    }

    public func clearSelectedModel() async throws {
        try await service().clearSelectedModel()
    }

    public func setPreference(_ preference: ProviderRoutePreference) async throws {
        try await service().setPreference(preference)
    }

    @discardableResult
    public func cleanupStaleDownloadingRecords() async throws -> [String] {
        try await service().cleanupStaleDownloadingRecords()
    }

    public func deleteModel(id: String) async throws {
        try await service().deleteModel(id: id)
    }

    private func service() throws -> LocalModelSettingsService {
        guard let localModelSettingsService else {
            throw KairoLocalModelAPIError.unavailable
        }
        return localModelSettingsService
    }
}
