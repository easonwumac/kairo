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

    func testParsesSectionDeepLink() {
        let url = URL(string: "kairo://open/assets")!
        XCTAssertEqual(router.parse(url), .section(.assets))
    }

    func testSectionDeepLinkIsRoundTrip() {
        let route: KairoURLRoute = .section(.memory)
        let url = route.deepLink
        XCTAssertNotNil(url)
        XCTAssertEqual(router.parse(url!), route)
    }

    func testParsesCaptureReviewDeepLink() {
        let url = URL(string: "kairo://capture/review")!
        XCTAssertEqual(router.parse(url), .captureReview)
    }

    func testCaptureReviewDeepLinkIsRoundTrip() {
        let route: KairoURLRoute = .captureReview
        let url = route.deepLink
        XCTAssertNotNil(url)
        XCTAssertEqual(router.parse(url!), route)
    }

    func testIntentRouteStoreConsumesSectionRouteOnce() {
        let suiteName = "KairoURLRouterTests-\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KairoIntentRouteStore(defaults: defaults)

        store.save(.section(.models))

        XCTAssertEqual(store.consume(router: router), .section(.models))
        XCTAssertNil(store.consume(router: router))
    }

    func testIntentRouteStoreConsumesCaptureReviewRouteOnce() {
        let suiteName = "KairoURLRouterTests-\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KairoIntentRouteStore(defaults: defaults)

        store.save(.captureReview)

        XCTAssertEqual(store.consume(router: router), .captureReview)
        XCTAssertNil(store.consume(router: router))
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
