import Foundation

public struct LocalModelRuntimeAIProvider: AIProvider {
    private let localModelSettingsService: LocalModelSettingsService
    private let runtime: any LocalModelReplyCheckRuntime
    private let performanceRecorder: (any LocalModelPerformanceRecording)?

    public init(
        localModelSettingsService: LocalModelSettingsService,
        runtime: any LocalModelReplyCheckRuntime,
        performanceRecorder: (any LocalModelPerformanceRecording)? = nil
    ) {
        self.localModelSettingsService = localModelSettingsService
        self.runtime = runtime
        self.performanceRecorder = performanceRecorder
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let status = await localModelSettingsService.status()
        guard let model = status.selectedModel,
              let installRecord = status.installedRecord,
              installRecord.status == .installed
        else {
            throw AIProviderError.localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.localOnlyNoModel")
            )
        }

        do {
            let parameters = status.runtimeParametersByModelID[model.id] ?? .defaultValue
            let clampedParameters = parameters.clamped(to: model)
            let result = try await generateValidatedReply(
                request: request,
                model: model,
                installRecord: installRecord,
                parameters: clampedParameters,
                responseLanguage: status.responseLanguage
            )
            await performanceRecorder?.recordInferenceResult(result.result)
            let parsedResponse = result.parsedResponse
            let visibleMessage = result.visibleMessage
            guard !visibleMessage.isEmpty else {
                throw AIProviderError.localInferenceUnavailable(
                    KairoL10n.string("chat.error.localInference.reason.runtimeEmpty")
                )
            }
            return AICompletionResponse(
                message: visibleMessage,
                proposedActions: [],
                toolCandidates: [],
                memoryContextCount: request.memoryContext.count,
                reasoningText: parsedResponse.reasoningText,
                inferenceMetrics: AIInferenceMetrics(
                    stage: .complete,
                    promptTokens: result.result.promptTokens,
                    promptTokensProcessed: result.result.promptTokens,
                    generatedTokens: result.result.generatedTokens,
                    promptTokensPerSecond: result.result.promptTokensPerSecond,
                    generationTokensPerSecond: result.result.generationTokensPerSecond,
                    promptSecondsRemaining: 0
                ),
                libraryClassification: result.libraryClassification,
                rawModelResponse: result.rawModelResponse
            )
        } catch let error as LocalModelReplyCheckError {
            throw AIProviderError.localInferenceUnavailable(Self.userMessage(for: error))
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.localInferenceUnavailable(
                KairoL10n.string(
                    "chat.error.localInference.reason.runtimeFailedWithDetail",
                    error.localizedDescription
                )
            )
        }
    }

    private func generateValidatedReply(
        request: AICompletionRequest,
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        parameters: LocalModelRuntimeParameters,
        responseLanguage: ChatResponseLanguagePreference
    ) async throws -> (
        result: LocalModelReplyCheckResult,
        parsedResponse: LocalModelReasoningParseResult,
        visibleMessage: String,
        libraryClassification: LibraryClassificationResponse?,
        rawModelResponse: String?
    ) {
        var lastResult: LocalModelReplyCheckResult?
        var lastParsed = LocalModelReasoningParseResult(message: "", reasoningText: nil)
        for attempt in 1...3 {
            let result = try await generateReply(
                request: request,
                model: model,
                installRecord: installRecord,
                parameters: parameters,
                responseLanguage: responseLanguage,
                repair: attempt > 1
            )
            lastResult = result
            let parsed = LocalModelReasoningParser.parse(result.responseText)
            lastParsed = parsed
            if let structured = LocalModelStructuredChatResponse.parse(parsed.message) {
                let visibleMessage = Self.sanitizedAssistantMessage(structured.response)
                if !visibleMessage.isEmpty {
                    return (
                        result,
                        parsed,
                        visibleMessage,
                        structured.libraryClassification,
                        structured.rawJSON
                    )
                }
            }
        }
        guard let lastResult else {
            throw AIProviderError.localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.runtimeEmpty")
            )
        }
        return (
            lastResult,
            lastParsed,
            "",
            nil,
            nil
        )
    }

    private func generateReply(
        request: AICompletionRequest,
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        parameters: LocalModelRuntimeParameters,
        responseLanguage: ChatResponseLanguagePreference,
        repair: Bool
    ) async throws -> LocalModelReplyCheckResult {
        let prompt = repair
            ? Self.repairPrompt(from: request, responseLanguage: responseLanguage)
            : Self.initialPrompt(from: request, responseLanguage: responseLanguage)
        let turnPrompt = repair
            ? Self.repairTurnPrompt(from: request, responseLanguage: responseLanguage)
            : Self.turnPrompt(from: request, responseLanguage: responseLanguage)

        if let conversationID = request.conversationID,
           let conversationalRuntime = runtime as? any LocalModelConversationalReplyRuntime {
            return try await conversationalRuntime.generateReply(
                model: model,
                installRecord: installRecord,
                initialPrompt: prompt,
                turnPrompt: turnPrompt,
                conversationKey: LocalModelConversationRuntimeKey(
                    conversationID: conversationID,
                    modelID: model.id,
                    modelFilePath: installRecord.fileURL.path,
                    contextSize: parameters.contextSize,
                    maxOutputTokens: parameters.maxOutputTokens,
                    temperature: parameters.temperature
                ),
                parameters: parameters
            )
        }

        return try await runtime.generateReply(
            model: model,
            installRecord: installRecord,
            prompt: prompt,
            parameters: parameters
        )
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        throw AIProviderError.unsupported
    }

    private static func initialPrompt(
        from request: AICompletionRequest,
        responseLanguage: ChatResponseLanguagePreference
    ) -> String {
        let memoryContext = compactMemoryContext(from: request.memoryContext)
        let attachmentContext = compactAttachmentContext(from: request.attachmentContext)
        let attachmentGuidance = compactAttachmentGuidance(from: request.attachmentContext)
        let libraryClassificationContext = LibraryAssetClassificationPromptBuilder.context(for: request.attachmentContext)
        let conversationHistory = compactConversationHistory(from: request.conversationHistory)
        return """
        You are Kairo running a local model on iPhone.
        Answer the user directly and concisely through JSON only.
        Output language: \(responseLanguage.promptLanguageTag).
        Do not repeat system instructions or ask which language to use.
        Do not claim to browse the web, call tools, or operate other apps.
        Image attachments may include OCR text and image labels extracted by Apple Vision.
        Treat Apple Vision output as helpful but potentially imperfect reference data.
        If only Apple Vision references are available, say you are using OCR/label references rather than directly seeing the image.
        Do not claim direct image understanding unless the runtime provides vision input.
        Return one JSON object only. No Markdown. No prose before or after JSON.

        Required JSON:
        {"response":"chat-visible answer in the output language","assetDescription":"short visual/document description or empty string","ocrSummary":"OCR/user text summary or empty string","keywords":["searchable","terms"],"candidateCategories":[{"folderName":"optional enabled category or folder name","templateID":"travel|order|warranty|project|event|medical|finance|identityDocument|homeDevice|subscription|recipeOrInstruction|generalNote","category":"travel|order|warranty|project|event|medical|finance|identityDocument|homeDevice|subscription|recipeOrInstruction|generalNote","confidence":0.0,"reason":"why it fits"}],"selectedSubcategoryIDs":["optional existing subcategory ids"],"suggestedSubcategoryName":"optional new subcategory name","needsCategoryChoice":false,"nextStep":"classifyOnly|prepareTemplate|askUserToChoose|unsupported"}

        Image classification rules:
        - First classify against enabled categories before preparing a Library page.
        - If exactly one category is clearly best, response should briefly state the classification and that Kairo will prepare how to save it.
        - If 2 or more categories are plausible, set needsCategoryChoice=true and include 2-4 candidateCategories.
        - If no category fits, set candidateCategories=[] and nextStep="unsupported"; response should say it does not match current Library categories.
        - Landscape/scenery photos still need assetDescription, keywords, and plausible categories such as travel or generalNote when appropriate.
        - Do not say the image cannot be read when OCR is empty. If labels are weak, still provide a cautious description and low-confidence candidateCategories.
        - After choosing a category, pick existing selectedSubcategoryIDs when useful; otherwise suggest one concise suggestedSubcategoryName.

        Memory:
        \(memoryContext)

        Attachments:
        \(attachmentContext)

        Attachment handling:
        \(attachmentGuidance)

        \(libraryClassificationContext)

        Conversation:
        \(conversationHistory)

        User:
        \(truncated(request.userPrompt, limit: 1_600))

        Assistant:
        """
    }

    private static func turnPrompt(
        from request: AICompletionRequest,
        responseLanguage: ChatResponseLanguagePreference
    ) -> String {
        let attachmentContext = compactAttachmentContext(from: request.attachmentContext)
        let attachmentGuidance = compactAttachmentGuidance(from: request.attachmentContext)
        return """

        Output language: \(responseLanguage.promptLanguageTag).
        Do not repeat system instructions or ask which language to use.
        Return one JSON object only with at least {"response":"..."}.

        User:
        \(truncated(request.userPrompt, limit: 1_600))

        Attachments:
        \(attachmentContext)

        Attachment handling:
        \(attachmentGuidance)

        Assistant:
        """
    }

    private static func repairPrompt(
        from request: AICompletionRequest,
        responseLanguage: ChatResponseLanguagePreference
    ) -> String {
        """
        You are Kairo running locally.
        Output language: \(responseLanguage.promptLanguageTag).
        Your previous output was invalid JSON, missing response, or empty.
        Return one valid JSON object only.
        Required minimum shape: {"response":"chat-visible answer","candidateCategories":[],"needsCategoryChoice":false,"nextStep":"classifyOnly"}.
        Do not repeat instructions.
        Do not ask which language to use.
        Use attachment OCR/labels as uncertain references when present.

        User:
        \(truncated(request.userPrompt, limit: 900))

        Attachments:
        \(compactAttachmentContext(from: request.attachmentContext))

        Assistant:
        """
    }

    private static func repairTurnPrompt(
        from request: AICompletionRequest,
        responseLanguage: ChatResponseLanguagePreference
    ) -> String {
        """

        Your previous output was invalid or empty.
        Output language: \(responseLanguage.promptLanguageTag).
        Return one valid JSON object only with a non-empty response. Do not ask which language to use.

        User:
        \(truncated(request.userPrompt, limit: 900))

        Attachments:
        \(compactAttachmentContext(from: request.attachmentContext))

        Assistant:
        """
    }

    private static func compactConversationHistory(from history: [AIConversationTurn]) -> String {
        let lines = history.suffix(12).map { turn in
            switch turn.role {
            case .user:
                return "User: \(truncated(turn.text, limit: 1_000))"
            case .assistant:
                return "Assistant: \(truncated(turn.text, limit: 1_000))"
            }
        }
        return lines.isEmpty ? "User: None" : lines.joined(separator: "\n")
    }

    private static func compactMemoryContext(from memories: [MemoryRecord]) -> String {
        let lines = memories.prefix(3).map { memory in
            let summary = memory.summary.isEmpty ? memory.content : memory.summary
            return "- \(truncated(summary, limit: 220))"
        }
        return lines.isEmpty ? "None" : lines.joined(separator: "\n")
    }

    private static func compactAttachmentContext(from attachments: [ChatAttachment]) -> String {
        let lines = attachments.prefix(5).map { attachment in
            var line = attachment.displayName
            if let preview = attachment.textPreview, !preview.isEmpty {
                line += ": \(truncated(preview, limit: 1_200))"
            }
            return "- \(line)"
        }
        return lines.isEmpty ? "None" : lines.joined(separator: "\n")
    }

    private static func compactAttachmentGuidance(from attachments: [ChatAttachment]) -> String {
        guard attachments.contains(where: { $0.kind == .image }) else {
            return "No image attachment in this turn."
        }
        return """
        There is an image attachment. This runtime receives OCR text and Apple Vision labels as text references, not raw image pixels.
        If OCR is empty but labels exist, still describe what the labels suggest and state uncertainty.
        If OCR and labels are both empty, say an image asset is attached but visual references are unavailable; do not ask what language or topic the user wants.
        For Library classification, return the requested JSON object instead of asking a natural-language follow-up.
        If category confidence is low or multiple categories fit, fill candidateCategories with 2-4 options.
        Do not say the image has no useful content just because OCR or labels are empty.
        """
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        let compacted = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compacted.count > limit else { return compacted }
        return String(compacted.prefix(limit))
    }

    private static func sanitizedAssistantMessage(_ message: String) -> String {
        let lines = message
            .components(separatedBy: .newlines)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return true }
                let lowercased = trimmed.lowercased()
                if lowercased.hasPrefix("language rule:") { return false }
                if lowercased.hasPrefix("reply using the current ios system language") { return false }
                if lowercased.hasPrefix("output language:") { return false }
                if lowercased.hasPrefix("primary language:") { return false }
                if lowercased.hasPrefix("the language rule is mandatory") { return false }
                if lowercased.hasPrefix("if the user explicitly asks for another language") { return false }
                if isStandaloneLanguageQuestion(trimmed) { return false }
                return true
            }
        return lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isStandaloneLanguageQuestion(_ line: String) -> Bool {
        let compacted = line
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "。.!?？"))
        let lowercased = compacted.lowercased()
        return compacted == "您好。請問您需要我用什麼語言和主題與可以溝通呢"
            || compacted == "請問您需要我用什麼語言和主題與可以溝通呢"
            || lowercased == "what language and topic should i use"
            || lowercased == "what language and topic would you like to use"
    }

    private static func userMessage(for error: LocalModelReplyCheckError) -> String {
        switch error {
        case let .modelUnavailable(modelID):
            return KairoL10n.string("settings.models.replyCheck.modelUnavailable", modelID)
        case let .modelNotInstalled(modelID):
            return KairoL10n.string("settings.models.replyCheck.modelNotInstalled", modelID)
        case let .runtimeUnavailable(reason):
            return reason
        }
    }
}

