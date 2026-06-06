import XCTest
import Foundation
@testable import KairoCore

final class KairoShareImportBackendAPITests: XCTestCase {
    func testKairoUITestingShareImportFactorySeedsPendingTextItemWhenRequested() async throws {
        let queue = KairoUITestingShareImportFactory(seedSharedTaskText: true).makeQueue()

        let pending = try await queue.pendingItems(limit: 10)

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.status, .pending)
        XCTAssertEqual(pending.first?.attachments.map(\.kind), [.text])
        XCTAssertEqual(pending.first?.attachments.first?.source, .shareExtension)
    }

    func testKairoUITestingStoreFactorySeedsShareQueueAndPersistsChatHistory() async throws {
        let rootDirectory = temporaryDirectory()
        let firstComponents = try await KairoUITestingStoreFactory(
            rootDirectory: rootDirectory,
            seedSharedTaskText: true
        ).makeComponents()
        let thread = ChatThread(messages: [
            ChatMessage(role: .user, text: "Persist UI testing chat")
        ])

        try await firstComponents.chatHistoryStore.saveThread(thread)
        let pendingShares = try await firstComponents.shareIngestionQueue.pendingItems(limit: 10)

        let reloadedComponents = try await KairoUITestingStoreFactory(
            rootDirectory: rootDirectory,
            seedSharedTaskText: false
        ).makeComponents()
        let reloadedThreads = try await reloadedComponents.chatHistoryStore.listThreads(limit: 10)

        XCTAssertEqual(pendingShares.count, 1)
        XCTAssertTrue(reloadedThreads.contains { $0.id == thread.id })
    }

    func testShareImportBackendAPIImportsPendingItemsWithoutDeletingBeforeChatSend() async throws {
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
        XCTAssertNotNil(imported.suggestedPrompt)
        let remaining = try await queue.pendingItems(limit: 10)
        XCTAssertEqual(remaining.map(\.id), [firstItem.id, secondItem.id])

        try await api.clearImportedShares(ids: imported.importedItemIDs, attachments: imported.attachments)

        let cleared = try await queue.pendingItems(limit: 10)
        XCTAssertTrue(cleared.isEmpty)
    }
    func testShareImportBackendAPIBuildsReminderPromptForTaskLikeSharedText() async throws {
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.text("""
                TODO: Send prototype link
                Notes from the launch review.
                """, displayName: "Launch Notes")
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let api = KairoShareImportBackendService(shareIngestionQueue: queue)
        let imported = try await api.importPendingShares(limit: 10)
        XCTAssertNotNil(imported.suggestedPrompt)
        XCTAssertEqual(imported.attachments.first?.textPreview?.contains("TODO: Send prototype link"), true)
        let remaining = try await queue.pendingItems(limit: 10)
        XCTAssertEqual(remaining.map(\.id), [item.id])
    }
    func testShareImportBackendAPIPurgesImportedShareContentFromDiskAfterClear() async throws {
        let fileURL = temporaryFileURL(named: "share-ingestion-queue.json")
        let queue = try await JSONFileShareIngestionQueue(fileURL: fileURL)
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.text("Private shared text should not remain in the queue after import.", displayName: "Private Note")
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        try await queue.enqueue(item)
        var rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(item.id.uuidString))
        XCTAssertTrue(rawText.contains("Private shared text should not remain"))
        let api = KairoShareImportBackendService(shareIngestionQueue: queue)
        let imported = try await api.importPendingShares(limit: 10)
        XCTAssertEqual(imported.importedItemIDs, [item.id])
        rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(item.id.uuidString))
        XCTAssertTrue(rawText.contains("Private shared text should not remain"))

        try await api.clearImportedShares(ids: imported.importedItemIDs, attachments: imported.attachments)

        rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(rawText.contains(item.id.uuidString))
        XCTAssertFalse(rawText.contains("Private shared text should not remain"))
    }
    func testShareImportBackendAPIPreservesCopiedSharedFilesAfterClearForChatAndLibraryReferences() async throws {
        let rootDirectory = temporaryDirectory()
        let sharedFilesDirectory = rootDirectory.appendingPathComponent("SharedFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedFilesDirectory, withIntermediateDirectories: true)
        let copiedFileURL = sharedFilesDirectory.appendingPathComponent("copied-note.txt")
        let externalFileURL = rootDirectory.appendingPathComponent("external-note.txt")
        try "copied file content".write(to: copiedFileURL, atomically: true, encoding: .utf8)
        try "external file content".write(to: externalFileURL, atomically: true, encoding: .utf8)
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.file(url: copiedFileURL, displayName: "copied-note.txt", uniformTypeIdentifier: "public.plain-text", byteCount: 19),
                builder.file(url: externalFileURL, displayName: "external-note.txt", uniformTypeIdentifier: "public.plain-text", byteCount: 21)
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let api = KairoShareImportBackendService(
            shareIngestionQueue: queue,
            sharedFilesDirectory: sharedFilesDirectory
        )
        let imported = try await api.importPendingShares(limit: 10)
        XCTAssertEqual(imported.importedItemIDs, [item.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFileURL.path))

        try await api.clearImportedShares(ids: imported.importedItemIDs, attachments: imported.attachments)

        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: externalFileURL.path))
    }
    private func temporaryFileURL(named name: String) -> URL {
        let directory = temporaryDirectory()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoShareImportBackendAPITests-\(UUID().uuidString)", isDirectory: true)
    }
}
