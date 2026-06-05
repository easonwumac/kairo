import Foundation

public struct CloudModelRoutingAIProvider: AIProvider {
    private let credentialStore: CredentialStore
    private let apiKeyProvider: any AIProvider
    private let codexOAuthProvider: any AIProvider

    public init(
        credentialStore: CredentialStore,
        apiKeyProvider: (any AIProvider)? = nil,
        codexOAuthProvider: (any AIProvider)? = nil
    ) {
        self.credentialStore = credentialStore
        self.apiKeyProvider = apiKeyProvider ?? OpenAIProvider(credentialStore: credentialStore)
        self.codexOAuthProvider = codexOAuthProvider ?? OpenAICodexProvider(credentialStore: credentialStore)
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        if try await hasOAuthToken(providerKey: "openai-codex") {
            return try await codexOAuthProvider.complete(request)
        }
        return try await apiKeyProvider.complete(request)
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        try await apiKeyProvider.embed(request)
    }

    private func hasOAuthToken(providerKey: String) async throws -> Bool {
        guard let encoded = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: providerKey)),
              let tokenSet = try OAuthTokenSet.decodeStoredSecret(encoded) else {
            return false
        }
        return !tokenSet.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
