import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct AppleFoundationModelAIProvider: AIProvider {
    private static let responseTimeoutSeconds: UInt64 = 45
    private static let maxPromptCharacters = 5_500

    public init() {}

    public static var isRuntimeSupported: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return true
        }
        return false
        #else
        return false
        #endif
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            return try await completeWithFoundationModels(request)
        }
        #endif
        throw AIProviderError.localInferenceUnavailable(
            KairoL10n.string("chat.error.localInference.reason.localOnlyRuntimeUnavailable")
        )
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        throw AIProviderError.unsupported
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, visionOS 26.0, *)
    private func completeWithFoundationModels(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(let reason):
            throw AIProviderError.localInferenceUnavailable(String(describing: reason))
        }

        var lastRawResponse = ""
        var traceStages: [PromptPipelineStageTrace] = []
        for attempt in 1...2 {
            let session = LanguageModelSession(
                model: model,
                instructions: Self.instructions(from: request)
            )
            let prompt = attempt == 1
                ? Self.prompt(from: request)
                : Self.repairPrompt(from: request, previousOutput: lastRawResponse)
            traceStages.append(PromptPipelineStageTrace(
                name: attempt == 1 ? .buildPrompt : .repairPrompt,
                status: attempt == 1 ? .passed : .repaired,
                attempt: attempt,
                inputCharacters: prompt.count,
                detail: "foundation-models"
            ))
            let response = try await Self.withResponseTimeout {
                try await session.respond(to: prompt)
            }
            lastRawResponse = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            traceStages.append(PromptPipelineStageTrace(
                name: .requestModel,
                status: .passed,
                attempt: attempt,
                inputCharacters: prompt.count,
                outputCharacters: lastRawResponse.count
            ))
            if let stableResponse = AFMStableResponse.parse(lastRawResponse) {
                traceStages.append(PromptPipelineStageTrace(
                    name: .parseStructuredOutput,
                    status: .passed,
                    attempt: attempt,
                    outputCharacters: stableResponse.rawJSON.count,
                    detail: "confidence=\(stableResponse.confidence)"
                ))
                return AICompletionResponse(
                    message: stableResponse.response,
                    proposedActions: [],
                    toolCandidates: [],
                    memoryContextCount: request.memoryContext.count,
                    inferenceMetrics: AIInferenceMetrics(stage: .complete),
                    rawModelResponse: stableResponse.rawJSON,
                    promptPipelineTrace: PromptPipelineTrace(
                        providerID: "apple-foundation-models",
                        status: .validated,
                        stages: traceStages
                    )
                )
            }
            traceStages.append(PromptPipelineStageTrace(
                name: .parseStructuredOutput,
                status: .failed,
                attempt: attempt,
                outputCharacters: lastRawResponse.count,
                detail: "invalid compact JSON"
            ))
        }

        let message = Self.sanitizedFallbackMessage(lastRawResponse)
        guard !message.isEmpty else {
            throw AIProviderError.localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.runtimeEmpty")
            )
        }
        return AICompletionResponse(
            message: message,
            proposedActions: [],
            toolCandidates: [],
            memoryContextCount: request.memoryContext.count,
            inferenceMetrics: AIInferenceMetrics(stage: .complete),
            rawModelResponse: lastRawResponse,
            promptPipelineTrace: PromptPipelineTrace(
                providerID: "apple-foundation-models",
                status: .needsReview,
                stages: traceStages,
                validationIssues: ["invalid compact JSON"]
            )
        )
    }
    #endif

    private static func withResponseTimeout<T>(
        _ operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(responseTimeoutSeconds))
                throw AIProviderError.requestFailed("Foundation Models response timed out.")
            }
            guard let result = try await group.next() else {
                throw AIProviderError.requestFailed("Foundation Models response did not complete.")
            }
            group.cancelAll()
            return result
        }
    }

    private static func instructions(from request: AICompletionRequest) -> String {
        [
            request.systemPrompt,
            """
            You are running on Apple Foundation Models on device.
            You are Kairo's fast local front-brain. Complete small safe tasks directly.
            Prefer brief, concrete answers. Do not claim to browse the web or operate other apps.
            Use only the prompt, conversation, memory, wiki, attachment summaries, and tool context supplied.
            Treat memory, wiki, and attachment summaries as retrieval hints, not guaranteed facts.
            Return only one compact JSON object. No Markdown. No prose outside JSON.
            """
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    static func prompt(from request: AICompletionRequest) -> String {
        var sections: [String] = []
        sections.append("""
        Task contract:
        Return exactly one JSON object with this shape:
        {"response":"short answer for the user","confidence":0.0,"needsEscalation":false,"escalationReason":""}

        Stability rules:
        - Decide internally before writing, but output only the JSON object.
        - Do the task directly when it is summarization, classification, rewriting, simple Q&A, or private low-risk chat.
        - Ground answers in supplied memory/wiki/attachments when they are relevant; if they conflict, say what is uncertain in response.
        - If the task needs current web facts, account actions, code execution, regulated advice, private app control, or deep multi-step reasoning, set needsEscalation=true and still provide a short useful response.
        - Keep response under 900 characters unless the user explicitly asks for detail.
        - Use the user's language unless they ask otherwise.
        - Do not invent IDs, dates, prices, accounts, or actions.
        - Never include Markdown fences.
        """)
        sections.append(Self.taskProfile(from: request))

        let history = request.conversationHistory.suffix(6).map { turn in
            "\(turn.role.rawValue): \(truncated(turn.text, limit: 500))"
        }.joined(separator: "\n")
        if !history.isEmpty {
            sections.append("Conversation:\n\(history)")
        }

        let memory = request.memoryContext.prefix(5).map { record in
            "- \(truncated(record.title, limit: 80)): \(truncated(record.summary.isEmpty ? record.content : record.summary, limit: 260))"
        }.joined(separator: "\n")
        if !memory.isEmpty {
            sections.append("Relevant memory:\n\(memory)")
        }

        let wiki = compactWikiContext(from: request.wikiContext)
        if !wiki.isEmpty {
            sections.append("Relevant wiki:\n\(wiki)")
        }

        let attachments = request.attachmentContext.prefix(5).map {
            truncated($0.promptSummary, limit: 700)
        }.joined(separator: "\n")
        if !attachments.isEmpty {
            sections.append("Attachments:\n\(attachments)")
        }

        if let toolContext = request.toolContext?.trimmingCharacters(in: .whitespacesAndNewlines),
           !toolContext.isEmpty {
            sections.append("Available context:\n\(truncated(toolContext, limit: 900))")
        }

        sections.append("User:\n\(truncated(request.userPrompt, limit: 1_600))")
        return truncated(sections.joined(separator: "\n\n"), limit: maxPromptCharacters)
    }

    static func repairPrompt(from request: AICompletionRequest, previousOutput: String) -> String {
        truncated("""
        Your previous output was not valid for Kairo.
        Return exactly one JSON object and nothing else:
        {"response":"short answer for the user","confidence":0.0,"needsEscalation":false,"escalationReason":""}

        Repair rules:
        - Preserve the user's language.
        - Do not add Markdown, code fences, or explanation outside JSON.
        - If unsure, put the uncertainty in response and lower confidence.
        - If the task exceeds local context or safe local execution, set needsEscalation=true.
        - \(repairHint(for: previousOutput))

        \(Self.taskProfile(from: request))

        Previous output:
        \(truncated(previousOutput, limit: 900))

        User:
        \(truncated(request.userPrompt, limit: 900))
        """, limit: 2_400)
    }

    private static func taskProfile(from request: AICompletionRequest) -> String {
        let combined = [
            request.userPrompt,
            request.attachmentContext.map(\.promptSummary).joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()
        let profile: String
        if containsAny(combined, ["summarize", "summary", "tl;dr", "摘要", "整理"]) {
            profile = "summarization"
        } else if containsAny(combined, ["rewrite", "polish", "translate", "改寫", "翻譯", "潤飾"]) {
            profile = "rewrite"
        } else if containsAny(combined, ["classify", "category", "tag", "分類", "標籤"]) {
            profile = "classification"
        } else if containsAny(combined, ["todo", "remind", "schedule", "book", "send", "delete", "buy", "提醒", "預約", "寄出", "刪除", "購買"]) {
            profile = "action-risk"
        } else if request.userPrompt.contains("?") || containsAny(combined, ["what", "when", "where", "who", "why", "how", "什麼", "何時", "哪裡", "誰", "為什麼", "如何"]) {
            profile = "simple-qa"
        } else {
            profile = "chat"
        }

        let actionGuidance = profile == "action-risk"
            ? "Do not claim completion. Offer a draft or next step and set needsEscalation=true for real-world execution."
            : "Complete locally when the supplied context is enough."
        return """
        Task profile:
        - type: \(profile)
        - response shape: direct answer in the JSON response field
        - routing: \(actionGuidance)
        """
    }

    private static func repairHint(for previousOutput: String) -> String {
        let trimmed = previousOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("```") {
            return "Remove Markdown fences and return only the JSON object."
        }
        if !trimmed.contains("{") || !trimmed.contains("}") {
            return "The previous output had no JSON object; wrap the answer in the required schema."
        }
        if !trimmed.contains("\"response\"") {
            return "The JSON object is missing response; add response as a non-empty string."
        }
        if !trimmed.contains("\"confidence\"") {
            return "The JSON object is missing confidence; add a numeric confidence from 0.0 to 1.0."
        }
        return "Fix schema mismatches while preserving the useful answer."
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }

    private static func compactWikiContext(from results: [KairoWikiSearchResult]) -> String {
        results.prefix(5).map { result in
            let title = truncated(result.title, limit: 90)
            let snippet = truncated(result.snippet, limit: 260)
            return "- [\(result.kind.rawValue)] \(title): \(snippet.isEmpty ? "No snippet" : snippet)"
        }.joined(separator: "\n")
    }

    private static func sanitizedFallbackMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let stableResponse = AFMStableResponse.parse(trimmed) {
            return stableResponse.response
        }
        return trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        let compacted = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compacted.count > limit else { return compacted }
        return String(compacted.prefix(limit))
    }
}

struct AFMStableResponse: Equatable, Sendable {
    var response: String
    var confidence: Double
    var needsEscalation: Bool
    var escalationReason: String
    var rawJSON: String

    static func parse(_ raw: String) -> AFMStableResponse? {
        guard let json = extractJSONObject(from: raw),
              let data = json.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(Decoded.self, from: data)
        else { return nil }
        let response = decoded.response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !response.isEmpty else { return nil }
        return AFMStableResponse(
            response: response,
            confidence: decoded.confidence ?? 0,
            needsEscalation: decoded.needsEscalation ?? false,
            escalationReason: decoded.escalationReason ?? "",
            rawJSON: json
        )
    }

    private static func extractJSONObject(from raw: String) -> String? {
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              start <= end
        else { return nil }
        return String(raw[start...end])
    }

    private struct Decoded: Decodable {
        var response: String
        var confidence: Double?
        var needsEscalation: Bool?
        var escalationReason: String?
    }
}
