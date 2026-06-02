import Foundation

public struct AICompletionRequest: Codable, Equatable, Sendable {
    public var systemPrompt: String
    public var userPrompt: String
    public var memoryContext: [MemoryRecord]
    public var allowedCapabilities: [CapabilityKey]

    public init(
        systemPrompt: String,
        userPrompt: String,
        memoryContext: [MemoryRecord] = [],
        allowedCapabilities: [CapabilityKey] = []
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.memoryContext = memoryContext
        self.allowedCapabilities = allowedCapabilities
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
