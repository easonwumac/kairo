import Foundation

public struct KairoKnowledgeAssetImportResult: Equatable, Sendable {
    public var assets: [KnowledgeAsset]
    public var importedItemIDs: [UUID]

    public init(assets: [KnowledgeAsset], importedItemIDs: [UUID]) {
        self.assets = assets
        self.importedItemIDs = importedItemIDs
    }
}

public protocol KairoKnowledgeAssetAPI: Sendable {
    func importPendingShares(limit: Int, iCloudBackupAllowed: Bool) async throws -> KairoKnowledgeAssetImportResult
    func list(limit: Int) async throws -> [KnowledgeAsset]
    func search(query: String, limit: Int) async throws -> [KnowledgeAsset]
    func save(_ asset: KnowledgeAsset) async throws
}

public struct KairoKnowledgeAssetBackendService: KairoKnowledgeAssetAPI {
    private let assetStore: any KnowledgeAssetStore
    private let shareIngestionQueue: any ShareIngestionQueue
    private let sharedFilesDirectory: URL?

    public init(
        assetStore: any KnowledgeAssetStore,
        shareIngestionQueue: any ShareIngestionQueue,
        sharedFilesDirectory: URL? = nil
    ) {
        self.assetStore = assetStore
        self.shareIngestionQueue = shareIngestionQueue
        self.sharedFilesDirectory = sharedFilesDirectory
    }

    public func importPendingShares(limit: Int = 20, iCloudBackupAllowed: Bool = false) async throws -> KairoKnowledgeAssetImportResult {
        let items = try await shareIngestionQueue.pendingItems(limit: limit)
        var assets: [KnowledgeAsset] = []
        for item in items {
            let asset = KnowledgeAssetDraftBuilder.asset(from: item, iCloudBackupAllowed: iCloudBackupAllowed)
            try applyBackupPolicyToAssetFiles(asset, iCloudBackupAllowed: iCloudBackupAllowed)
            try await assetStore.save(asset)
            try await shareIngestionQueue.markImported(id: item.id)
            try await shareIngestionQueue.delete(id: item.id)
            assets.append(asset)
        }
        return KairoKnowledgeAssetImportResult(assets: assets, importedItemIDs: items.map(\.id))
    }

    public func list(limit: Int = 50) async throws -> [KnowledgeAsset] {
        try await assetStore.list(limit: limit)
    }

    public func search(query: String, limit: Int = 20) async throws -> [KnowledgeAsset] {
        try await assetStore.search(query: query, limit: limit)
    }

    public func save(_ asset: KnowledgeAsset) async throws {
        try await assetStore.save(asset)
    }

    private func applyBackupPolicyToAssetFiles(_ asset: KnowledgeAsset, iCloudBackupAllowed: Bool) throws {
        guard let sharedFilesDirectory else { return }
        let sharedDirectoryPath = sharedFilesDirectory.standardizedFileURL.path
        for attachment in asset.attachments {
            guard let fileURL = attachment.fileURL?.standardizedFileURL else { continue }
            guard fileURL.path.hasPrefix(sharedDirectoryPath) else { continue }
            try (fileURL as NSURL).setResourceValue(!iCloudBackupAllowed, forKey: URLResourceKey.isExcludedFromBackupKey)
        }
    }
}

public enum KnowledgeAssetDraftBuilder {
    public static func asset(from item: ShareIngestionItem, iCloudBackupAllowed: Bool = false) -> KnowledgeAsset {
        let extractedText = combinedText(from: item.attachments)
        let kind = kind(from: item.attachments)
        let travelContext = travelContext(from: extractedText)
        let title = title(for: item, extractedText: extractedText, travelContext: travelContext)
        let tags = tags(for: item.attachments, extractedText: extractedText, travelContext: travelContext)
        let collections = travelContext.map { [KairoL10n.string("knowledgeAsset.collection.trip", $0)] } ?? []
        let checklist = checklistItems(from: extractedText, travelContext: travelContext)
        let actions = proposedActions(from: extractedText, travelContext: travelContext)

        return KnowledgeAsset(
            title: title,
            kind: kind,
            source: .shareExtension,
            attachments: item.attachments,
            extractedText: extractedText,
            generatedDescription: nil,
            summary: summary(for: item, extractedText: extractedText),
            tags: tags,
            collections: collections,
            checklistItems: checklist,
            proposedActions: actions,
            iCloudBackupAllowed: iCloudBackupAllowed,
            createdAt: item.receivedAt,
            updatedAt: item.receivedAt
        )
    }

