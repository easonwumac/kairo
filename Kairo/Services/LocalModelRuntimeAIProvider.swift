import Foundation

public struct LocalModelRuntimeAIProvider: AIProvider {
    private let localModelSettingsService: LocalModelSettingsService
    private let runtime: any LocalModelReplyCheckRuntime

    public init(
        localModelSettingsService: LocalModelSettingsService,
        runtime: any LocalModelReplyCheckRuntime
    ) {
        self.localModelSettingsService = localModelSettingsService
        self.runtime = runtime
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
            let result = try await runtime.generateReply(
                model: model,
                installRecord: installRecord,
                prompt: Self.prompt(from: request, responseLanguage: status.responseLanguage)
            )
            let parsedResponse = LocalModelReasoningParser.parse(result.responseText)
            guard !parsedResponse.message.isEmpty else {
                throw AIProviderError.localInferenceUnavailable(
                    KairoL10n.string("chat.error.localInference.reason.runtimeEmpty")
                )
            }
            return AICompletionResponse(
                message: parsedResponse.message,
                proposedActions: [],
                toolCandidates: [],
                memoryContextCount: request.memoryContext.count,
                reasoningText: parsedResponse.reasoningText
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

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        throw AIProviderError.unsupported
    }

    private static func prompt(
        from request: AICompletionRequest,
        responseLanguage: ChatResponseLanguagePreference
    ) -> String {
        let memoryContext = compactMemoryContext(from: request.memoryContext)
        let attachmentContext = compactAttachmentContext(from: request.attachmentContext)
        return """
        You are Kairo running a local model on iPhone.
        Answer the user directly and concisely.
        Do not claim to browse the web, call tools, or operate other apps.
        Primary language:
        \(responseLanguage.promptInstruction)
        If the user explicitly asks for another language, follow the user's explicit language request.

        Memory:
        \(memoryContext)

        Attachments:
        \(attachmentContext)

        User:
        \(truncated(request.userPrompt, limit: 1_600))

        Assistant:
        """
    }

    private static func compactMemoryContext(from memories: [MemoryRecord]) -> String {
        let lines = memories.prefix(3).map { memory in
            let summary = memory.summary.isEmpty ? memory.content : memory.summary
            return "- \(truncated(summary, limit: 220))"
        }
        return lines.isEmpty ? "None" : lines.joined(separator: "\n")
    }

    private static func compactAttachmentContext(from attachments: [ChatAttachment]) -> String {
        let lines = attachments.prefix(3).map { attachment in
            var line = attachment.displayName
            if let preview = attachment.textPreview, !preview.isEmpty {
                line += ": \(truncated(preview, limit: 320))"
            }
            return "- \(line)"
        }
        return lines.isEmpty ? "None" : lines.joined(separator: "\n")
    }

    private static func truncated(_ value: String, limit: Int) -> String {
        let compacted = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard compacted.count > limit else { return compacted }
        return String(compacted.prefix(limit))
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
