import XCTest
@testable import KairoCore

final class KairoWikiSearchServiceTests: XCTestCase {
    func testWikiSearchAggregatesInfoPagesAssetsAndMemories() async throws {
        let page = InfoPage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            title: "Hong Kong Airport Pickup",
            category: .travel,
            templateID: .travel,
            summary: "Flight arrival and driver contact",
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let asset = KnowledgeAsset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            title: "Airport transfer screenshot",
            kind: .screenshot,
            source: .shareExtension,
            attachments: [],
            extractedText: "Hong Kong airport pickup voucher",
            summary: "Transfer booking",
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let memory = MemoryRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            title: "Airport preference",
            summary: "Prefer pickup at arrivals hall",
            content: "Airport pickup should include luggage time.",
            source: .manual,
            updatedAt: Date(timeIntervalSince1970: 30)
        )
        let service = KairoWikiSearchService(
            memoryStore: InMemoryMemoryStore(seed: [memory]),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(seed: [asset]),
            infoPageStore: InMemoryInfoPageStore(seed: [page])
        )

        let results = try await service.search(query: "airport pickup", limit: 10)

        XCTAssertEqual(Set(results.map(\.kind)), [.infoPage, .knowledgeAsset, .memory])
        XCTAssertEqual(results.first?.kind, .infoPage)
        XCTAssertTrue(results.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(results.allSatisfy { $0.score > 0 })
    }

    func testWikiSearchBlankQueryReturnsRecentItemsAcrossStores() async throws {
        let olderPage = InfoPage(
            title: "Older page",
            category: .generalNote,
            templateID: .generalNote,
            updatedAt: Date(timeIntervalSince1970: 1)
        )
        let recentAsset = KnowledgeAsset(
            title: "Recent asset",
            kind: .text,
            source: .manual,
            attachments: [],
            updatedAt: Date(timeIntervalSince1970: 3)
        )
        let middleMemory = MemoryRecord(
            title: "Middle memory",
            summary: "",
            content: "remember this",
            source: .manual,
            updatedAt: Date(timeIntervalSince1970: 2)
        )
        let service = KairoWikiSearchService(
            memoryStore: InMemoryMemoryStore(seed: [middleMemory]),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(seed: [recentAsset]),
            infoPageStore: InMemoryInfoPageStore(seed: [olderPage])
        )

        let results = try await service.search(query: " ", limit: 3)

        XCTAssertEqual(results.map(\.title), ["Recent asset", "Middle memory", "Older page"])
        XCTAssertEqual(results.map(\.score), [1, 1, 1])
    }

    func testWikiSearchTruncatesLongSnippets() async throws {
        let longContent = String(repeating: "important context ", count: 40)
        let memory = MemoryRecord(
            title: "Long note",
            summary: "",
            content: longContent,
            source: .manual
        )
        let service = KairoWikiSearchService(
            memoryStore: InMemoryMemoryStore(seed: [memory]),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(),
            infoPageStore: InMemoryInfoPageStore()
        )

        let results = try await service.search(query: "important", limit: 1)
        let result = try XCTUnwrap(results.first)

        XCTAssertLessThanOrEqual(result.snippet.count, 220)
        XCTAssertTrue(result.snippet.contains("important"))
    }

    func testDefaultAgentWikiContextProviderSkipsPrivateChat() async throws {
        let memory = MemoryRecord(
            title: "Private lookup",
            summary: "Do not inject",
            content: "private context",
            source: .manual
        )
        let searchService = KairoWikiSearchService(
            memoryStore: InMemoryMemoryStore(seed: [memory]),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(),
            infoPageStore: InMemoryInfoPageStore()
        )
        let provider = DefaultAgentWikiContextProvider(wikiSearchService: searchService)

        let results = try await provider.context(for: "private", privacyMode: .privateChat)

        XCTAssertTrue(results.isEmpty)
    }

