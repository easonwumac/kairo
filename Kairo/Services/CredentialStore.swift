import Foundation

public protocol CredentialStore: Sendable {
    func saveSecret(_ value: String, for key: String) async throws
    func readSecret(for key: String) async throws -> String?
    func deleteSecret(for key: String) async throws
}

public actor InMemoryCredentialStore: CredentialStore {
    private var secrets: [String: String] = [:]

    public init() {}

    public func saveSecret(_ value: String, for key: String) async throws {
        secrets[key] = value
    }

    public func readSecret(for key: String) async throws -> String? {
        secrets[key]
    }

    public func deleteSecret(for key: String) async throws {
        secrets.removeValue(forKey: key)
    }
}

public enum CredentialKey {
    public static let openAIAPIKey = "openai.api_key"
    public static let chatGPTOAuthTokenSet = "chatgpt.oauth_token_set"
    public static let openAICompatibleAPIKey = "openai_compatible.api_key"
    public static let openAICompatibleEndpoint = "openai_compatible.endpoint"
    public static let openAICompatibleModel = "openai_compatible.model"
    public static let openAICompatibleDisplayName = "openai_compatible.display_name"

    public static func oauthTokenSet(providerKey: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = providerKey
            .lowercased()
            .unicodeScalars
            .map { allowed.contains($0) ? Character($0) : "-" }
        let key = String(sanitized).trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
        return "oauth.\(key.isEmpty ? "provider" : key).token_set"
    }
}
