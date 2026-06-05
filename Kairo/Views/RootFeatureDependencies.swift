#if canImport(SwiftUI)
import Foundation

public struct RootFeatureDependencies {
    public var openURLHandler: (any KairoOpenURLHandling)?

    public init(openURLHandler: (any KairoOpenURLHandling)? = nil) {
        self.openURLHandler = openURLHandler
    }
}

public extension KairoEnvironment {
    var rootFeatureDependencies: RootFeatureDependencies {
        guard let oauthConnectorCallbackStore else {
            return RootFeatureDependencies()
        }

        let oauthLoginService = OAuthConnectorLoginCenter(
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
#endif
