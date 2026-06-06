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
    public var sensitivity: KnowledgeAssetSensitivity
    public var linkedInfoPageIDs: [UUID]
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
        sensitivity: KnowledgeAssetSensitivity = .standard,
        linkedInfoPageIDs: [UUID] = [],
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
        self.sensitivity = sensitivity
        self.linkedInfoPageIDs = linkedInfoPageIDs
        self.collections = collections
        self.checklistItems = checklistItems
        self.proposedActions = proposedActions
        self.iCloudBackupAllowed = iCloudBackupAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case kind
        case source
        case attachments
        case extractedText
        case generatedDescription
        case summary
        case tags
        case sensitivity
        case linkedInfoPageIDs
        case collections
        case checklistItems
        case proposedActions
        case iCloudBackupAllowed
        case createdAt
        case updatedAt
        case deletedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.kind = try container.decode(KnowledgeAssetKind.self, forKey: .kind)
        self.source = try container.decode(KnowledgeAssetSource.self, forKey: .source)
        self.attachments = try container.decode([ChatAttachment].self, forKey: .attachments)
        self.extractedText = try container.decodeIfPresent(String.self, forKey: .extractedText) ?? ""
        self.generatedDescription = try container.decodeIfPresent(String.self, forKey: .generatedDescription)
        self.summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        self.sensitivity = try container.decodeIfPresent(KnowledgeAssetSensitivity.self, forKey: .sensitivity) ?? .standard
        self.linkedInfoPageIDs = try container.decodeIfPresent([UUID].self, forKey: .linkedInfoPageIDs) ?? []
        self.collections = try container.decodeIfPresent([String].self, forKey: .collections) ?? []
        self.checklistItems = try container.decodeIfPresent([KnowledgeAssetChecklistItem].self, forKey: .checklistItems) ?? []
        self.proposedActions = try container.decodeIfPresent([AgentAction].self, forKey: .proposedActions) ?? []
        self.iCloudBackupAllowed = try container.decodeIfPresent(Bool.self, forKey: .iCloudBackupAllowed) ?? false
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
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

public enum KnowledgeAssetSensitivity: String, Codable, CaseIterable, Sendable {
    case standard
    case personal
    case financial
    case medical
    case identity
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
