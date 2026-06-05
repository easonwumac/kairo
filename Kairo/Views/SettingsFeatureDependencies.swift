#if canImport(SwiftUI)
import Foundation

public struct SettingsFeatureDependencies {
    public var settingsService: OpenAISettingsService
    public var credentialStore: any CredentialStore
    public var oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]
    public var oauthCallbackStore: FileBackedOAuthConnectorCallbackStore?
    public var oauthLoginService: (any OAuthConnectorLoginServicing)?
    public var oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)?
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
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        oauthLoginService: (any OAuthConnectorLoginServicing)? = nil,
        oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)? = SettingsView.defaultOAuthWebAuthenticationRunner(),
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
        self.oauthClientConfigurations = oauthClientConfigurations
        self.oauthCallbackStore = oauthCallbackStore
        self.oauthLoginService = oauthLoginService
        self.oauthWebAuthenticationRunner = oauthWebAuthenticationRunner
        self.localModelCatalog = localModelCatalog
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.deletionAPI = deletionAPI
    }
}

public extension KairoEnvironment {
    var settingsFeatureDependencies: SettingsFeatureDependencies {
        SettingsFeatureDependencies(
            settingsService: OpenAISettingsService(credentialStore: credentialStore),
            credentialStore: credentialStore,
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
