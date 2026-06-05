import Foundation

public protocol KairoAgentProviding: Sendable {
    func makeAgent() async throws -> AgentCore
}

public struct LiveKairoAgentProvider: KairoAgentProviding {
    private let paths: KairoPaths
    private let credentialStore: any CredentialStore
    private let aiProviderOverride: (any AIProvider)?
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding

    public init(
        paths: KairoPaths = KairoSharedAppStorage.paths(),
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        aiProvider: (any AIProvider)? = nil,
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) {
        self.paths = paths
        self.credentialStore = credentialStore
        self.aiProviderOverride = aiProvider
        self.toolCatalog = toolCatalog
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
            toolCatalog: toolCatalog
        )
    }
}
