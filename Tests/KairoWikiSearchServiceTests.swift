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
}
