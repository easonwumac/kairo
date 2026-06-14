import Foundation

public struct ChatThread: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?
    public var messages: [ChatMessage]
    public var lastPromptTokens: Int?
    public var rollingSummary: String?
    public var compactedThroughMessageID: UUID?
    public var compactionGeneration: Int

    public init(
        id: UUID = UUID(),
        title: String = "New Chat",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        messages: [ChatMessage] = [],
        lastPromptTokens: Int? = nil,
        rollingSummary: String? = nil,
        compactedThroughMessageID: UUID? = nil,
        compactionGeneration: Int = 0
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.messages = messages
        self.lastPromptTokens = lastPromptTokens
        self.rollingSummary = rollingSummary
        self.compactedThroughMessageID = compactedThroughMessageID
        self.compactionGeneration = compactionGeneration
    }

    public var lastMessagePreview: String {
        guard let message = messages.last else {
            return "No messages yet"
        }
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            return String(text.prefix(80))
        }
        guard !message.attachments.isEmpty else {
            return "No messages yet"
        }
        return "Attachments: " + message.attachments.map(\.displayName).joined(separator: ", ")
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

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case createdAt
        case updatedAt
        case deletedAt
        case messages
        case lastPromptTokens
        case rollingSummary
        case compactedThroughMessageID
        case compactionGeneration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        self.messages = try container.decode([ChatMessage].self, forKey: .messages)
        self.lastPromptTokens = try container.decodeIfPresent(Int.self, forKey: .lastPromptTokens)
        self.rollingSummary = try container.decodeIfPresent(String.self, forKey: .rollingSummary)
        self.compactedThroughMessageID = try container.decodeIfPresent(UUID.self, forKey: .compactedThroughMessageID)
        self.compactionGeneration = try container.decodeIfPresent(Int.self, forKey: .compactionGeneration) ?? 0
    }
}

public struct ChatMessage: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var role: ChatRole
    public var text: String
    public var createdAt: Date
    public var proposedActions: [AgentAction]
    public var toolCandidates: [AgentToolInvocationCandidate]
    public var attachments: [ChatAttachment]
    public var status: ChatMessageStatus
    public var memoryContextCount: Int
    public var reasoningText: String?
    public var rawModelResponse: String?
    public var promptPipelineTrace: PromptPipelineTrace?
    public var pipelineDiagnosticResult: PipelineDiagnosticResult?

    public init(
        id: UUID = UUID(),
        role: ChatRole,
        text: String,
        createdAt: Date = Date(),
        proposedActions: [AgentAction] = [],
        toolCandidates: [AgentToolInvocationCandidate] = [],
        attachments: [ChatAttachment] = [],
        status: ChatMessageStatus = .sent,
        memoryContextCount: Int = 0,
        reasoningText: String? = nil,
        rawModelResponse: String? = nil,
        promptPipelineTrace: PromptPipelineTrace? = nil,
        pipelineDiagnosticResult: PipelineDiagnosticResult? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.proposedActions = proposedActions
        self.toolCandidates = toolCandidates
        self.attachments = attachments
        self.status = status
        self.memoryContextCount = memoryContextCount
        self.reasoningText = reasoningText
        self.rawModelResponse = rawModelResponse
        self.promptPipelineTrace = promptPipelineTrace
        self.pipelineDiagnosticResult = pipelineDiagnosticResult ?? rawModelResponse.flatMap(PipelineDiagnosticResult.parse)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case role
        case text
        case createdAt
        case proposedActions
        case toolCandidates
        case attachments
        case status
        case memoryContextCount
        case reasoningText
        case rawModelResponse
        case promptPipelineTrace
        case pipelineDiagnosticResult
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.role = try container.decode(ChatRole.self, forKey: .role)
        self.text = try container.decode(String.self, forKey: .text)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.proposedActions = try container.decodeIfPresent([AgentAction].self, forKey: .proposedActions) ?? []
        self.toolCandidates = try container.decodeIfPresent([AgentToolInvocationCandidate].self, forKey: .toolCandidates) ?? []
        self.attachments = try container.decodeIfPresent([ChatAttachment].self, forKey: .attachments) ?? []
        self.status = try container.decodeIfPresent(ChatMessageStatus.self, forKey: .status) ?? .sent
        self.memoryContextCount = try container.decodeIfPresent(Int.self, forKey: .memoryContextCount) ?? 0
        self.reasoningText = try container.decodeIfPresent(String.self, forKey: .reasoningText)
        self.rawModelResponse = try container.decodeIfPresent(String.self, forKey: .rawModelResponse)
        self.promptPipelineTrace = try container.decodeIfPresent(PromptPipelineTrace.self, forKey: .promptPipelineTrace)
        self.pipelineDiagnosticResult = try container.decodeIfPresent(PipelineDiagnosticResult.self, forKey: .pipelineDiagnosticResult)
            ?? rawModelResponse.flatMap(PipelineDiagnosticResult.parse)
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
