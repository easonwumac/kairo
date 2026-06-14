import Foundation

public struct ActionInboxItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var source: ActionInboxSource
    public var sourceItemIDs: [UUID]
    public var attachments: [ChatAttachment]
    public var summary: ActionInboxSummary
    public var triage: ActionInboxTriage
    public var suggestions: [ActionInboxSuggestion]
    public var receivedAt: Date

    public init(
        id: UUID = UUID(),
        source: ActionInboxSource,
        sourceItemIDs: [UUID],
        attachments: [ChatAttachment],
        summary: ActionInboxSummary,
        triage: ActionInboxTriage = .captureOnly,
        suggestions: [ActionInboxSuggestion],
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.sourceItemIDs = sourceItemIDs
        self.attachments = attachments
        self.summary = summary
        self.triage = triage
        self.suggestions = suggestions
        self.receivedAt = receivedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case source
        case sourceItemIDs
        case attachments
        case summary
        case triage
        case suggestions
        case receivedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        source = try container.decode(ActionInboxSource.self, forKey: .source)
        sourceItemIDs = try container.decode([UUID].self, forKey: .sourceItemIDs)
        attachments = try container.decode([ChatAttachment].self, forKey: .attachments)
        summary = try container.decode(ActionInboxSummary.self, forKey: .summary)
        triage = try container.decodeIfPresent(ActionInboxTriage.self, forKey: .triage) ?? .captureOnly
        suggestions = try container.decode([ActionInboxSuggestion].self, forKey: .suggestions)
        receivedAt = try container.decode(Date.self, forKey: .receivedAt)
    }
}

public enum ActionInboxSource: String, Codable, Equatable, Sendable {
    case shareExtension
    case chatInput
    case shortcutInput
}

public struct ActionInboxSummary: Codable, Equatable, Sendable {
    public var title: String
    public var bullets: [String]

    public init(title: String, bullets: [String] = []) {
        self.title = title
        self.bullets = bullets
    }
}

public enum ActionInboxTriage: String, Codable, CaseIterable, Sendable {
    case captureOnly
    case createInfoPage
    case createReminder
    case saveMemory
    case openHandoff
}

public struct ActionInboxSuggestion: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: ActionInboxSuggestionKind
    public var title: String
    public var action: AgentAction?
    public var requiresConfirmation: Bool

    public init(
        id: UUID = UUID(),
        kind: ActionInboxSuggestionKind,
        title: String,
        action: AgentAction? = nil,
        requiresConfirmation: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.action = action
        self.requiresConfirmation = requiresConfirmation
    }
}

public enum ActionInboxSuggestionKind: String, Codable, CaseIterable, Sendable {
    case summary
    case reminderDraft
    case calendarDraft
    case emailDraft
    case messageDraft
    case phoneHandoff
    case mapsHandoff
    case webSearchHandoff
    case memorySave
    case setupRequired
    case unsupported
}
