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

    func testCaptureStoreSavesHTTPURLAndRejectsUnsupportedURLSchemes() {
        let suiteName = "KairoIntentCaptureStoreTests-\(UUID().uuidString)"
        let defaults = try! XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = KairoIntentCaptureStore(defaults: defaults)

        store.saveURL(URL(string: "https://example.com/article")!, note: "Read later", sourceName: "Shortcut URL")
        store.saveURL(URL(string: "file:///tmp/private.txt")!, note: nil, sourceName: "Shortcut URL")

        let captures = store.consume()

        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(captures.first?.kind, .url)
        XCTAssertEqual(captures.first?.url?.absoluteString, "https://example.com/article")
        XCTAssertTrue(captures.first?.text.contains("Read later") == true)
        XCTAssertTrue(captures.first?.text.contains("https://example.com/article") == true)
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

    func testCaptureIngestorEnqueuesIntentURLAttachment() async throws {
        let queue = InMemoryShareIngestionQueue()
        let captures = [
            KairoIntentCapture(
                kind: .url,
                text: "https://example.com/article",
                url: URL(string: "https://example.com/article")!,
                sourceName: "Shortcut URL",
                createdAt: Date(timeIntervalSince1970: 10)
            )
        ]

        try await KairoIntentCaptureIngestor().enqueue(captures, into: queue)

        let items = try await queue.pendingItems(limit: 10)
        let item = try XCTUnwrap(items.first)
        let attachment = try XCTUnwrap(item.attachments.first)
        XCTAssertEqual(attachment.kind, .url)
        XCTAssertEqual(attachment.fileURL?.absoluteString, "https://example.com/article")
        XCTAssertEqual(attachment.textPreview, "https://example.com/article")
    }
}
