import Foundation

public struct MemoryRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var summary: String
    public var content: String
    public var source: MemorySource
    public var tags: [String]
    public var sensitivity: SensitivityLevel
    public var cloudSyncAllowed: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var expiresAt: Date?
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        content: String,
        source: MemorySource,
        tags: [String] = [],
        sensitivity: SensitivityLevel = .normal,
        cloudSyncAllowed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        expiresAt: Date? = nil,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.source = source
        self.tags = tags
        self.sensitivity = sensitivity
        self.cloudSyncAllowed = cloudSyncAllowed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.expiresAt = expiresAt
        self.deletedAt = deletedAt
    }
}

public enum MemorySource: String, Codable, CaseIterable, Sendable {
    case manual
    case chat
    case shareExtension
    case documentPicker
    case photosPicker
    case appIntent
    case calendar
    case reminders
    case externalConnector
}

public enum SensitivityLevel: String, Codable, CaseIterable, Sendable {
    case publicInfo
    case normal
    case privateInfo
    case confidential
    case highlySensitive
}
