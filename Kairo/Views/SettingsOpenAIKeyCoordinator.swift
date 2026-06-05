#if canImport(SwiftUI)
import Foundation

public actor SettingsOpenAIKeyCoordinator {
    private let settingsService: OpenAISettingsService

    public init(settingsService: OpenAISettingsService) {
        self.settingsService = settingsService
    }

    public func status() async throws -> OpenAISettingsStatus {
        try await settingsService.status()
    }

    public func saveAPIKey(_ apiKey: String) async throws {
        try await settingsService.saveAPIKey(apiKey)
    }

    public func deleteAPIKey() async throws {
        try await settingsService.deleteAPIKey()
    }

    public func dryRunAPIKey(_ apiKey: String?) async throws -> OpenAISettingsDryRunResult {
        try await settingsService.dryRunAPIKey(apiKey)
    }
}
#endif
