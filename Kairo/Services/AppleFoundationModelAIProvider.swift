import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

public struct AppleFoundationModelAIProvider: AIProvider {
    private static let responseTimeoutSeconds: UInt64 = 45

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

        let session = LanguageModelSession(
            model: model,
            instructions: Self.instructions(from: request)
        )
        let response = try await Self.withResponseTimeout {
            try await session.respond(to: Self.prompt(from: request))
        }
        let message = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
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
            rawModelResponse: message
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
            Answer concisely. Do not claim to browse the web or operate other apps.
            If attachments are referenced, use only the metadata and text previews included in the prompt.
            """
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    private static func prompt(from request: AICompletionRequest) -> String {
        var sections: [String] = []
        let history = request.conversationHistory.suffix(8).map { turn in
            "\(turn.role.rawValue): \(turn.text)"
        }.joined(separator: "\n")
        if !history.isEmpty {
            sections.append("Conversation:\n\(history)")
        }

        let memory = request.memoryContext.prefix(8).map { record in
            "- \(record.title): \(record.summary.isEmpty ? record.content : record.summary)"
        }.joined(separator: "\n")
        if !memory.isEmpty {
            sections.append("Relevant memory:\n\(memory)")
        }

        let attachments = request.attachmentContext.map(\.promptSummary).joined(separator: "\n")
        if !attachments.isEmpty {
            sections.append("Attachments:\n\(attachments)")
        }

        if let toolContext = request.toolContext?.trimmingCharacters(in: .whitespacesAndNewlines),
           !toolContext.isEmpty {
            sections.append("Available context:\n\(toolContext)")
        }

        sections.append("User:\n\(request.userPrompt)")
        return sections.joined(separator: "\n\n")
    }
}
