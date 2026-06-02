import Foundation

public struct ChatThread: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var messages: [ChatMessage]

    public init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.messages = messages
    }

    public var lastMessagePreview: String {
        guard let text = messages.last?.text.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return "No messages yet"
        }
        return String(text.prefix(80))
    }

    public mutating func append(_ message: ChatMessage, now: Date = Date()) {
        messages.append(message)
        updatedAt = now
        if title == "New Chat", message.role == .user {
            title = Self.title(from: message.text)
        }
    }

    public static func title(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "New Chat" }
        return String(trimmed.prefix(42))
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var role: ChatRole
    public var text: String
    public var createdAt: Date
    public var proposedActions: [AgentAction]
    public var status: ChatMessageStatus

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date = Date(),
        proposedActions: [AgentAction] = [],
        status: ChatMessageStatus = .sent
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.proposedActions = proposedActions
        self.status = status
    }
}

public enum ChatRole: String, Codable, Equatable, Sendable {
    case user
    case assistant
    case system
}

public enum ChatMessageStatus: String, Codable, Equatable, Sendable {
    case sending
    case sent
    case failed
}