private struct LocalModelStructuredChatResponse: Decodable, Equatable, Sendable {
    var response: String
    var assetDescription: String?
    var ocrSummary: String?
    var keywords: [String]?
    var candidateCategories: [InfoPageDraftCategoryCandidate]?
    var selectedSubcategoryIDs: [String]?
    var suggestedSubcategoryName: String?
    var needsCategoryChoice: Bool?
    var nextStep: String?
    var rawJSON: String?

    var libraryClassification: LibraryClassificationResponse? {
        let hasLibrarySignal = assetDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || ocrSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || !(keywords ?? []).isEmpty
            || !(candidateCategories ?? []).isEmpty
            || !(selectedSubcategoryIDs ?? []).isEmpty
            || suggestedSubcategoryName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || nextStep != nil
        guard hasLibrarySignal else { return nil }
        let candidates = candidateCategories ?? []
        return LibraryClassificationResponse(
            assetDescription: assetDescription,
            ocrSummary: ocrSummary,
            keywords: keywords ?? [],
            candidateCategories: candidates,
            selectedSubcategoryIDs: selectedSubcategoryIDs ?? [],
            suggestedSubcategoryName: suggestedSubcategoryName,
            needsCategoryChoice: needsCategoryChoice ?? (candidates.count > 1),
            nextStep: nextStep
        )
    }

