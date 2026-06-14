import Foundation

public struct KairoShareImportResult: Equatable, Sendable {
    public var attachments: [ChatAttachment]
    public var suggestedPrompt: String?
    public var importedItemIDs: [UUID]
    public var suggestedActions: [AgentAction]

    public init(
        attachments: [ChatAttachment],
        suggestedPrompt: String?,
        importedItemIDs: [UUID],
        suggestedActions: [AgentAction] = []
    ) {
        self.attachments = attachments
        self.suggestedPrompt = suggestedPrompt
        self.importedItemIDs = importedItemIDs
        self.suggestedActions = suggestedActions
    }

    public var isEmpty: Bool {
        attachments.isEmpty && importedItemIDs.isEmpty && suggestedActions.isEmpty
    }
}

public protocol KairoShareImportAPI: Sendable {
    func importPendingShares(limit: Int) async throws -> KairoShareImportResult
    func clearImportedShares(ids: [UUID], attachments: [ChatAttachment]) async throws
}

public struct KairoShareImportBackendService: KairoShareImportAPI {
    private let shareIngestionQueue: any ShareIngestionQueue
    private let urlMetadataProvider: any URLMetadataProviding

    public init(
        shareIngestionQueue: any ShareIngestionQueue,
        sharedFilesDirectory: URL? = nil,
        urlMetadataProvider: any URLMetadataProviding = URLMetadataProviderFactory.live()
    ) {
        self.shareIngestionQueue = shareIngestionQueue
        self.urlMetadataProvider = urlMetadataProvider
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
            suggestedPrompt: await suggestedPrompt(for: items),
            importedItemIDs: items.map(\.id),
            suggestedActions: try await suggestedActions(limit: limit)
        )
    }

    public func clearImportedShares(ids: [UUID], attachments: [ChatAttachment]) async throws {
        _ = attachments
        for id in ids {
            try await shareIngestionQueue.markImported(id: id)
            try await shareIngestionQueue.delete(id: id)
        }
    }

    private func suggestedActions(limit: Int) async throws -> [AgentAction] {
        let inbox = KairoActionInboxBackendService(shareIngestionQueue: shareIngestionQueue)
        let items = try await inbox.pendingItems(limit: limit)
        return items
            .flatMap(\.suggestions)
            .compactMap(\.action)
    }

    private func suggestedPrompt(for items: [ShareIngestionItem]) async -> String? {
        let attachments = items.flatMap(\.attachments)
        for attachment in attachments {
            guard let taskTitle = Self.taskTitle(from: attachment.textPreview) else { continue }
            return KairoL10n.string("chat.share.prompt.extractReminder", taskTitle)
        }
        if let urlPrompt = await urlReadingPrompt(for: attachments) {
            return urlPrompt
        }
        return items.first?.suggestedPrompt
    }

    private func urlReadingPrompt(for attachments: [ChatAttachment]) async -> String? {
        let urls = attachments.compactMap { attachment -> URL? in
            guard attachment.kind == .url else { return nil }
            return attachment.fileURL ?? attachment.textPreview.flatMap(URL.init(string:))
        }
        guard !urls.isEmpty else { return nil }
        let metadata = await metadataByURL(for: Array(urls.prefix(4)))
        let context = URLReadingContextBuilder().promptBlock(from: urls, metadata: metadata)
        return KairoL10n.string("chat.share.prompt.readURLs", context)
    }

    private func metadataByURL(for urls: [URL]) async -> [URL: URLReadingMetadata] {
        var metadataByURL: [URL: URLReadingMetadata] = [:]
        for url in urls {
            guard let metadata = await urlMetadataProvider.metadata(for: url) else { continue }
            metadataByURL[url] = metadata
        }
        return metadataByURL
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
