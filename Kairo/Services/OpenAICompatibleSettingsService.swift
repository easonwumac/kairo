import Foundation

public struct OpenAICompatibleSettingsStatus: Equatable, Sendable {
    public var hasEndpoint: Bool
    public var hasAPIKey: Bool
    public var endpoint: String?
    public var model: String?
    public var displayName: String?
    public var providerName: String

    public init(
        hasEndpoint: Bool = false,
        hasAPIKey: Bool = false,
        endpoint: String? = nil,
        model: String? = nil,
        displayName: String? = nil,
        providerName: String = "OpenAI Compatible"
    ) {
        self.hasEndpoint = hasEndpoint
        self.hasAPIKey = hasAPIKey
        self.endpoint = endpoint
        self.model = model
        self.displayName = displayName
        self.providerName = providerName
    }

    public var isConfigured: Bool { hasEndpoint && hasAPIKey }
    public var label: String { displayName ?? providerName }
}

public struct OpenAICompatibleSettingsDryRunResult: Equatable, Sendable {
    public var usesSavedKey: Bool
    public var redactedKey: String
    public var message: String

    public init(usesSavedKey: Bool, redactedKey: String, message: String) {
        self.usesSavedKey = usesSavedKey
        self.redactedKey = redactedKey
        self.message = message
    }
}

public enum OpenAICompatibleSettingsError: LocalizedError, Equatable {
    case emptyEndpoint
    case emptyAPIKey

    public var errorDescription: String? {
        switch self {
        case .emptyEndpoint:
            return "Endpoint URL is required"
        case .emptyAPIKey:
            return "API key is required"
        }
    }
}

public actor OpenAICompatibleSettingsService {
    private let credentialStore: CredentialStore

    public init(credentialStore: CredentialStore) {
        self.credentialStore = credentialStore
    }

    public func status() async throws -> OpenAICompatibleSettingsStatus {
        let endpoint = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleEndpoint)
        let apiKey = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleAPIKey)
        let model = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleModel)
        let displayName = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleDisplayName)
        return OpenAICompatibleSettingsStatus(
            hasEndpoint: endpoint?.isEmpty == false,
            hasAPIKey: apiKey?.isEmpty == false,
            endpoint: endpoint,
            model: model,
            displayName: displayName,
            providerName: displayName ?? "OpenAI Compatible"
        )
    }

    public func saveEndpoint(_ endpoint: String) async throws {
        let trimmed = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenAICompatibleSettingsError.emptyEndpoint }
        try await credentialStore.saveSecret(trimmed, for: CredentialKey.openAICompatibleEndpoint)
    }

    public func saveAPIKey(_ apiKey: String) async throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenAICompatibleSettingsError.emptyAPIKey }
        try await credentialStore.saveSecret(trimmed, for: CredentialKey.openAICompatibleAPIKey)
    }

    public func saveModel(_ model: String) async throws {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        try await credentialStore.saveSecret(trimmed, for: CredentialKey.openAICompatibleModel)
    }

    public func saveDisplayName(_ name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        try await credentialStore.saveSecret(trimmed, for: CredentialKey.openAICompatibleDisplayName)
    }

    public func deleteAll() async throws {
        try await credentialStore.deleteSecret(for: CredentialKey.openAICompatibleEndpoint)
        try await credentialStore.deleteSecret(for: CredentialKey.openAICompatibleAPIKey)
        try await credentialStore.deleteSecret(for: CredentialKey.openAICompatibleModel)
        try await credentialStore.deleteSecret(for: CredentialKey.openAICompatibleDisplayName)
    }

    public func dryRun(_ endpoint: String?, _ apiKey: String?) async throws -> OpenAICompatibleSettingsDryRunResult {
        let candidateKey: String
        let usesSavedKey: Bool

        if let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            candidateKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            usesSavedKey = false
        } else if let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleAPIKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !savedKey.isEmpty {
            candidateKey = savedKey
            usesSavedKey = true
        } else {
            throw OpenAICompatibleSettingsError.emptyAPIKey
        }

        return OpenAICompatibleSettingsDryRunResult(
            usesSavedKey: usesSavedKey,
            redactedKey: redactedKey(candidateKey),
            message: "Configured with key: \(redactedKey(candidateKey))"
        )
    }

    private func redactedKey(_ apiKey: String) -> String {
        guard apiKey.count > 8 else { return "••••" }
        let prefix = apiKey.prefix(4)
        let suffix = apiKey.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}
