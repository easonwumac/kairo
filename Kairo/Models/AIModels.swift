import Foundation

public enum ChatPrivacyMode: String, Codable, Equatable, Sendable {
    case standard
    case privateChat
}

public struct AICompletionRequest: Codable, Equatable, Sendable {
    public var systemPrompt: String
    public var userPrompt: String
    public var memoryContext: [MemoryRecord]
    public var allowedCapabilities: [CapabilityKey]
    public var attachmentContext: [ChatAttachment]
    public var toolContext: String?
    public var privacyMode: ChatPrivacyMode

    public init(
        systemPrompt: String,
        userPrompt: String,
        memoryContext: [MemoryRecord] = [],
        allowedCapabilities: [CapabilityKey] = [],
        attachmentContext: [ChatAttachment] = [],
        toolContext: String? = nil,
        privacyMode: ChatPrivacyMode = .standard
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.memoryContext = memoryContext
        self.allowedCapabilities = allowedCapabilities
        self.attachmentContext = attachmentContext
        self.toolContext = toolContext
        self.privacyMode = privacyMode
    }
}

public struct AICompletionResponse: Codable, Equatable, Sendable {
    public var message: String
    public var proposedActions: [AgentAction]
    public var toolCandidates: [AgentToolInvocationCandidate]
    public var memoryContextCount: Int

    public init(
        message: String,
        proposedActions: [AgentAction] = [],
        toolCandidates: [AgentToolInvocationCandidate] = [],
        memoryContextCount: Int = 0
    ) {
        self.message = message
        self.proposedActions = proposedActions
        self.toolCandidates = toolCandidates
        self.memoryContextCount = memoryContextCount
    }
}

public struct AIEmbeddingRequest: Codable, Equatable, Sendable {
    public var input: String
}

public struct AIEmbeddingResponse: Codable, Equatable, Sendable {
    public var vector: [Double]
}
