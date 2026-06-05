import Foundation

public struct KairoLiveAccessComponents: Sendable {
    public var skillManagerService: AgentSkillManagerService
    public var marketplaceCatalogService: AgentSkillMarketplaceCatalogService
    public var oauthCallbackStore: FileBackedOAuthConnectorCallbackStore
    public var oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]

    public init(
        skillManagerService: AgentSkillManagerService,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService,
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]
    ) {
        self.skillManagerService = skillManagerService
        self.marketplaceCatalogService = marketplaceCatalogService
        self.oauthCallbackStore = oauthCallbackStore
        self.oauthClientConfigurations = oauthClientConfigurations
    }
}

public struct KairoLiveAccessFactory: Sendable {
    public var paths: KairoPaths
    public var credentialStore: any CredentialStore
    public var installedLocalModelIDs: [String]
    public var oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]?
    public var oauthConnectorRegistry: any OAuthConnectorRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(
        paths: KairoPaths,
        credentialStore: any CredentialStore,
        installedLocalModelIDs: [String],
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]? = nil,
        oauthConnectorRegistry: any OAuthConnectorRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
        self.installedLocalModelIDs = installedLocalModelIDs
        self.oauthClientConfigurations = oauthClientConfigurations
        self.oauthConnectorRegistry = oauthConnectorRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
    }

    public func makeComponents() async throws -> KairoLiveAccessComponents {
        let skillStore = try await FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)
        let runtimeContext = AgentSkillRuntimeContext.current(
            grantedEntitlements: [],
            connectedOAuthProviderKeys: try await Self.connectedOAuthProviderKeys(
                credentialStore: credentialStore,
                registry: oauthConnectorRegistry,
                appIntegrationSkillCatalog: appIntegrationSkillCatalog
            ),
            installedLocalModelIDs: installedLocalModelIDs
        )
        let skillManagerService = AgentSkillManagerService(
            store: skillStore,
            builtInCatalog: .defaultWithMarketplaceSamples,
            trustStore: .defaultRelease,
            runtimeContext: runtimeContext
        )
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(
            fileURL: paths.oauthConnectorCallbackPreviewsURL
        )

        return KairoLiveAccessComponents(
            skillManagerService: skillManagerService,
            marketplaceCatalogService: .defaultStandaloneRepository,
            oauthCallbackStore: callbackStore,
            oauthClientConfigurations: oauthClientConfigurations ?? OAuthConnectorClientConfigurationLoader().load(
                registry: oauthConnectorRegistry
            )
        )
    }

    public static func connectedOAuthProviderKeys(
        credentialStore: CredentialStore,
        registry: any OAuthConnectorRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()
    ) async throws -> [String] {
        let catalogProviderKeys = appIntegrationSkillCatalog.oauthProviderKeys
        let legacyProviderKeys = registry
            .oauthConnectorsNotMigrated(to: appIntegrationSkillCatalog)
            .compactMap(\.oauth?.providerKey)
        let providerKeys = Array(Set(catalogProviderKeys + legacyProviderKeys)).sorted()
        var connectedProviderKeys: [String] = []

        for providerKey in providerKeys {
            guard let encoded = try await credentialStore.readSecret(
                for: CredentialKey.oauthTokenSet(providerKey: providerKey)
            ) else {
                continue
            }
            if let tokenSet = try OAuthTokenSet.decodeStoredSecret(encoded),
               !tokenSet.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                connectedProviderKeys.append(providerKey)
            }
        }
        return connectedProviderKeys
    }
}
