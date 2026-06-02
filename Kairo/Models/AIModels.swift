import Foundation

public struct AICompletionRequest: Codable, Equatable, Sendable {
    public var systemPrompt: String
    public var userPrompt: String
    public var memoryContext: [MemoryRecord]
    public var allowedCapabilities: [CapabilityKey]
    public var attachmentContext: [ChatAttachment]
    public var toolContext: String?

    public init(
        systemPrompt: String,
        userPrompt: String,
        memoryContext: [MemoryRecord] = [],
        allowedCapabilities: [CapabilityKey] = [],
        attachmentContext: [ChatAttachment] = [],
        toolContext: String? = nil
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.memoryContext = memoryContext
        self.allowedCapabilities = allowedCapabilities
        self.attachmentContext = attachmentContext
        self.toolContext = toolContext
    }
}

public struct AICompletionResponse: Codable, Equatable, Sendable {
    public var message: String
    public var proposedActions: [AgentAction]

    public init(message: String, proposedActions: [AgentAction] = []) {
        self.message = message
        self.proposedActions = proposedActions
    }
}

public struct AIEmbeddingRequest: Codable, Equatable, Sendable {
    public var input: String
}

public struct AIEmbeddingResponse: Codable, Equatable, Sendable {
    public var vector: [Double]
}
