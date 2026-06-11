import Foundation

public enum KairoWikiSearchResultKind: String, Codable, Equatable, Sendable {
    case infoPage
    case knowledgeAsset
    case memory
}

public struct KairoWikiSearchResult: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: KairoWikiSearchResultKind
    public var title: String
    public var snippet: String
    public var updatedAt: Date
    public var score: Int

    public init(
        id: UUID,
        kind: KairoWikiSearchResultKind,
        title: String,
        snippet: String,
        updatedAt: Date,
        score: Int
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.snippet = snippet
        self.updatedAt = updatedAt
        self.score = score
    }
}

public protocol KairoWikiSearchProviding: Sendable {
    func search(query: String, limit: Int) async throws -> [KairoWikiSearchResult]
}

public struct KairoWikiSearchService: KairoWikiSearchProviding {
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

    public func search(query: String, limit: Int = 20) async throws -> [KairoWikiSearchResult] {
        let boundedLimit = max(limit, 1)
        let perStoreLimit = max(boundedLimit, 10)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        async let pages = trimmed.isEmpty
            ? infoPageStore.list(limit: perStoreLimit)
            : infoPageStore.search(query: trimmed, limit: perStoreLimit)
        async let assets = trimmed.isEmpty
            ? knowledgeAssetStore.list(limit: perStoreLimit)
            : knowledgeAssetStore.search(query: trimmed, limit: perStoreLimit)
        async let memories = trimmed.isEmpty
            ? memoryStore.list(limit: perStoreLimit)
            : memoryStore.search(query: trimmed, limit: perStoreLimit)

        let pageResults = try await pages.map {
            result(from: $0, query: trimmed)
        }
        let assetResults = try await assets.map {
            result(from: $0, query: trimmed)
        }
        let memoryResults = try await memories.map {
            result(from: $0, query: trimmed)
        }

        return (pageResults + assetResults + memoryResults)
            .filter { trimmed.isEmpty || $0.score > 0 }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                if lhs.updatedAt != rhs.updatedAt {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return sourceRank(lhs.kind) < sourceRank(rhs.kind)
            }
            .prefix(boundedLimit)
            .map { $0 }
    }

    private func result(from page: InfoPage, query: String) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: page.id,
            kind: .infoPage,
            title: page.title,
            snippet: Self.snippet([
                page.summary,
                page.facts.map { "\($0.label): \($0.value)" }.joined(separator: " "),
                page.timeline.map { "\($0.title) \($0.note ?? "")" }.joined(separator: " ")
            ]),
            updatedAt: page.updatedAt,
            score: query.isEmpty ? 1 : InfoPageSearchMatcher(query: query).score(page) + 15
        )
    }

    private func result(from asset: KnowledgeAsset, query: String) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: asset.id,
            kind: .knowledgeAsset,
            title: asset.title,
            snippet: Self.snippet([
                asset.summary,
                asset.generatedDescription ?? "",
                asset.extractedText,
                asset.tags.joined(separator: " "),
                asset.collections.joined(separator: " ")
            ]),
            updatedAt: asset.updatedAt,
            score: query.isEmpty ? 1 : KnowledgeAssetSearchMatcher(query: query).score(asset) + 10
        )
    }

    private func result(from memory: MemoryRecord, query: String) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: memory.id,
            kind: .memory,
            title: memory.title,
            snippet: Self.snippet([
                memory.summary,
                memory.content,
                memory.tags.joined(separator: " ")
            ]),
            updatedAt: memory.updatedAt,
            score: query.isEmpty ? 1 : MemorySearchMatcher(query: query).score(memory)
        )
    }

    private static func snippet(_ values: [String]) -> String {
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

    private func sourceRank(_ kind: KairoWikiSearchResultKind) -> Int {
        switch kind {
        case .infoPage:
            return 0
        case .knowledgeAsset:
            return 1
        case .memory:
            return 2
        }
    }
}

public extension KairoEnvironment {
    var wikiSearchService: any KairoWikiSearchProviding {
        KairoWikiSearchService(
            memoryStore: memoryStore,
            knowledgeAssetStore: knowledgeAssetStore,
            infoPageStore: injectedInfoPageStore ?? InMemoryInfoPageStore()
        )
    }
}
