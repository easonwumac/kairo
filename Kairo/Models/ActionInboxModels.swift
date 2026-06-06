import Foundation

public struct ActionInboxItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var source: ActionInboxSource
    public var sourceItemIDs: [UUID]
    public var attachments: [ChatAttachment]
    public var summary: ActionInboxSummary
    public var suggestions: [ActionInboxSuggestion]
    public var receivedAt: Date

    public init(
        id: UUID = UUID(),
        source: ActionInboxSource,
        sourceItemIDs: [UUID],
        attachments: [ChatAttachment],
        summary: ActionInboxSummary,
        suggestions: [ActionInboxSuggestion],
        receivedAt: Date = Date()
    ) {
        self.id = id
        self.source = source
        self.sourceItemIDs = sourceItemIDs
        self.attachments = attachments
        self.summary = summary
        self.suggestions = suggestions
        self.receivedAt = receivedAt
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
