import Foundation

public enum KairoWikiDetail: Equatable, Sendable {
    case infoPage(InfoPage)
    case knowledgeAsset(KnowledgeAsset)
    case memory(MemoryRecord)
}

public protocol KairoWikiDetailResolving: Sendable {
    func detail(for result: KairoWikiSearchResult) async throws -> KairoWikiDetail?
}

public struct KairoWikiDetailResolver: KairoWikiDetailResolving {
    private let memoryStore: any MemoryStore
    private let knowledgeAssetStore: any KnowledgeAssetStore
    private let infoPageStore: any InfoPageStore

    public init(
        memoryStore: any MemoryStore,
        knowledgeAssetStore: any KnowledgeAssetStore,
        infoPageStore: any InfoPageStore
    ) {
        self.memoryStore = memoryStore
        self.knowledgeAssetStore = knowledgeAssetStore
        self.infoPageStore = infoPageStore
    }

    public func detail(for result: KairoWikiSearchResult) async throws -> KairoWikiDetail? {
        switch result.kind {
        case .infoPage:
            guard let page = try await infoPageStore.get(id: result.id) else { return nil }
            return .infoPage(page)
        case .knowledgeAsset:
            guard let asset = try await knowledgeAssetStore.get(id: result.id) else { return nil }
            return .knowledgeAsset(asset)
        case .memory:
            guard let memory = try await memoryStore.get(id: result.id) else { return nil }
            return .memory(memory)
        }
    }
}

public extension KairoEnvironment {
    var wikiDetailResolver: any KairoWikiDetailResolving {
        KairoWikiDetailResolver(
            memoryStore: memoryStore,
            knowledgeAssetStore: knowledgeAssetStore,
            infoPageStore: infoPageStore
        )
    }
}
