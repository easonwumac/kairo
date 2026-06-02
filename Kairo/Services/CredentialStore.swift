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
}
