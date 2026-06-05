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

    public init(
        paths: KairoPaths,
        credentialStore: any CredentialStore,
        installedLocalModelIDs: [String],
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]? = nil,
        oauthConnectorRegistry: any OAuthConnectorRegistryProviding = IntegrationRegistry()
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
        self.installedLocalModelIDs = installedLocalModelIDs
        self.oauthClientConfigurations = oauthClientConfigurations
        self.oauthConnectorRegistry = oauthConnectorRegistry
    }

    public func makeComponents() async throws -> KairoLiveAccessComponents {
        let skillStore = try await FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)
        let runtimeContext = AgentSkillRuntimeContext.current(
            grantedEntitlements: [],
            connectedOAuthProviderKeys: try await Self.connectedOAuthProviderKeys(
                credentialStore: credentialStore,
                registry: oauthConnectorRegistry
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
        registry: any OAuthConnectorRegistryProviding = IntegrationRegistry()
    ) async throws -> [String] {
        var providerKeys: [String] = []
        for integration in registry.oauthConnectors {
            guard let providerKey = integration.oauth?.providerKey else { continue }
            guard let encoded = try await credentialStore.readSecret(
                for: CredentialKey.oauthTokenSet(providerKey: providerKey)
            ) else {
                continue
            }
            if let tokenSet = try OAuthTokenSet.decodeStoredSecret(encoded),
               !tokenSet.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerKeys.append(providerKey)
            }
        }
        return Array(Set(providerKeys)).sorted()
    }
}
