import Foundation

public struct KairoShareImportResult: Equatable, Sendable {
    public var attachments: [ChatAttachment]
    public var suggestedPrompt: String?
    public var importedItemIDs: [UUID]

    public init(
        attachments: [ChatAttachment],
        suggestedPrompt: String?,
        importedItemIDs: [UUID]
    ) {
        self.attachments = attachments
        self.suggestedPrompt = suggestedPrompt
        self.importedItemIDs = importedItemIDs
    }

    public var isEmpty: Bool {
        attachments.isEmpty && importedItemIDs.isEmpty
    }
}

public protocol KairoShareImportAPI: Sendable {
    func importPendingShares(limit: Int) async throws -> KairoShareImportResult
}

public struct KairoShareImportBackendService: KairoShareImportAPI {
    private let shareIngestionQueue: any ShareIngestionQueue

    public init(shareIngestionQueue: any ShareIngestionQueue) {
        self.shareIngestionQueue = shareIngestionQueue
    }

    public func importPendingShares(limit: Int = 10) async throws -> KairoShareImportResult {
        let items = try await shareIngestionQueue.pendingItems(limit: limit)
        guard !items.isEmpty else {
            return KairoShareImportResult(attachments: [], suggestedPrompt: nil, importedItemIDs: [])
        }

        var importedItemIDs: [UUID] = []
        importedItemIDs.reserveCapacity(items.count)
        for item in items {
            try await shareIngestionQueue.markImported(id: item.id)
            importedItemIDs.append(item.id)
        }

        return KairoShareImportResult(
            attachments: items.flatMap(\.attachments),
            suggestedPrompt: items.first?.suggestedPrompt,
            importedItemIDs: importedItemIDs
        )
    }
}
