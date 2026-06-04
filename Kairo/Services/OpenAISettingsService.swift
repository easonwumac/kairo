import Foundation

public struct OpenAISettingsStatus: Equatable, Sendable {
    public var hasAPIKey: Bool
    public var providerName: String

    public init(hasAPIKey: Bool, providerName: String = "OpenAI") {
        self.hasAPIKey = hasAPIKey
        self.providerName = providerName
    }
}

public struct OpenAISettingsDryRunResult: Equatable, Sendable {
    public var usesSavedKey: Bool
    public var redactedKey: String
    public var message: String

    public init(usesSavedKey: Bool, redactedKey: String, message: String) {
        self.usesSavedKey = usesSavedKey
        self.redactedKey = redactedKey
        self.message = message
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

    public func dryRunAPIKey(_ apiKey: String?) async throws -> OpenAISettingsDryRunResult {
        let trimmedInput = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidateKey: String
        let usesSavedKey: Bool

        if let trimmedInput, !trimmedInput.isEmpty {
            candidateKey = trimmedInput
            usesSavedKey = false
        } else if let savedKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
                  !savedKey.isEmpty {
            candidateKey = savedKey
            usesSavedKey = true
        } else {
            throw OpenAISettingsError.emptyAPIKey
        }

        return OpenAISettingsDryRunResult(
            usesSavedKey: usesSavedKey,
            redactedKey: Self.redactedKey(candidateKey),
            message: KairoL10n.string("settings.openai.dryRun.noNetwork")
        )
    }

    public func deleteAPIKey() async throws {
        try await credentialStore.deleteSecret(for: CredentialKey.openAIAPIKey)
    }

    private static func redactedKey(_ apiKey: String) -> String {
        guard apiKey.count > 8 else {
            return "••••"
        }

        let prefix = apiKey.prefix(4)
        let suffix = apiKey.suffix(4)
        return "\(prefix)...\(suffix)"
    }
}

public enum OpenAISettingsError: LocalizedError, Equatable {
    case emptyAPIKey

    public var errorDescription: String? {
        switch self {
        case .emptyAPIKey:
            return KairoL10n.string("settings.openai.error.emptyAPIKey")
        }
    }
}
