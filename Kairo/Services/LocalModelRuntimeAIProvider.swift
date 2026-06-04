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
                prompt: Self.prompt(from: request)
            )
            let trimmedResponse = result.responseText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedResponse.isEmpty else {
                throw AIProviderError.localInferenceUnavailable(
                    KairoL10n.string("chat.error.localInference.reason.runtimeEmpty")
                )
            }
            return AICompletionResponse(
                message: trimmedResponse,
                proposedActions: [],
                toolCandidates: [],
                memoryContextCount: request.memoryContext.count
            )
        } catch let error as LocalModelReplyCheckError {
            throw AIProviderError.localInferenceUnavailable(Self.userMessage(for: error))
        } catch let error as AIProviderError {
            throw error
        } catch {
            throw AIProviderError.localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.runtimeFailed")
            )
        }
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        throw AIProviderError.unsupported
    }

    private static func prompt(from request: AICompletionRequest) -> String {
        let memoryContext = request.memoryContext.map { memory in
            "- [\(memory.source.rawValue)] \(memory.title): \(memory.summary)"
        }.joined(separator: "\n")

        let capabilities = request.allowedCapabilities.map(\.rawValue).joined(separator: ", ")
        return """
        System:
        \(request.systemPrompt)

        Relevant memory:
        \(memoryContext.isEmpty ? "None" : memoryContext)

        Allowed capabilities:
        \(capabilities.isEmpty ? "None" : capabilities)

        \(CapabilityPromptContextBuilder.attachmentContext(request.attachmentContext))

        Tool context:
        \(request.toolContext ?? "No tool context supplied.")

        User:
        \(request.userPrompt)

        Assistant:
        """
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
