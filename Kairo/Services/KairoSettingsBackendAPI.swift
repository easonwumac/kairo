import Foundation

public protocol KairoSettingsAPI: Sendable {
    func openAIStatus() async throws -> OpenAISettingsStatus
    func saveOpenAIAPIKey(_ apiKey: String) async throws
    func dryRunOpenAIAPIKey(_ apiKey: String?) async throws -> OpenAISettingsDryRunResult
    func deleteOpenAIAPIKey() async throws
    func oauthLoginOptions() async throws -> [OAuthConnectorLoginOption]
    func makeOAuthAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession
    func previewOAuthCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview
    func disconnectOAuthProvider(providerKey: String) async throws
}

public struct KairoSettingsBackendService: KairoSettingsAPI {
    private let openAISettingsService: OpenAISettingsService
    private let oauthLoginCenter: OAuthConnectorLoginCenter

    public init(
        openAISettingsService: OpenAISettingsService,
        oauthLoginCenter: OAuthConnectorLoginCenter
    ) {
        self.openAISettingsService = openAISettingsService
        self.oauthLoginCenter = oauthLoginCenter
    }

    public func openAIStatus() async throws -> OpenAISettingsStatus {
        try await openAISettingsService.status()
    }

    public func saveOpenAIAPIKey(_ apiKey: String) async throws {
        try await openAISettingsService.saveAPIKey(apiKey)
    }

    public func dryRunOpenAIAPIKey(_ apiKey: String?) async throws -> OpenAISettingsDryRunResult {
        try await openAISettingsService.dryRunAPIKey(apiKey)
    }

    public func deleteOpenAIAPIKey() async throws {
        try await openAISettingsService.deleteAPIKey()
    }

    public func oauthLoginOptions() async throws -> [OAuthConnectorLoginOption] {
        try await oauthLoginCenter.loginOptions()
    }

    public func makeOAuthAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession {
        try await oauthLoginCenter.makeAuthorizationSession(
            for: integrationKey,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    public func previewOAuthCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        try await oauthLoginCenter.previewCallback(callbackURL)
    }

    public func disconnectOAuthProvider(providerKey: String) async throws {
        try await oauthLoginCenter.disconnect(providerKey: providerKey)
    }
}
