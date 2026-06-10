import XCTest
@testable import KairoCore

final class KairoURLRouterTests: XCTestCase {
    private let router = KairoURLRouter()

    func testParsesInfoPageDeepLink() {
        let id = UUID()
        let url = URL(string: "kairo://info-page/\(id.uuidString)")!
        XCTAssertEqual(router.parse(url), .infoPage(id: id))
    }

    func testParsesMemoryRecordDeepLink() {
        let id = UUID()
        let url = URL(string: "kairo://memory/\(id.uuidString)")!
        XCTAssertEqual(router.parse(url), .memoryRecord(id: id))
    }

    func testParsesKnowledgeAssetDeepLink() {
        let id = UUID()
        let url = URL(string: "kairo://asset/\(id.uuidString)")!
        XCTAssertEqual(router.parse(url), .knowledgeAsset(id: id))
    }

    func testParsesChatThreadDeepLink() {
        let id = UUID()
        let url = URL(string: "kairo://chat/\(id.uuidString)")!
        XCTAssertEqual(router.parse(url), .chatThread(id: id))
    }

    func testParsesSearchQuery() {
        let url = URL(string: "kairo://search?q=hong%20kong")!
        XCTAssertEqual(router.parse(url), .search(query: "hong kong"))
    }

    func testRejectsUnknownScheme() {
        let url = URL(string: "https://info-page/\(UUID().uuidString)")!
        XCTAssertNil(router.parse(url))
    }

    func testRejectsMalformedUUID() {
        let url = URL(string: "kairo://info-page/not-a-uuid")!
        XCTAssertNil(router.parse(url))
    }

    func testRejectsSearchWithEmptyQuery() {
        let url = URL(string: "kairo://search?q=")!
        XCTAssertNil(router.parse(url))
    }

    func testDeepLinkIsRoundTrip() {
        let id = UUID()
        let route: KairoURLRoute = .infoPage(id: id)
        let url = route.deepLink
        XCTAssertNotNil(url)
        XCTAssertEqual(router.parse(url!), route)
    }
}
