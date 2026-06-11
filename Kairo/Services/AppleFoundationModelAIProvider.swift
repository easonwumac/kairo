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
        for attempt in 1...2 {
            let session = LanguageModelSession(
                model: model,
                instructions: Self.instructions(from: request)
            )
            let prompt = attempt == 1
                ? Self.prompt(from: request)
                : Self.repairPrompt(from: request, previousOutput: lastRawResponse)
            let response = try await Self.withResponseTimeout {
                try await session.respond(to: prompt)
            }
            lastRawResponse = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            if let stableResponse = AFMStableResponse.parse(lastRawResponse) {
                return AICompletionResponse(
                    message: stableResponse.response,
                    proposedActions: [],
                    toolCandidates: [],
                    memoryContextCount: request.memoryContext.count,
                    inferenceMetrics: AIInferenceMetrics(stage: .complete),
                    rawModelResponse: stableResponse.rawJSON
                )
            }
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
            rawModelResponse: lastRawResponse
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
            If attachments are referenced, use only the metadata and text previews included in the prompt.
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
        - Do the task directly when it is summarization, classification, rewriting, simple Q&A, or private low-risk chat.
        - If the task needs current web facts, account actions, code execution, regulated advice, or deep multi-step reasoning, set needsEscalation=true and still provide a short useful response.
        - Keep response under 900 characters unless the user explicitly asks for detail.
        - Use the user's language unless they ask otherwise.
        - Never include Markdown fences.
        """)

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

        Previous output:
        \(truncated(previousOutput, limit: 900))

        User:
        \(truncated(request.userPrompt, limit: 900))
        """, limit: 2_400)
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
