import Foundation

public protocol AIProvider: Sendable {
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse
    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse
}

public enum AIProviderError: Error, Equatable {
    case missingCredential
    case unsupported
    case requestFailed(String)
}

public struct MockAIProvider: AIProvider {
    public init() {}

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        AICompletionResponse(
            message: "我可以根據你授權的資料與記憶協助你。這是 mock 回應：\(request.userPrompt)",
            proposedActions: []
        )
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        AIEmbeddingResponse(vector: Array(repeating: 0.0, count: 8))
    }
}
