import Foundation

public struct OpenAICompatibleRuntimeSettings: Equatable, Sendable {
    public var endpoint: String
    public var apiKey: String
    public var model: String

    public init(endpoint: String, apiKey: String, model: String) {
        self.endpoint = endpoint
        self.apiKey = apiKey
        self.model = model
    }
}

public struct CompanionCloudModelRoutingAIProvider: AIProvider {
    private let credentialStore: any CredentialStore
    private let fallbackProvider: any AIProvider
    private let httpClient: any HTTPClient
    private let settingsLoader: @Sendable () async -> OpenAICompatibleRuntimeSettings?

    public init(
        credentialStore: any CredentialStore,
        fallbackProvider: (any AIProvider)? = nil,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        settingsLoader: (@Sendable () async -> OpenAICompatibleRuntimeSettings?)? = nil
    ) {
        self.credentialStore = credentialStore
        self.fallbackProvider = fallbackProvider ?? CloudModelRoutingAIProvider(credentialStore: credentialStore)
        self.httpClient = httpClient
        if let settingsLoader {
            self.settingsLoader = settingsLoader
        } else {
            self.settingsLoader = {
                if let defaultsSettings = Self.userDefaultsOpenAICompatibleSettings() {
                    return defaultsSettings
                }
                return await Self.credentialStoreOpenAICompatibleSettings(credentialStore: credentialStore)
            }
        }
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        guard let settings = await settingsLoader() else {
            return try await fallbackProvider.complete(request)
        }
        guard URL(string: settings.endpoint) != nil else {
            return try await fallbackProvider.complete(request)
        }
        let provider = OpenAICompatibleProvider(
            credentialStore: credentialStore,
            httpClient: httpClient,
            endpoint: settings.endpoint,
            apiKey: settings.apiKey,
            model: settings.model
        )
        return try await provider.complete(request)
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        guard let settings = await settingsLoader(), URL(string: settings.endpoint) != nil else {
            return try await fallbackProvider.embed(request)
        }
        let provider = OpenAICompatibleProvider(
            credentialStore: credentialStore,
            httpClient: httpClient,
            endpoint: settings.endpoint,
            apiKey: settings.apiKey,
            model: settings.model
        )
        return try await provider.embed(request)
    }

    private static func userDefaultsOpenAICompatibleSettings() -> OpenAICompatibleRuntimeSettings? {
        let defaults = UserDefaults.standard
        let endpoint = defaults.string(forKey: "omlx_endpoint")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = defaults.string(forKey: "omlx_api_key")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = defaults.string(forKey: "omlx_model")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !endpoint.isEmpty, !apiKey.isEmpty else { return nil }
        return OpenAICompatibleRuntimeSettings(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model.isEmpty ? "gemma-4-e2b-it-4bit" : model
        )
    }

    private static func credentialStoreOpenAICompatibleSettings(
        credentialStore: any CredentialStore
    ) async -> OpenAICompatibleRuntimeSettings? {
        let endpoint = (try? await credentialStore.readSecret(for: CredentialKey.openAICompatibleEndpoint))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let apiKey = (try? await credentialStore.readSecret(for: CredentialKey.openAICompatibleAPIKey))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let model = (try? await credentialStore.readSecret(for: CredentialKey.openAICompatibleModel))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !endpoint.isEmpty, !apiKey.isEmpty else { return nil }
        return OpenAICompatibleRuntimeSettings(
            endpoint: endpoint,
            apiKey: apiKey,
            model: model.isEmpty ? "gemma-4-e2b-it-4bit" : model
        )
    }
}
