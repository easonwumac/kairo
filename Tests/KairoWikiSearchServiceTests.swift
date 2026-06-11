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

    func testWikiSearchIncludesInfoPageLinkedFromMatchingAsset() async throws {
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
        let page = InfoPage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
            title: "Camera warranty page",
            category: .warranty,
            templateID: .warranty,
            summary: "Coverage details",
            assetIDs: [assetID],
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let asset = KnowledgeAsset(
            id: assetID,
            title: "Receipt image",
            kind: .image,
            source: .chat,
            attachments: [],
            generatedDescription: "Lens serial KA-42 warranty card",
            summary: "Original image",
            linkedInfoPageIDs: [page.id],
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let service = KairoWikiSearchService(
            memoryStore: InMemoryMemoryStore(),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(seed: [asset]),
            infoPageStore: InMemoryInfoPageStore(seed: [page])
        )

        let results = try await service.search(query: "KA-42", limit: 10)

        XCTAssertTrue(results.contains { $0.id == assetID && $0.kind == .knowledgeAsset })
        XCTAssertTrue(results.contains { $0.id == page.id && $0.kind == .infoPage })
        XCTAssertLessThan(
            try XCTUnwrap(results.first { $0.id == page.id && $0.kind == .infoPage }).score,
            try XCTUnwrap(results.first { $0.id == assetID && $0.kind == .knowledgeAsset }).score
        )
    }

    func testWikiSearchIncludesAssetLinkedFromMatchingInfoPage() async throws {
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-000000000106")!
        let page = InfoPage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000107")!,
            title: "Appliance repair",
            category: .homeDevice,
            templateID: .homeDevice,
            summary: "Washer repair booking",
            facts: [
                InfoPageFact(label: "Case", value: "Repair ticket ZX-88")
            ],
            assetIDs: [assetID],
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let asset = KnowledgeAsset(
            id: assetID,
            title: "Washer photo",
            kind: .image,
            source: .chat,
            attachments: [],
            summary: "Original photo",
            linkedInfoPageIDs: [page.id],
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let service = KairoWikiSearchService(
            memoryStore: InMemoryMemoryStore(),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(seed: [asset]),
            infoPageStore: InMemoryInfoPageStore(seed: [page])
        )

        let results = try await service.search(query: "ZX-88", limit: 10)

        XCTAssertTrue(results.contains { $0.id == page.id && $0.kind == .infoPage })
        XCTAssertTrue(results.contains { $0.id == assetID && $0.kind == .knowledgeAsset })
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

        XCTAssertEqual(pageDetail, .infoPage(page, linkedAssets: []))
        XCTAssertEqual(assetDetail, .knowledgeAsset(asset, linkedInfoPages: []))
        XCTAssertEqual(memoryDetail, .memory(memory))
    }

    func testWikiDetailResolverExpandsLinkedAssetsAndPages() async throws {
        let assetID = UUID(uuidString: "00000000-0000-0000-0000-000000000115")!
        let page = InfoPage(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000116")!,
            title: "Lens warranty",
            category: .warranty,
            templateID: .warranty,
            summary: "Warranty coverage",
            assetIDs: [assetID],
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        let asset = KnowledgeAsset(
            id: assetID,
            title: "Lens receipt",
            kind: .image,
            source: .chat,
            attachments: [],
            generatedDescription: "Serial number and purchase date",
            summary: "Original receipt",
            linkedInfoPageIDs: [page.id],
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let resolver = KairoWikiDetailResolver(
            memoryStore: InMemoryMemoryStore(),
            knowledgeAssetStore: InMemoryKnowledgeAssetStore(seed: [asset]),
            infoPageStore: InMemoryInfoPageStore(seed: [page])
        )

        let pageDetail = try await resolver.detail(for: result(id: page.id, kind: .infoPage))
        let assetDetail = try await resolver.detail(for: result(id: asset.id, kind: .knowledgeAsset))

        guard case .infoPage(_, let linkedAssets) = pageDetail else {
            return XCTFail("Expected info page detail")
        }
        guard case .knowledgeAsset(_, let linkedInfoPages) = assetDetail else {
            return XCTFail("Expected asset detail")
        }
        XCTAssertEqual(linkedAssets.map(\.id), [asset.id])
        XCTAssertEqual(linkedAssets.map(\.kind), [.knowledgeAsset])
        XCTAssertEqual(linkedInfoPages.map(\.id), [page.id])
        XCTAssertEqual(linkedInfoPages.map(\.kind), [.infoPage])
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
        let related = KairoWikiSearchResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000502")!,
            kind: .infoPage,
            title: "Flight itinerary",
            snippet: "Airport gate context",
            updatedAt: Date(timeIntervalSince1970: 20),
            score: 70
        )
        let service = StubWikiSearchService(resultBatches: [[result], [result, related]])
        let resolver = StubWikiDetailResolver(detail: .knowledgeAsset(KnowledgeAsset(
            id: result.id,
            title: "Boarding pass",
            kind: .text,
            source: .manual,
            attachments: [],
            summary: "Flight gate and seat"
        ), linkedInfoPages: []))
        let viewModel = KairoWikiSearchViewModel(searchService: service, detailResolver: resolver, limit: 5)

        await viewModel.search(query: "boarding")
        await viewModel.select(result)

        XCTAssertEqual(service.receivedQueries.first, "boarding")
        XCTAssertEqual(service.receivedLimits.first, 5)
        XCTAssertEqual(service.receivedQueries.count, 2)
        XCTAssertTrue(service.receivedQueries[1].contains("Boarding pass"))
        XCTAssertTrue(service.receivedQueries[1].contains("Flight gate and seat"))
        XCTAssertEqual(viewModel.results, [result])
        XCTAssertEqual(viewModel.relatedResults, [related])
        XCTAssertEqual(resolver.receivedResultID, result.id)
        XCTAssertNotNil(viewModel.selectedDetail)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingDetail)
        XCTAssertFalse(viewModel.isLoadingRelated)
    }

    @MainActor
    func testWikiSearchViewModelOpensSearchRoute() async throws {
        let result = KairoWikiSearchResult(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000503")!,
            kind: .infoPage,
            title: "Warranty page",
            snippet: "Lens warranty",
            updatedAt: Date(timeIntervalSince1970: 10),
            score: 70
        )
        let service = StubWikiSearchService(results: [result])
        let viewModel = KairoWikiSearchViewModel(searchService: service)

        let query = await viewModel.open(.search(query: "lens warranty"))

        XCTAssertEqual(query, "lens warranty")
        XCTAssertEqual(service.receivedQuery, "lens warranty")
        XCTAssertEqual(viewModel.results, [result])
        XCTAssertNil(viewModel.selectedResult)
    }

    @MainActor
    func testWikiSearchViewModelOpensItemRouteAndHydratesSelectedResult() async throws {
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000504")!
        let page = InfoPage(
            id: pageID,
            title: "Direct linked warranty",
            category: .warranty,
            templateID: .warranty,
            summary: "Coverage and serial number"
        )
        let service = StubWikiSearchService(results: [])
        let resolver = StubWikiDetailResolver(detail: .infoPage(page, linkedAssets: []))
        let viewModel = KairoWikiSearchViewModel(searchService: service, detailResolver: resolver)

        let query = await viewModel.open(.infoPage(id: pageID))

        XCTAssertNil(query)
        XCTAssertEqual(resolver.receivedResultID, pageID)
        XCTAssertEqual(viewModel.selectedResult?.id, pageID)
        XCTAssertEqual(viewModel.selectedResult?.kind, .infoPage)
        XCTAssertEqual(viewModel.selectedResult?.title, "Direct linked warranty")
        XCTAssertEqual(viewModel.selectedDetail, .infoPage(page, linkedAssets: []))
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
    private var resultBatches: [[KairoWikiSearchResult]]
    private let error: Error?
    private(set) var receivedQueries: [String] = []
    private(set) var receivedLimits: [Int] = []
    private(set) var receivedQuery: String?
    private(set) var receivedLimit: Int?

    init(
        results: [KairoWikiSearchResult],
        error: Error? = nil
    ) {
        self.resultBatches = [results]
        self.error = error
    }

    init(
        resultBatches: [[KairoWikiSearchResult]],
        error: Error? = nil
    ) {
        self.resultBatches = resultBatches
        self.error = error
    }

    func search(query: String, limit: Int) async throws -> [KairoWikiSearchResult] {
        receivedQuery = query
        receivedLimit = limit
        receivedQueries.append(query)
        receivedLimits.append(limit)
        if let error {
            throw error
        }
        if resultBatches.isEmpty {
            return []
        }
        return resultBatches.removeFirst()
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