    private static func kind(from attachments: [ChatAttachment]) -> KnowledgeAssetKind {
        if attachments.contains(where: { $0.kind == .image }) {
            return .screenshot
        }
        if attachments.contains(where: { $0.kind == .pdf }) {
            return .pdf
        }
        if attachments.contains(where: { $0.kind == .url }) {
            return .url
        }
        if attachments.contains(where: { $0.kind == .text }) {
            return .text
        }
        return .file
    }

    private static func title(for item: ShareIngestionItem, extractedText: String, travelContext: String?) -> String {
        if let travelContext {
            return KairoL10n.string("knowledgeAsset.title.travelAsset", travelContext)
        }
        if let firstAttachment = item.attachments.first {
            return firstAttachment.displayName
        }
        let trimmed = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? KairoL10n.string("knowledgeAsset.title.untitled") : String(trimmed.prefix(60))
    }

    private static func summary(for item: ShareIngestionItem, extractedText: String) -> String {
        let trimmed = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return String(trimmed.prefix(220))
        }
        let names = item.attachments.map(\.displayName).joined(separator: ", ")
        return names.isEmpty ? KairoL10n.string("knowledgeAsset.summary.pendingAnalysis") : names
    }

    private static func tags(for attachments: [ChatAttachment], extractedText: String, travelContext: String?) -> [String] {
        var tags = Set<String>()
        for attachment in attachments {
            tags.insert(attachment.kind.rawValue)
            if attachment.kind == .image {
                tags.insert("screenshot")
            }
        }
        if let travelContext {
            tags.insert("travel")
            tags.insert(travelContext.lowercased())
        }
        if extractedText.localizedCaseInsensitiveContains("機場") || extractedText.localizedCaseInsensitiveContains("airport") {
            tags.insert("airport")
        }
        return Array(tags).sorted()
    }

    private static func checklistItems(from text: String, travelContext: String?) -> [KnowledgeAssetChecklistItem] {
        guard travelContext != nil else { return [] }
        var items: [KnowledgeAssetChecklistItem] = []
        let hasOutbound = text.localizedCaseInsensitiveContains("去程") || text.localizedCaseInsensitiveContains("arrival")
            || text.localizedCaseInsensitiveContains("接送") || text.localizedCaseInsensitiveContains("pickup")
        let hasReturn = text.localizedCaseInsensitiveContains("回程") || text.localizedCaseInsensitiveContains("return")

        if hasOutbound {
            items.append(KnowledgeAssetChecklistItem(title: KairoL10n.string("knowledgeAsset.checklist.outboundTransfer"), source: .extracted))
        }
        if !hasReturn {
            items.append(KnowledgeAssetChecklistItem(title: KairoL10n.string("knowledgeAsset.checklist.returnTransfer"), source: .suggested))
        }
        items.append(KnowledgeAssetChecklistItem(title: KairoL10n.string("knowledgeAsset.checklist.travelDocuments"), source: .suggested))
        return items
    }

    private static func proposedActions(from text: String, travelContext: String?) -> [AgentAction] {
        guard let travelContext else { return [] }
        let reminder = ReminderDraft(
            title: KairoL10n.string("knowledgeAsset.action.reviewTripChecklist", travelContext),
            notes: text.isEmpty ? nil : text,
            dueDate: nil
        )
        return [
            AgentAction(
                kind: .createReminderDraft,
                title: KairoL10n.string("actionInbox.action.createReminder"),
                rationale: KairoL10n.string("knowledgeAsset.action.rationale.tripChecklist"),
                payload: .reminder(reminder),
                riskTier: .tier2LowRiskWrite
            )
        ]
    }

    private static func travelContext(from text: String) -> String? {
        if text.localizedCaseInsensitiveContains("香港") || text.localizedCaseInsensitiveContains("hong kong") {
            return KairoL10n.string("knowledgeAsset.travel.hongKong")
        }
        return nil
    }

    private static func combinedText(from attachments: [ChatAttachment]) -> String {
        attachments.compactMap { attachment in
            attachment.textPreview?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}
