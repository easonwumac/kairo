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
    public var wikiContext: [KairoWikiSearchResult]
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
        wikiContext: [KairoWikiSearchResult] = [],
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
        self.wikiContext = wikiContext
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
    public var rawModelResponse: String?
    public var infoPageDraft: InfoPageDraft?
    public var promptPipelineTrace: PromptPipelineTrace?
    public var pipelineDiagnosticResult: PipelineDiagnosticResult?

    public init(
        message: String,
        proposedActions: [AgentAction] = [],
        toolCandidates: [AgentToolInvocationCandidate] = [],
        memoryContextCount: Int = 0,
        reasoningText: String? = nil,
        inferenceMetrics: AIInferenceMetrics? = nil,
        libraryClassification: LibraryClassificationResponse? = nil,
        rawModelResponse: String? = nil,
        infoPageDraft: InfoPageDraft? = nil,
        promptPipelineTrace: PromptPipelineTrace? = nil,
        pipelineDiagnosticResult: PipelineDiagnosticResult? = nil
    ) {
        self.message = message
        self.proposedActions = proposedActions
        self.toolCandidates = toolCandidates
        self.memoryContextCount = memoryContextCount
        self.reasoningText = reasoningText
        self.inferenceMetrics = inferenceMetrics
        self.libraryClassification = libraryClassification
        self.rawModelResponse = rawModelResponse
        self.infoPageDraft = infoPageDraft
        self.promptPipelineTrace = promptPipelineTrace
        self.pipelineDiagnosticResult = pipelineDiagnosticResult ?? rawModelResponse.flatMap(PipelineDiagnosticResult.parse)
    }
}

public struct PipelineDiagnosticResult: Codable, Equatable, Sendable {
    public enum Verdict: String, Codable, Equatable, Sendable {
        case pass
        case watch
        case fail
    }

    public var verdict: Verdict
    public var likelyFailure: String
    public var promptFix: String
    public var confidence: Double

    public init(
        verdict: Verdict,
        likelyFailure: String,
        promptFix: String,
        confidence: Double
    ) {
        self.verdict = verdict
        self.likelyFailure = likelyFailure
        self.promptFix = promptFix
        self.confidence = confidence
    }

    public static func parse(_ raw: String) -> PipelineDiagnosticResult? {
        guard let json = extractJSONObject(from: raw),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(PipelineDiagnosticResult.self, from: data)
        else { return nil }
        return decoded
    }

    private static func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start <= end
        else { return nil }
        return String(raw[start...end])
    }
}

public struct PromptPipelineTrace: Codable, Equatable, Sendable {
    public enum Status: String, Codable, Equatable, Sendable {
        case validated
        case needsRepair
        case needsReview
        case failed
    }

    public var providerID: String
    public var status: Status
    public var stages: [PromptPipelineStageTrace]
    public var validationIssues: [String]

    public init(
        providerID: String,
        status: Status,
        stages: [PromptPipelineStageTrace] = [],
        validationIssues: [String] = []
    ) {
        self.providerID = providerID
        self.status = status
        self.stages = stages
        self.validationIssues = validationIssues
    }

    public var attemptCount: Int {
        let attempts = stages.compactMap(\.attempt)
        return attempts.max() ?? (stages.isEmpty ? 0 : 1)
    }

    public var totalOutputCharacters: Int {
        stages.compactMap(\.outputCharacters).reduce(0, +)
    }

    public var repairedStageCount: Int {
        stages.filter { $0.status == .repaired }.count
    }

    public var failedStageCount: Int {
        stages.filter { $0.status == .failed }.count
    }
}

public struct PromptPipelineStageTrace: Codable, Equatable, Sendable {
    public enum Name: String, Codable, Equatable, Sendable {
        case buildPrompt
        case requestModel
        case parseStructuredOutput
        case validateDraft
        case repairPrompt
        case routeEscalation
        case finalize
    }

    public enum Status: String, Codable, Equatable, Sendable {
        case pending
        case passed
        case repaired
        case failed
    }

    public var name: Name
    public var status: Status
    public var attempt: Int?
    public var inputCharacters: Int?
    public var outputCharacters: Int?
    public var detail: String?

    public init(
        name: Name,
        status: Status,
        attempt: Int? = nil,
        inputCharacters: Int? = nil,
        outputCharacters: Int? = nil,
        detail: String? = nil
    ) {
        self.name = name
        self.status = status
        self.attempt = attempt
        self.inputCharacters = inputCharacters
        self.outputCharacters = outputCharacters
        self.detail = detail
    }
}

public struct ChatPromptPipelineHealthSummary: Equatable, Sendable {
    public enum Level: String, Equatable, Sendable {
        case stable
        case watch
        case needsTuning
    }

    public var providerID: String
    public var traceCount: Int
    public var validatedCount: Int
    public var repairCount: Int
    public var failedCount: Int
    public var latestStatus: PromptPipelineTrace.Status
    public var unstableStageName: PromptPipelineStageTrace.Name?
    public var latestValidationIssue: String?

    public init(
        providerID: String,
        traceCount: Int,
        validatedCount: Int,
        repairCount: Int,
        failedCount: Int,
        latestStatus: PromptPipelineTrace.Status,
        unstableStageName: PromptPipelineStageTrace.Name? = nil,
        latestValidationIssue: String? = nil
    ) {
        self.providerID = providerID
        self.traceCount = traceCount
        self.validatedCount = validatedCount
        self.repairCount = repairCount
        self.failedCount = failedCount
        self.latestStatus = latestStatus
        self.unstableStageName = unstableStageName
        self.latestValidationIssue = latestValidationIssue
    }

    public var validationRate: Double {
        guard traceCount > 0 else { return 0 }
        return Double(validatedCount) / Double(traceCount)
    }

    public var level: Level {
        if failedCount > 0 || latestStatus == .failed {
            return .needsTuning
        }
        if repairCount > 0 || latestStatus == .needsRepair || latestStatus == .needsReview || validationRate < 0.75 {
            return .watch
        }
        return .stable
    }

    public var shouldOfferModelTuning: Bool {
        level != .stable
    }
}

public struct LibraryClassificationResponse: Codable, Equatable, Sendable {
    public var assetDescription: String?
    public var ocrSummary: String?
    public var keywords: [String]
    public var candidateCategories: [InfoPageDraftCategoryCandidate]
    public var selectedSubcategoryIDs: [String]
    public var suggestedSubcategoryName: String?
    public var needsCategoryChoice: Bool
    public var nextStep: String?

    public init(
        assetDescription: String? = nil,
        ocrSummary: String? = nil,
        keywords: [String] = [],
        candidateCategories: [InfoPageDraftCategoryCandidate] = [],
        selectedSubcategoryIDs: [String] = [],
        suggestedSubcategoryName: String? = nil,
        needsCategoryChoice: Bool = false,
        nextStep: String? = nil
    ) {
        self.assetDescription = assetDescription
        self.ocrSummary = ocrSummary
        self.keywords = keywords
        self.candidateCategories = candidateCategories
        self.selectedSubcategoryIDs = selectedSubcategoryIDs
        self.suggestedSubcategoryName = suggestedSubcategoryName
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
