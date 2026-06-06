import Foundation

public struct KnowledgeAsset: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: KnowledgeAssetKind
    public var source: KnowledgeAssetSource
    public var attachments: [ChatAttachment]
    public var extractedText: String
    public var generatedDescription: String?
    public var summary: String
    public var tags: [String]
    public var collections: [String]
    public var checklistItems: [KnowledgeAssetChecklistItem]
    public var proposedActions: [AgentAction]
    public var iCloudBackupAllowed: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        kind: KnowledgeAssetKind,
        source: KnowledgeAssetSource,
        attachments: [ChatAttachment],
        extractedText: String = "",
        generatedDescription: String? = nil,
        summary: String = "",
        tags: [String] = [],
        collections: [String] = [],
        checklistItems: [KnowledgeAssetChecklistItem] = [],
        proposedActions: [AgentAction] = [],
        iCloudBackupAllowed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.source = source
        self.attachments = attachments
        self.extractedText = extractedText
        self.generatedDescription = generatedDescription
        self.summary = summary
        self.tags = tags
        self.collections = collections
        self.checklistItems = checklistItems
        self.proposedActions = proposedActions
        self.iCloudBackupAllowed = iCloudBackupAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}

public enum KnowledgeAssetKind: String, Codable, CaseIterable, Sendable {
    case screenshot
    case image
    case text
    case url
    case pdf
    case file
    case note
}

public enum KnowledgeAssetSource: String, Codable, CaseIterable, Sendable {
    case shareExtension
    case chat
    case shortcut
    case manual
}

public struct KnowledgeAssetChecklistItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var isCompleted: Bool
    public var source: KnowledgeAssetChecklistSource

    public init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        source: KnowledgeAssetChecklistSource = .suggested
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.source = source
    }
}

public enum KnowledgeAssetChecklistSource: String, Codable, CaseIterable, Sendable {
    case extracted
    case suggested
    case userCreated
}
