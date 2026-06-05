#if canImport(SwiftUI)
import Foundation

public struct SettingsFeatureDependencies {
    public var settingsService: OpenAISettingsService
    public var credentialStore: any CredentialStore
    public var oauthConnectorRegistry: any AppIntegrationRegistryProviding
    public var oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]
    public var oauthCallbackStore: FileBackedOAuthConnectorCallbackStore?
    public var oauthLoginService: (any OAuthConnectorLoginServicing)?
    public var oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)?
    public var openAIKeyCoordinator: SettingsOpenAIKeyCoordinator
    public var oauthCoordinator: SettingsOAuthConnectorCoordinator
    public var privacyCoordinator: SettingsPrivacyCoordinator
    public var localModelCatalog: LocalModelCatalog
    public var localModelCatalogService: LocalModelCatalogService?
    public var localModelSettingsService: LocalModelSettingsService?
    public var localModelDownloader: (any LocalModelDownloader)?
    public var localModelBenchmarkService: LocalModelBenchmarkService?
    public var localModelReplyCheckService: LocalModelReplyCheckService?
    public var deletionAPI: (any KairoDeletionAPI)?

    public init(
        settingsService: OpenAISettingsService,
        credentialStore: any CredentialStore,
        oauthConnectorRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        oauthLoginService: (any OAuthConnectorLoginServicing)? = nil,
        oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)? = nil,
        openAIKeyCoordinator: SettingsOpenAIKeyCoordinator? = nil,
        oauthCoordinator: SettingsOAuthConnectorCoordinator? = nil,
        privacyCoordinator: SettingsPrivacyCoordinator? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) {
        self.settingsService = settingsService
        self.credentialStore = credentialStore
        self.oauthConnectorRegistry = oauthConnectorRegistry
        self.oauthClientConfigurations = oauthClientConfigurations
        self.oauthCallbackStore = oauthCallbackStore
        self.oauthLoginService = oauthLoginService
        self.oauthWebAuthenticationRunner = oauthWebAuthenticationRunner
        self.openAIKeyCoordinator = openAIKeyCoordinator ?? SettingsOpenAIKeyCoordinator(settingsService: settingsService)
        let resolvedOAuthLoginService = oauthLoginService ?? OAuthConnectorLoginCenter(
            registry: oauthConnectorRegistry,
            credentialStore: credentialStore,
            clientConfigurations: oauthClientConfigurations,
            callbackStore: oauthCallbackStore
        )
        self.oauthCoordinator = oauthCoordinator ?? SettingsOAuthConnectorCoordinator(
            loginService: resolvedOAuthLoginService,
            webAuthenticationRunner: oauthWebAuthenticationRunner
        )
        self.privacyCoordinator = privacyCoordinator ?? SettingsPrivacyCoordinator(deletionAPI: deletionAPI)
        self.localModelCatalog = localModelCatalog
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.deletionAPI = deletionAPI
    }
}

public struct SettingsFeatureDependencyFactory: Sendable {
    public init() {}

    public func makeDependencies(
        credentialStore: (any CredentialStore)? = nil,
        oauthConnectorRegistry: (any AppIntegrationRegistryProviding)? = nil,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        oauthLoginService: (any OAuthConnectorLoginServicing)? = nil,
        oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)? = nil,
        openAIKeyCoordinator: SettingsOpenAIKeyCoordinator? = nil,
        oauthCoordinator: SettingsOAuthConnectorCoordinator? = nil,
        privacyCoordinator: SettingsPrivacyCoordinator? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) -> SettingsFeatureDependencies {
        let runtimeCredentialStore = credentialStore ?? InMemoryCredentialStore()
        let runtimeOAuthConnectorRegistry = oauthConnectorRegistry ?? IntegrationRegistry.appIntegrationHarnessRegistry()
        return SettingsFeatureDependencies(
            settingsService: OpenAISettingsService(credentialStore: runtimeCredentialStore),
            credentialStore: runtimeCredentialStore,
            oauthConnectorRegistry: runtimeOAuthConnectorRegistry,
            oauthClientConfigurations: oauthClientConfigurations,
            oauthCallbackStore: oauthCallbackStore,
            oauthLoginService: oauthLoginService,
            oauthWebAuthenticationRunner: oauthWebAuthenticationRunner,
            openAIKeyCoordinator: openAIKeyCoordinator,
            oauthCoordinator: oauthCoordinator,
            privacyCoordinator: privacyCoordinator,
            localModelCatalog: localModelCatalog,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelDownloader: localModelDownloader,
            localModelBenchmarkService: localModelBenchmarkService,
            localModelReplyCheckService: localModelReplyCheckService,
            deletionAPI: deletionAPI
        )
    }
}

public extension KairoEnvironment {
    var settingsFeatureDependencies: SettingsFeatureDependencies {
        SettingsFeatureDependencyFactory().makeDependencies(
            credentialStore: credentialStore,
            oauthConnectorRegistry: oauthConnectorRegistry,
            oauthClientConfigurations: oauthClientConfigurations,
            oauthCallbackStore: oauthConnectorCallbackStore,
            localModelCatalog: localModelCatalog,
            localModelCatalogService: localModelCatalogService,
            localModelSettingsService: localModelSettingsService,
            localModelDownloader: localModelDownloader,
            localModelBenchmarkService: localModelBenchmarkService,
            localModelReplyCheckService: localModelReplyCheckService,
            deletionAPI: backendAPI.deletion
        )
    }
}
#endif
