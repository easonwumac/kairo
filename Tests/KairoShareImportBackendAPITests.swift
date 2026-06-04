import XCTest
@testable import KairoCore

final class KairoShareImportBackendAPITests: XCTestCase {
    func testShareImportBackendAPIImportsPendingItemsAndMarksThemImported() async throws {
        let builder = ShareAttachmentBuilder()
        let firstItem = ShareIngestionItem(
            attachments: [
                builder.text("Shared text", displayName: "Note"),
                builder.url(URL(string: "https://example.com/article")!)
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let secondItem = ShareIngestionItem(
            attachments: [
                builder.file(
                    url: URL(fileURLWithPath: "/tmp/brief.pdf"),
                    displayName: "brief.pdf",
                    uniformTypeIdentifier: "com.adobe.pdf",
                    byteCount: 2048
                )
            ],
            sourceApplication: "Files",
            receivedAt: Date(timeIntervalSince1970: 20)
        )
        let queue = InMemoryShareIngestionQueue(seed: [firstItem, secondItem])
        let api = KairoShareImportBackendService(shareIngestionQueue: queue)

        let imported = try await api.importPendingShares(limit: 10)

        XCTAssertEqual(imported.importedItemIDs, [firstItem.id, secondItem.id])
        XCTAssertEqual(imported.attachments.map(\.kind), [.text, .url, .pdf])
        XCTAssertEqual(imported.attachments.map(\.source), [.shareExtension, .shareExtension, .shareExtension])
        XCTAssertEqual(imported.suggestedPrompt, firstItem.suggestedPrompt)
        let remaining = try await queue.pendingItems(limit: 10)
        XCTAssertTrue(remaining.isEmpty)
    }
}
