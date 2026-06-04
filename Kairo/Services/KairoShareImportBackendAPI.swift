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
            suggestedPrompt: Self.suggestedPrompt(for: items),
            importedItemIDs: importedItemIDs
        )
    }

    private static func suggestedPrompt(for items: [ShareIngestionItem]) -> String? {
        let attachments = items.flatMap(\.attachments)
        for attachment in attachments {
            guard let taskTitle = taskTitle(from: attachment.textPreview) else { continue }
            return "建立提醒事項：\(taskTitle)"
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
