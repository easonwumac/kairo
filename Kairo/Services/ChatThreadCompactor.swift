import Foundation

public struct ChatContextBudget: Sendable, Equatable {
    public var contextWindow: Int
    public var reservedOutputTokens: Int
    public var softThresholdRatio: Double
    public var hardThresholdRatio: Double

    public init(
        contextWindow: Int,
        reservedOutputTokens: Int = 1280,
        softThresholdRatio: Double = 0.70,
        hardThresholdRatio: Double = 0.85
    ) {
        self.contextWindow = max(1024, contextWindow)
        self.reservedOutputTokens = max(256, reservedOutputTokens)
        self.softThresholdRatio = min(0.95, max(0.10, softThresholdRatio))
        self.hardThresholdRatio = min(0.98, max(softThresholdRatio + 0.01, hardThresholdRatio))
    }

    public var inputBudget: Int {
        max(512, contextWindow - reservedOutputTokens)
    }

    public var softThresholdTokens: Int {
        Int(Double(inputBudget) * softThresholdRatio)
    }

    public var hardThresholdTokens: Int {
        Int(Double(inputBudget) * hardThresholdRatio)
    }

    public static let conservativeDefault = ChatContextBudget(contextWindow: 8192)
    public static let openAICloudDefault = ChatContextBudget(contextWindow: 128_000, reservedOutputTokens: 4096)
}

public enum ChatContextPressure: Sendable, Equatable {
    case ok
    case soft
    case hard
}

public struct ChatCompactionResult: Sendable, Equatable {
    public var thread: ChatThread
    public var summarizedMessageCount: Int
    public var newRollingSummary: String?
}

public protocol ChatThreadCompacting: Sendable {
    func pressure(
        for thread: ChatThread,
        additionalUserTextChars: Int,
        budget: ChatContextBudget
    ) -> ChatContextPressure

    func compact(
        _ thread: ChatThread,
        budget: ChatContextBudget
    ) async throws -> ChatCompactionResult
}

public struct DefaultChatThreadCompactor: ChatThreadCompacting {
    public let summarizer: any AIProvider
    public let keepRecentTurns: Int
    public let minTurnsToCompact: Int
    public let summaryMaxChars: Int
    public let systemOverheadTokens: Int

    public init(
        summarizer: any AIProvider,
        keepRecentTurns: Int = 6,
        minTurnsToCompact: Int = 4,
        summaryMaxChars: Int = 800,
        systemOverheadTokens: Int = 600
    ) {
        self.summarizer = summarizer
        self.keepRecentTurns = max(2, keepRecentTurns)
        self.minTurnsToCompact = max(2, minTurnsToCompact)
        self.summaryMaxChars = max(200, summaryMaxChars)
        self.systemOverheadTokens = max(100, systemOverheadTokens)
    }

    public func pressure(
        for thread: ChatThread,
        additionalUserTextChars: Int,
        budget: ChatContextBudget
    ) -> ChatContextPressure {
        let estimate = estimatedNextPromptTokens(
            for: thread,
            additionalUserTextChars: additionalUserTextChars
        )
        if estimate >= budget.hardThresholdTokens { return .hard }
        if estimate >= budget.softThresholdTokens { return .soft }
        return .ok
    }

    public func estimatedNextPromptTokens(
        for thread: ChatThread,
        additionalUserTextChars: Int
    ) -> Int {
        let nextUserTokens = Self.tokens(forChars: max(0, additionalUserTextChars))
        if let lastPrompt = thread.lastPromptTokens, lastPrompt > 0 {
            let lastAssistantChars = thread.messages.reversed().first(where: { $0.role == .assistant })?.text.count ?? 0
            return lastPrompt + Self.tokens(forChars: lastAssistantChars) + nextUserTokens
        }
        let messageChars = thread.messages.reduce(0) { partial, message in
            partial + message.text.count
        }
        let summaryChars = thread.rollingSummary?.count ?? 0
        return systemOverheadTokens
            + Self.tokens(forChars: messageChars + summaryChars + additionalUserTextChars)
    }

    public func compact(
        _ thread: ChatThread,
        budget: ChatContextBudget
    ) async throws -> ChatCompactionResult {
        let toCompact = compactableMessages(in: thread)
        guard toCompact.count >= minTurnsToCompact else {
            return ChatCompactionResult(
                thread: thread,
                summarizedMessageCount: 0,
                newRollingSummary: thread.rollingSummary
            )
        }
        let summaryRequest = makeSummaryRequest(
            existingSummary: thread.rollingSummary,
            messages: toCompact
        )
        let response = try await summarizer.complete(summaryRequest)
        let newSummary = Self.sanitizedSummary(response.message, limit: summaryMaxChars)
        guard !newSummary.isEmpty else {
            return ChatCompactionResult(
                thread: thread,
                summarizedMessageCount: 0,
                newRollingSummary: thread.rollingSummary
            )
        }
        let removedIDs = Set(toCompact.map(\.id))
        var compacted = thread
        compacted.messages = thread.messages.filter { !removedIDs.contains($0.id) }
        compacted.rollingSummary = newSummary
        compacted.compactedThroughMessageID = toCompact.last?.id
        compacted.compactionGeneration += 1
        compacted.lastPromptTokens = nil
        return ChatCompactionResult(
            thread: compacted,
            summarizedMessageCount: toCompact.count,
            newRollingSummary: newSummary
        )
    }

    private func compactableMessages(in thread: ChatThread) -> [ChatMessage] {
        let conversational = thread.messages.filter { $0.role == .user || $0.role == .assistant }
        let keep = keepRecentTurns * 2
        guard conversational.count > keep + 1 else { return [] }
        let keepIDs = Set(conversational.suffix(keep).map(\.id))
        return thread.messages.filter { message in
            (message.role == .user || message.role == .assistant) && !keepIDs.contains(message.id)
        }
    }

    private func makeSummaryRequest(
        existingSummary: String?,
        messages: [ChatMessage]
    ) -> AICompletionRequest {
        let transcript = messages.map { message in
            "\(message.role.rawValue): \(message.text.replacingOccurrences(of: "\n", with: " ").prefix(600))"
        }.joined(separator: "\n")
        let existing = existingSummary?.isEmpty == false ? existingSummary! : "(none)"
        let system = """
        You compress chat history into a concise factual brief for an iPhone assistant named Kairo.
        Keep names, decisions, action items, unresolved questions, and any user preferences.
        Drop pleasantries and repetition.
        Plain text only, no markdown, at most \(summaryMaxChars) characters.
        Write in the same language the user used most.
        """
        let user = """
        Previous summary (extend it, do not drop existing facts):
        \(existing)

        New conversation segment to absorb:
        \(transcript)

        Output the updated summary only.
        """
        return AICompletionRequest(systemPrompt: system, userPrompt: user)
    }

    private static func sanitizedSummary(_ raw: String, limit: Int) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= limit { return trimmed }
        return String(trimmed.prefix(limit))
    }

    static func tokens(forChars chars: Int) -> Int {
        guard chars > 0 else { return 0 }
        // Mixed-language rough estimate. CJK characters cost ~1-2 tokens each, ASCII ~0.25.
        // We use 0.4 tokens/char to bias toward compacting a little early rather than overflowing.
        return max(1, (chars * 2) / 5)
    }
}
