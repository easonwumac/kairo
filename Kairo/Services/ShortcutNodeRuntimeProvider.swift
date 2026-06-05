import Foundation

public protocol ShortcutNodeRuntimeProviding: Sendable {
    func makeRuntime() async throws -> ShortcutNodeRuntime
}

public struct LiveShortcutNodeRuntimeProvider: ShortcutNodeRuntimeProviding {
    private let paths: KairoPaths
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(
        paths: KairoPaths = KairoSharedAppStorage.paths(),
        toolCatalog: (any BuiltInPhoneToolCatalogProviding)? = nil,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)? = nil
    ) {
        self.paths = paths
        self.toolCatalog = toolCatalog ?? BuiltInPhoneToolCatalog()
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog ?? AppIntegrationSkillCatalog()
    }

    public func makeRuntime() async throws -> ShortcutNodeRuntime {
        let store = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        return ShortcutNodeRuntime(
            memoryStore: store,
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
    }
}
