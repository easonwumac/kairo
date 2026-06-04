import Foundation

public protocol AIProvider: Sendable {
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse
}

public enum AIProviderError: Error, Equatable {
    case missingCredential
    case unsupported
    case localInferenceUnavailable(String)
    case requestFailed(String)
}

public struct MockAIProvider: AIProvider {
    public init() {}

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        AICompletionResponse(
            message: KairoL10n.string("chat.provider.mockPreviewResponse", request.userPrompt),
            proposedActions: []
        )
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        AIEmbeddingResponse(vector: Array(repeating: 0.0, count: 8))
    }
}
