#if canImport(SwiftUI)
import Foundation

public struct RootFeatureDependencies {
    public var openURLHandler: (any KairoOpenURLHandling)?

    public init(openURLHandler: (any KairoOpenURLHandling)? = nil) {
        self.openURLHandler = openURLHandler
    }
}

public struct RootFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(
        oauthConnectorCallbackStore: FileBackedOAuthConnectorCallbackStore?,
        credentialStore: any CredentialStore,
        oauthConnectorRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthLoginService: (any OAuthConnectorLoginServicing)? = nil,
        openURLHandler: (any KairoOpenURLHandling)? = nil
    ) -> RootFeatureDependencies {
        if let openURLHandler {
            return RootFeatureDependencies(openURLHandler: openURLHandler)
        }

        guard let oauthConnectorCallbackStore else {
            return RootFeatureDependencies()
        }

        let oauthLoginService = oauthLoginService ?? OAuthConnectorLoginCenter(
            registry: oauthConnectorRegistry,
            credentialStore: credentialStore,
            clientConfigurations: oauthClientConfigurations,
            callbackStore: oauthConnectorCallbackStore
        )
        return RootFeatureDependencies(
            openURLHandler: OAuthConnectorCallbackOpenURLHandler(loginService: oauthLoginService)
        )
    }
}

public extension KairoEnvironment {
    var rootFeatureDependencies: RootFeatureDependencies {
        RootFeatureDependencyFactory().makeDependencies(
            oauthConnectorCallbackStore: oauthConnectorCallbackStore,
            credentialStore: credentialStore,
            oauthConnectorRegistry: oauthConnectorRegistry,
            oauthClientConfigurations: oauthClientConfigurations
        )
    }
}
#endif