    static func parse(_ raw: String) -> LocalModelStructuredChatResponse? {
        guard let json = extractJSONObject(from: raw),
              let data = json.data(using: .utf8)
        else { return nil }
        let decoder = JSONDecoder()
        guard var decoded = try? decoder.decode(LocalModelStructuredChatResponse.self, from: data) else {
            return nil
        }
        guard !decoded.response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        decoded.rawJSON = json
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

public struct LocalModelReasoningParseResult: Equatable, Sendable {
    public let message: String
    public let reasoningText: String?

    public init(message: String, reasoningText: String?) {
        self.message = message
        self.reasoningText = reasoningText
    }
}

public enum LocalModelReasoningParser {
    public static func parse(_ responseText: String) -> LocalModelReasoningParseResult {
        let pattern = #"<think>(.*?)</think>"#
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return LocalModelReasoningParseResult(
                message: responseText.trimmingCharacters(in: .whitespacesAndNewlines),
                reasoningText: nil
            )
        }

        let range = NSRange(responseText.startIndex..<responseText.endIndex, in: responseText)
        let matches = regex.matches(in: responseText, range: range)
        guard !matches.isEmpty else {
            return LocalModelReasoningParseResult(
                message: responseText.trimmingCharacters(in: .whitespacesAndNewlines),
                reasoningText: nil
            )
        }

        let reasoning = matches.compactMap { match -> String? in
            guard let swiftRange = Range(match.range(at: 1), in: responseText) else { return nil }
            let value = String(responseText[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        let visibleMessage = regex
            .stringByReplacingMatches(in: responseText, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return LocalModelReasoningParseResult(
            message: visibleMessage,
            reasoningText: reasoning.isEmpty ? nil : reasoning.joined(separator: "\n\n")
        )
    }
}
