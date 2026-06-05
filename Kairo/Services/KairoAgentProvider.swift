import Foundation

public protocol KairoAgentProviding: Sendable {
    func makeAgent() async throws -> AgentCore
}

public struct LiveKairoAgentProvider: KairoAgentProviding {
    private let paths: KairoPaths
    private let credentialStore: any CredentialStore
    private let aiProviderOverride: (any AIProvider)?
    private let integrationRegistry: any AppIntegrationRegistryProviding
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(
        paths: KairoPaths = KairoSharedAppStorage.paths(),
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        aiProvider: (any AIProvider)? = nil,
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
        self.aiProviderOverride = aiProvider
        self.integrationRegistry = integrationRegistry
        self.toolCatalog = toolCatalog
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
    }

    public func makeAgent() async throws -> AgentCore {
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let aiProvider: any AIProvider
        if let aiProviderOverride {
            aiProvider = aiProviderOverride
        } else {
            aiProvider = try await KairoLiveLocalModelFactory(
                paths: paths,
                credentialStore: credentialStore
            ).makeComponents().aiProvider
        }

        return AgentCore(
            memoryStore: memoryStore,
            aiProvider: aiProvider,
            integrationRegistry: integrationRegistry,
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
    }
}
