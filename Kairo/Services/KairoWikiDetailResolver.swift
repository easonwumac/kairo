import Foundation

public enum KairoWikiDetail: Equatable, Sendable {
    case infoPage(InfoPage, linkedAssets: [KairoWikiSearchResult])
    case knowledgeAsset(KnowledgeAsset, linkedInfoPages: [KairoWikiSearchResult])
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
            let linkedAssets = try await linkedAssets(for: page)
            return .infoPage(page, linkedAssets: linkedAssets)
        case .knowledgeAsset:
            guard let asset = try await knowledgeAssetStore.get(id: result.id) else { return nil }
            let linkedInfoPages = try await linkedInfoPages(for: asset)
            return .knowledgeAsset(asset, linkedInfoPages: linkedInfoPages)
        case .memory:
            guard let memory = try await memoryStore.get(id: result.id) else { return nil }
            return .memory(memory)
        }
    }

    private func linkedAssets(for page: InfoPage) async throws -> [KairoWikiSearchResult] {
        let pageAssetIDs = Set(page.assetIDs)
        return try await knowledgeAssetStore.list(limit: 200)
            .filter { pageAssetIDs.contains($0.id) || $0.linkedInfoPageIDs.contains(page.id) }
            .map { assetResult(from: $0) }
    }

    private func linkedInfoPages(for asset: KnowledgeAsset) async throws -> [KairoWikiSearchResult] {
        let linkedPageIDs = Set(asset.linkedInfoPageIDs)
        return try await infoPageStore.list(limit: 200)
            .filter { linkedPageIDs.contains($0.id) || $0.assetIDs.contains(asset.id) }
            .map { infoPageResult(from: $0) }
    }

    private func infoPageResult(from page: InfoPage) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: page.id,
            kind: .infoPage,
            title: page.title,
            snippet: snippet([
                page.summary,
                page.facts.map { "\($0.label): \($0.value)" }.joined(separator: " ")
            ]),
            updatedAt: page.updatedAt,
            score: 1
        )
    }

    private func assetResult(from asset: KnowledgeAsset) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: asset.id,
            kind: .knowledgeAsset,
            title: asset.title,
            snippet: snippet([
                asset.summary,
                asset.generatedDescription ?? "",
                asset.extractedText
            ]),
            updatedAt: asset.updatedAt,
            score: 1
        )
    }

    private func snippet(_ values: [String]) -> String {
        let compacted = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compacted.count > 220 else { return compacted }
        return String(compacted.prefix(220))
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
