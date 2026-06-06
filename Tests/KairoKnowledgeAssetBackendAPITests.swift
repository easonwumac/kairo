import XCTest
@testable import KairoCore

final class KairoKnowledgeAssetBackendAPITests: XCTestCase {
    func testBackendComposerExposesInjectedKnowledgeAssetStore() async throws {
        let store = InMemoryKnowledgeAssetStore()
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            knowledgeAssetStore: store,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: MockAIProvider()
        )
        let asset = sampleAsset(title: "Composer asset")

        try await environment.backendAPI.knowledgeAssets.save(asset)
        let saved = try await store.list(limit: 10)

        XCTAssertEqual(saved.map(\.id), [asset.id])
    }

    func testJSONStorePersistsAndSearchesAssetContent() async throws {
        let fileURL = temporaryBackendTestFileURL(named: "knowledge-assets.json")
        let store = try await JSONFileKnowledgeAssetStore(fileURL: fileURL)
        let asset = KnowledgeAsset(
            title: "Airport transfer",
            kind: .screenshot,
            source: .shareExtension,
            attachments: [
                ChatAttachment(
                    kind: .image,
                    displayName: "transfer.png",
                    uniformTypeIdentifier: "public.png",
                    textPreview: "Hong Kong airport pickup"
                )
            ],
            extractedText: "Hong Kong airport pickup confirmed",
            generatedDescription: "Screenshot for airport pickup booking.",
            summary: "Airport pickup booking",
            tags: ["airport", "travel"],
            collections: ["Hong Kong trip"],
            checklistItems: [
                KnowledgeAssetChecklistItem(title: "Confirm return transfer", source: .suggested)
            ],
            proposedActions: []
        )

        try await store.save(asset)
        let reloaded = try await JSONFileKnowledgeAssetStore(fileURL: fileURL)
        let results = try await reloaded.search(query: "airport pickup", limit: 10)

        XCTAssertEqual(results.map(\.id), [asset.id])
        XCTAssertEqual(results.first?.attachments.first?.displayName, "transfer.png")
    }

    func testJSONStoreAppliesICloudBackupPolicyToIndexFile() async throws {
        let excludedURL = temporaryBackendTestFileURL(named: "knowledge-assets-excluded.json")
        let includedURL = temporaryBackendTestFileURL(named: "knowledge-assets-included.json")
        let excludedStore = try await JSONFileKnowledgeAssetStore(fileURL: excludedURL, iCloudBackupAllowed: false)
        let includedStore = try await JSONFileKnowledgeAssetStore(fileURL: includedURL, iCloudBackupAllowed: true)

        try await excludedStore.save(sampleAsset(title: "Excluded backup"))
        try await includedStore.save(sampleAsset(title: "Included backup"))

        XCTAssertEqual(try isExcludedFromBackup(excludedURL), true)
        XCTAssertEqual(try isExcludedFromBackup(includedURL), false)
    }

    func testImportingTravelScreenshotCreatesAssetChecklistReminderDraftAndClearsQueue() async throws {
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let sharedFilesDirectory = rootDirectory.appendingPathComponent("SharedFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: sharedFilesDirectory, withIntermediateDirectories: true)
        let imageURL = sharedFilesDirectory.appendingPathComponent("airport-transfer.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
        let item = ShareIngestionItem(
            attachments: [
                ChatAttachment(
                    kind: .image,
                    displayName: "airport-transfer.png",
                    uniformTypeIdentifier: "public.png",
                    fileURL: imageURL,
                    byteCount: 4,
                    textPreview: "香港 機場接送 去程 已預訂 接機時間 10:30",
                    source: .shareExtension
                )
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 1_717_392_000)
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let store = InMemoryKnowledgeAssetStore()
        let api = KairoKnowledgeAssetBackendService(
            assetStore: store,
            shareIngestionQueue: queue,
            sharedFilesDirectory: sharedFilesDirectory
        )

        let result = try await api.importPendingShares(limit: 10, iCloudBackupAllowed: false)
        let asset = try XCTUnwrap(result.assets.first)
        let searchResults = try await api.search(query: "airport 10:30", limit: 10)
        let remainingQueue = try await queue.pendingItems(limit: 10)

        XCTAssertEqual(result.importedItemIDs, [item.id])
        XCTAssertEqual(asset.kind, .screenshot)
        XCTAssertEqual(asset.source, .shareExtension)
        XCTAssertEqual(asset.iCloudBackupAllowed, false)
        XCTAssertTrue(asset.extractedText.localizedCaseInsensitiveContains("10:30"))
        XCTAssertTrue(asset.tags.contains("travel"))
        XCTAssertTrue(asset.tags.contains("airport"))
        XCTAssertTrue(asset.checklistItems.contains { $0.source == .extracted })
        XCTAssertTrue(asset.checklistItems.contains { $0.source == .suggested })
        XCTAssertTrue(asset.proposedActions.allSatisfy(\.requiresConfirmation))
        XCTAssertTrue(asset.proposedActions.contains { $0.kind == .createReminderDraft })
        XCTAssertEqual(searchResults.map(\.id), [asset.id])
        XCTAssertTrue(remainingQueue.isEmpty)
        XCTAssertEqual(try isExcludedFromBackup(imageURL), true)
    }

    private func sampleAsset(title: String) -> KnowledgeAsset {
        KnowledgeAsset(
            title: title,
            kind: .text,
            source: .manual,
            attachments: [],
            extractedText: title,
            generatedDescription: nil,
            summary: title,
            tags: [],
            collections: [],
            checklistItems: [],
            proposedActions: []
        )
    }

    private func isExcludedFromBackup(_ url: URL) throws -> Bool {
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        return values.isExcludedFromBackup ?? false
    }
}
