import Foundation

public struct OpenAISettingsStatus: Equatable, Sendable {
    public var hasAPIKey: Bool
    public var providerName: String

    public init(hasAPIKey: Bool, providerName: String = "OpenAI") {
        self.hasAPIKey = hasAPIKey
        self.providerName = providerName
    }
}

public actor OpenAISettingsService {
    private let credentialStore: CredentialStore

    public init(credentialStore: CredentialStore) {
        self.credentialStore = credentialStore
    }

    public func status() async throws -> OpenAISettingsStatus {
        let key = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        return OpenAISettingsStatus(hasAPIKey: key?.isEmpty == false)
    }

    public func saveAPIKey(_ apiKey: String) async throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw OpenAISettingsError.emptyAPIKey
        }
        try await credentialStore.saveSecret(trimmed, for: CredentialKey.openAIAPIKey)
    }

    public func deleteAPIKey() async throws {
        try await credentialStore.deleteSecret(for: CredentialKey.openAIAPIKey)
    }
}

public enum OpenAISettingsError: Error, Equatable {
    case emptyAPIKey
}