    func testWikiDetailResolverLoadsResultSourceByKind() async throws {
        let page = InfoPage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000111")!,
            title: "Trip page",
            category: .travel,
            templateID: .travel,
            summary: "Trip summary"
        )
        let asset = KnowledgeAsset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000112")!,
            title: "Trip asset",
            kind: .text,
            source: .manual,
            attachments: [],
            extractedText: "Asset body",
            summary: "Asset summary"
        )
        let memory = MemoryRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000113")!,
            title: "Trip memory",
            summary: "Memory summary",
            content: "Memory body",
            source: .manual
        )
        let resolver = KairoWikiDetailResolver(
            memoryStore: InMemoryMemoryStore(seed: [memory]),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(seed: [asset]),
            infoPageStore: InMemoryInfoPageStore(seed: [page])
        )

        let pageDetail = try await resolver.detail(for: result(id: page.id, kind: .infoPage))
        let assetDetail = try await resolver.detail(for: result(id: asset.id, kind: .knowledgeAsset))
        let memoryDetail = try await resolver.detail(for: result(id: memory.id, kind: .memory))

        XCTAssertEqual(pageDetail, .infoPage(page))
        XCTAssertEqual(assetDetail, .knowledgeAsset(asset))
        XCTAssertEqual(memoryDetail, .memory(memory))
    }

    func testWikiDetailResolverSkipsDeletedItems() async throws {
        let store = InMemoryMemoryStore(seed: [
            MemoryRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000114")!,
                title: "Deleted memory",
                summary: "Deleted",
                content: "Deleted body",
                source: .manual
            )
        ])
        let memories = try await store.list(limit: 1)
        let memory = try XCTUnwrap(memories.first)
        try await store.delete(id: memory.id)
        let resolver = KairoWikiDetailResolver(
            memoryStore: store,
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(),
            infoPageStore: InMemoryInfoPageStore()
        )

        let detail = try await resolver.detail(for: result(id: memory.id, kind: .memory))

        XCTAssertNil(detail)
    }

    @MainActor
    func testWikiSearchViewModelPublishesSearchResults() async throws {
        let result = KairoWikiSearchResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
            kind: .knowledgeAsset,
            title: "Boarding pass",
            snippet: "Flight gate and seat",
            updatedAt: Date(timeIntervalSince1970: 10),
            score: 90
        )
        let service = StubWikiSearchService(results: [result])
        let resolver = StubWikiDetailResolver(detail: .knowledgeAsset(KnowledgeAsset(
            id: result.id,
            title: "Boarding pass",
            kind: .text,
            source: .manual,
            attachments: [],
            summary: "Flight gate and seat"
        )))
        let viewModel = KairoWikiSearchViewModel(searchService: service, detailResolver: resolver, limit: 5)

        await viewModel.search(query: "boarding")
        await viewModel.select(result)

        XCTAssertEqual(service.receivedQuery, "boarding")
        XCTAssertEqual(service.receivedLimit, 5)
        XCTAssertEqual(viewModel.results, [result])
        XCTAssertEqual(resolver.receivedResultID, result.id)
        XCTAssertNotNil(viewModel.selectedDetail)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingDetail)
    }

    @MainActor
    func testWikiSearchViewModelClearsResultsOnFailure() async throws {
        let error = NSError(domain: "WikiSearchTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        let service = StubWikiSearchService(results: [], error: error)
        let viewModel = KairoWikiSearchViewModel(searchService: service)

        await viewModel.search(query: "missing")

        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertEqual(viewModel.errorMessage, "Search failed")
        XCTAssertFalse(viewModel.isLoading)
    }

    private func result(id: UUID, kind: KairoWikiSearchResultKind) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: id,
            kind: kind,
            title: "Result",
            snippet: "Snippet",
            updatedAt: Date(timeIntervalSince1970: 10),
            score: 1
        )
    }
}

private final class StubWikiSearchService: KairoWikiSearchProviding, @unchecked Sendable {
    private let results: [KairoWikiSearchResult]
    private let error: Error?
    private(set) var receivedQuery: String?
    private(set) var receivedLimit: Int?

    init(
        results: [KairoWikiSearchResult],
        error: Error? = nil
    ) {
        self.results = results
        self.error = error
    }

    func search(query: String, limit: Int) async throws -> [KairoWikiSearchResult] {
        receivedQuery = query
        receivedLimit = limit
        if let error {
            throw error
        }
        return results
    }
}

private final class StubWikiDetailResolver: KairoWikiDetailResolving, @unchecked Sendable {
    private let detail: KairoWikiDetail?
    private(set) var receivedResultID: UUID?

    init(detail: KairoWikiDetail?) {
        self.detail = detail
    }

    func detail(for result: KairoWikiSearchResult) async throws -> KairoWikiDetail? {
        receivedResultID = result.id
        return detail
    }
}
