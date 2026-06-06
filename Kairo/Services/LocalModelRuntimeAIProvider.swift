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
                )
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
        visibleMessage: String
    ) {
        let firstResult = try await generateReply(
            request: request,
            model: model,
            installRecord: installRecord,
            parameters: parameters,
            responseLanguage: responseLanguage,
            repair: false
        )
        let firstParsed = LocalModelReasoningParser.parse(firstResult.responseText)
        let firstVisibleMessage = Self.sanitizedAssistantMessage(firstParsed.message)
        guard firstVisibleMessage.isEmpty else {
            return (firstResult, firstParsed, firstVisibleMessage)
        }

        let retryResult = try await generateReply(
            request: request,
            model: model,
            installRecord: installRecord,
            parameters: parameters,
            responseLanguage: responseLanguage,
            repair: true
        )
        let retryParsed = LocalModelReasoningParser.parse(retryResult.responseText)
        return (
            retryResult,
            retryParsed,
            Self.sanitizedAssistantMessage(retryParsed.message)
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
        Answer the user directly and concisely.
        Output language: \(responseLanguage.promptLanguageTag).
        Do not repeat system instructions or ask which language to use.
        Do not claim to browse the web, call tools, or operate other apps.
        Image attachments may include OCR text and image labels extracted by Apple Vision.
        Treat Apple Vision output as helpful but potentially imperfect reference data.
        If only Apple Vision references are available, say you are using OCR/label references rather than directly seeing the image.
        Do not claim direct image understanding unless the runtime provides vision input.

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
        Your previous output was invalid or empty.
        Reply with useful content only.
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
        Reply with useful content only. Do not ask which language to use.

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
        Decide whether the item should be saved to Library. If useful, ask the user whether to save it.
        If category confidence is low, offer 2-4 likely categories such as Travel, Receipt/Order, Document, Photo/Plant, Project, or Other and ask the user to choose.
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
