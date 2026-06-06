import Foundation

public enum ChatPrivacyMode: String, Codable, Equatable, Sendable {
    case standard
    case privateChat
}

public struct AICompletionRequest: Codable, Equatable, Sendable {
    public var systemPrompt: String
    public var userPrompt: String
    public var conversationID: String?
    public var conversationHistory: [AIConversationTurn]
    public var memoryContext: [MemoryRecord]
    public var allowedCapabilities: [CapabilityKey]
    public var attachmentContext: [ChatAttachment]
    public var toolContext: String?
    public var privacyMode: ChatPrivacyMode

    public init(
        systemPrompt: String,
        userPrompt: String,
        conversationID: String? = nil,
        conversationHistory: [AIConversationTurn] = [],
        memoryContext: [MemoryRecord] = [],
        allowedCapabilities: [CapabilityKey] = [],
        attachmentContext: [ChatAttachment] = [],
        toolContext: String? = nil,
        privacyMode: ChatPrivacyMode = .standard
    ) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.conversationID = conversationID
        self.conversationHistory = conversationHistory
        self.memoryContext = memoryContext
        self.allowedCapabilities = allowedCapabilities
        self.attachmentContext = attachmentContext
        self.toolContext = toolContext
        self.privacyMode = privacyMode
    }
}

public struct AIConversationTurn: Codable, Equatable, Sendable {
    public enum Role: String, Codable, Equatable, Sendable {
        case user
        case assistant
    }

    public var role: Role
    public var text: String

    public init(role: Role, text: String) {
        self.role = role
        self.text = text
    }
}

public struct AICompletionResponse: Codable, Equatable, Sendable {
    public var message: String
    public var proposedActions: [AgentAction]
    public var toolCandidates: [AgentToolInvocationCandidate]
    public var memoryContextCount: Int
    public var reasoningText: String?
    public var inferenceMetrics: AIInferenceMetrics?
    public var libraryClassification: LibraryClassificationResponse?

    public init(
        message: String,
        proposedActions: [AgentAction] = [],
        toolCandidates: [AgentToolInvocationCandidate] = [],
        memoryContextCount: Int = 0,
        reasoningText: String? = nil,
        inferenceMetrics: AIInferenceMetrics? = nil,
        libraryClassification: LibraryClassificationResponse? = nil
    ) {
        self.message = message
        self.proposedActions = proposedActions
        self.toolCandidates = toolCandidates
        self.memoryContextCount = memoryContextCount
        self.reasoningText = reasoningText
        self.inferenceMetrics = inferenceMetrics
        self.libraryClassification = libraryClassification
    }
}

public struct LibraryClassificationResponse: Codable, Equatable, Sendable {
    public var assetDescription: String?
    public var ocrSummary: String?
    public var keywords: [String]
    public var candidateCategories: [InfoPageDraftCategoryCandidate]
    public var needsCategoryChoice: Bool
    public var nextStep: String?

    public init(
        assetDescription: String? = nil,
        ocrSummary: String? = nil,
        keywords: [String] = [],
        candidateCategories: [InfoPageDraftCategoryCandidate] = [],
        needsCategoryChoice: Bool = false,
        nextStep: String? = nil
    ) {
        self.assetDescription = assetDescription
        self.ocrSummary = ocrSummary
        self.keywords = keywords
        self.candidateCategories = candidateCategories
        self.needsCategoryChoice = needsCategoryChoice
        self.nextStep = nextStep
    }
}

public struct AIInferenceMetrics: Codable, Equatable, Sendable {
    public enum Stage: String, Codable, Equatable, Sendable {
        case preparingInput
        case loadingModel
        case prefill
        case generation
        case complete
    }

    public var stage: Stage?
    public var promptTokens: Int?
    public var promptTokensProcessed: Int?
    public var generatedTokens: Int?
    public var promptTokensPerSecond: Double?
    public var generationTokensPerSecond: Double?
    public var promptSecondsRemaining: Double?

    public init(
        stage: Stage? = nil,
        promptTokens: Int? = nil,
        promptTokensProcessed: Int? = nil,
        generatedTokens: Int? = nil,
        promptTokensPerSecond: Double? = nil,
        generationTokensPerSecond: Double? = nil,
        promptSecondsRemaining: Double? = nil
    ) {
        self.stage = stage
        self.promptTokens = promptTokens
        self.promptTokensProcessed = promptTokensProcessed
        self.generatedTokens = generatedTokens
        self.promptTokensPerSecond = promptTokensPerSecond
        self.generationTokensPerSecond = generationTokensPerSecond
        self.promptSecondsRemaining = promptSecondsRemaining
    }
}

public struct AIEmbeddingRequest: Codable, Equatable, Sendable {
    public var input: String
}

public struct AIEmbeddingResponse: Codable, Equatable, Sendable {
    public var vector: [Double]
}
