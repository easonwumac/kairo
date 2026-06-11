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
        let graphLimit = max(perStoreLimit, 200)
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
        async let graphPages = trimmed.isEmpty
            ? [InfoPage]()
            : infoPageStore.list(limit: graphLimit)
        async let graphAssets = trimmed.isEmpty
            ? [KnowledgeAsset]()
            : knowledgeAssetStore.list(limit: graphLimit)

        var pageResults = try await pages.map {
            result(from: $0, query: trimmed)
        }
        var assetResults = try await assets.map {
            result(from: $0, query: trimmed)
        }
        let memoryResults = try await memories.map {
            result(from: $0, query: trimmed)
        }

        if !trimmed.isEmpty {
            let linked = try await linkedResults(
                pages: graphPages,
                assets: graphAssets,
                matchedPages: pageResults,
                matchedAssets: assetResults,
                query: trimmed
            )
            pageResults.append(contentsOf: linked.pages)
            assetResults.append(contentsOf: linked.assets)
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

    private func linkedResults(
        pages: [InfoPage],
        assets: [KnowledgeAsset],
        matchedPages: [KairoWikiSearchResult],
        matchedAssets: [KairoWikiSearchResult],
        query: String
    ) -> (pages: [KairoWikiSearchResult], assets: [KairoWikiSearchResult]) {
        let pagesByID = Dictionary(uniqueKeysWithValues: pages.map { ($0.id, $0) })
        let assetsByID = Dictionary(uniqueKeysWithValues: assets.map { ($0.id, $0) })
        var existingPageIDs = Set(matchedPages.map(\.id))
        var existingAssetIDs = Set(matchedAssets.map(\.id))
        var extraPages: [KairoWikiSearchResult] = []
        var extraAssets: [KairoWikiSearchResult] = []

        for assetResult in matchedAssets {
            guard let asset = assetsByID[assetResult.id] else { continue }
            let linkedPageIDs = Set(asset.linkedInfoPageIDs)
            for page in pages where !existingPageIDs.contains(page.id) {
                guard page.assetIDs.contains(asset.id) || linkedPageIDs.contains(page.id) else { continue }
                existingPageIDs.insert(page.id)
                extraPages.append(result(
                    from: page,
                    query: query,
                    scoreOverride: linkedScore(from: assetResult.score)
                ))
            }
        }

        for pageResult in matchedPages {
            guard let page = pagesByID[pageResult.id] else { continue }
            let linkedAssetIDs = Set(page.assetIDs)
            for asset in assets where !existingAssetIDs.contains(asset.id) {
                guard linkedAssetIDs.contains(asset.id) || asset.linkedInfoPageIDs.contains(page.id) else { continue }
                existingAssetIDs.insert(asset.id)
                extraAssets.append(result(
                    from: asset,
                    query: query,
                    scoreOverride: linkedScore(from: pageResult.score)
                ))
            }
        }

        return (extraPages, extraAssets)
    }

    private func linkedScore(from sourceScore: Int) -> Int {
        max(1, min(sourceScore - 1, 20 + (sourceScore / 2)))
    }

    private func result(from page: InfoPage, query: String, scoreOverride: Int? = nil) -> KairoWikiSearchResult {
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
            score: scoreOverride ?? (query.isEmpty ? 1 : InfoPageSearchMatcher(query: query).score(page) + 15)
        )
    }

    private func result(from asset: KnowledgeAsset, query: String, scoreOverride: Int? = nil) -> KairoWikiSearchResult {
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
            score: scoreOverride ?? (query.isEmpty ? 1 : KnowledgeAssetSearchMatcher(query: query).score(asset) + 10)
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
