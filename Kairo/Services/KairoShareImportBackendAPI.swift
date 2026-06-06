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
    func clearImportedShares(ids: [UUID], attachments: [ChatAttachment]) async throws
}

public struct KairoShareImportBackendService: KairoShareImportAPI {
    private let shareIngestionQueue: any ShareIngestionQueue

    public init(shareIngestionQueue: any ShareIngestionQueue, sharedFilesDirectory: URL? = nil) {
        self.shareIngestionQueue = shareIngestionQueue
        _ = sharedFilesDirectory
    }

    public func importPendingShares(limit: Int = 10) async throws -> KairoShareImportResult {
        let items = try await shareIngestionQueue.pendingItems(limit: limit)
        guard !items.isEmpty else {
            return KairoShareImportResult(attachments: [], suggestedPrompt: nil, importedItemIDs: [])
        }
        let attachments = items.flatMap(\.attachments)

        return KairoShareImportResult(
            attachments: attachments,
            suggestedPrompt: Self.suggestedPrompt(for: items),
            importedItemIDs: items.map(\.id)
        )
    }

    public func clearImportedShares(ids: [UUID], attachments: [ChatAttachment]) async throws {
        _ = attachments
        for id in ids {
            try await shareIngestionQueue.markImported(id: id)
            try await shareIngestionQueue.delete(id: id)
        }
    }

    private static func suggestedPrompt(for items: [ShareIngestionItem]) -> String? {
        let attachments = items.flatMap(\.attachments)
        for attachment in attachments {
            guard let taskTitle = taskTitle(from: attachment.textPreview) else { continue }
            return KairoL10n.string("chat.share.prompt.extractReminder", taskTitle)
        }
        return items.first?.suggestedPrompt
    }

    private static func taskTitle(from text: String?) -> String? {
        guard let text else { return nil }
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if let title = strippedTaskTitle(from: line) {
                return title
            }
        }
        return nil
    }

    private static func strippedTaskTitle(from line: String) -> String? {
        let prefixes = [
            "TODO:",
            "Todo:",
            "todo:",
            "Reminder:",
            "reminder:",
            "Action:",
            "action:",
            "待辦：",
            "待辦:",
            "提醒：",
            "提醒:",
            "- [ ]",
            "-",
            "*",
            "•"
        ]
        for prefix in prefixes where line.hasPrefix(prefix) {
            let title = line
                .dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : String(title.prefix(120))
        }
        return nil
    }
}
