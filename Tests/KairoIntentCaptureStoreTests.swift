import XCTest
@testable import KairoCore

final class KairoIntentCaptureStoreTests: XCTestCase {
    func testCaptureStoreTrimsAndConsumesTextOnce() {
        let suiteName = "KairoIntentCaptureStoreTests-\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KairoIntentCaptureStore(defaults: defaults)

        store.saveText("  Review AFM notes  ", sourceName: "Shortcut")
        store.saveText("   ", sourceName: "Shortcut")

        let captures = store.consume()

        XCTAssertEqual(captures.map(\.text), ["Review AFM notes"])
        XCTAssertEqual(captures.map(\.sourceName), ["Shortcut"])
        XCTAssertEqual(store.consume(), [])
    }

    func testCaptureIngestorEnqueuesIntentTextIntoActionInbox() async throws {
        let queue = InMemoryShareIngestionQueue()
        let captures = [
            KairoIntentCapture(
                text: "TODO: Send AFM benchmark notes",
                sourceName: "Shortcut",
                createdAt: Date(timeIntervalSince1970: 10)
            )
        ]

        try await KairoIntentCaptureIngestor().enqueue(captures, into: queue)

        let inbox = KairoActionInboxBackendService(shareIngestionQueue: queue)
        let items = try await inbox.pendingItems(limit: 10)
        let item = try XCTUnwrap(items.first)
        XCTAssertEqual(item.summary.title, "Shortcut")
        XCTAssertEqual(item.source, .shareExtension)
        XCTAssertEqual(item.suggestions.contains { $0.kind == .reminderDraft }, true)
    }
}
