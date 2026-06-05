public protocol OAuthConnectorLoginServiceMaking: Sendable {
    func makeLoginService(
        override: (any OAuthConnectorLoginServicing)?,
        credentialStore: any CredentialStore,
        oauthConnectorRegistry: any AppIntegrationRegistryProviding,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore?
    ) -> any OAuthConnectorLoginServicing
}

public struct OAuthConnectorLoginServiceFactory: Sendable {
    public init() {}

    public func makeLoginService(
        override: (any OAuthConnectorLoginServicing)?,
        credentialStore: any CredentialStore,
        oauthConnectorRegistry: any AppIntegrationRegistryProviding,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore?
    ) -> any OAuthConnectorLoginServicing {
        if let override {
            return override
        }
        return OAuthConnectorLoginCenter(
            registry: oauthConnectorRegistry,
            credentialStore: credentialStore,
            clientConfigurations: oauthClientConfigurations,
            callbackStore: oauthCallbackStore
        )
    }
}

extension OAuthConnectorLoginServiceFactory: OAuthConnectorLoginServiceMaking {}
