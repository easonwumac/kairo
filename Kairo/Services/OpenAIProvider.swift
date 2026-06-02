import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OpenAIProvider: AIProvider {
    private let credentialStore: CredentialStore
    private let httpClient: HTTPClient
    private let responsesURL: URL
    private let embeddingsURL: URL
    private let model: String
    private let embeddingModel: String

    public init(
        credentialStore: CredentialStore,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        responsesURL: URL = URL(string: "https://api.openai.com/v1/responses")!,
        embeddingsURL: URL = URL(string: "https://api.openai.com/v1/embeddings")!,
        model: String = "gpt-4.1",
        embeddingModel: String = "text-embedding-3-small"
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.responsesURL = responsesURL
        self.embeddingsURL = embeddingsURL
        self.model = model
        self.embeddingModel = embeddingModel
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let apiKey = try await apiKey()
        let payload = OpenAIResponsesRequest(
            model: model,
            input: buildInput(from: request),
            temperature: 0.2
        )
        let data = try JSONEncoder().encode(payload)
        var urlRequest = URLRequest(url: responsesURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await httpClient.data(for: urlRequest)
        try validate(response, data: responseData)

        let decoded = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: responseData)
        return AICompletionResponse(message: decoded.outputText, proposedActions: [])
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        let apiKey = try await apiKey()
        let payload = OpenAIEmbeddingRequest(model: embeddingModel, input: request.input)
        let data = try JSONEncoder().encode(payload)
        var urlRequest = URLRequest(url: embeddingsURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data

        let (responseData, response) = try await httpClient.data(for: urlRequest)
        try validate(response, data: responseData)

        let decoded = try JSONDecoder().decode(OpenAIEmbeddingResponse.self, from: responseData)
        guard let vector = decoded.data.first?.embedding else {
            throw AIProviderError.requestFailed("Embedding response did not include a vector.")
        }
        return AIEmbeddingResponse(vector: vector)
    }

    private func apiKey() async throws -> String {
        guard let apiKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey), !apiKey.isEmpty else {
            throw AIProviderError.missingCredential
        }
        return apiKey
    }

    private func buildInput(from request: AICompletionRequest) -> [OpenAIInputMessage] {
        let memoryContext = request.memoryContext.map { memory in
            "- [\(memory.source.rawValue)] \(memory.title): \(memory.summary)"
        }.joined(separator: "\n")

        let capabilities = request.allowedCapabilities.map(\.rawValue).joined(separator: ", ")
        let context = """
        Relevant memory:
        \(memoryContext.isEmpty ? "None" : memoryContext)

        Allowed capabilities:
        \(capabilities.isEmpty ? "None" : capabilities)
        """

        return [
            OpenAIInputMessage(role: "system", content: request.systemPrompt),
            OpenAIInputMessage(role: "system", content: context),
            OpenAIInputMessage(role: "user", content: request.userPrompt)
        ]
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let message = sanitizedErrorMessage(statusCode: response.statusCode, data: data)
            throw AIProviderError.requestFailed(message)
        }
    }

    private func sanitizedErrorMessage(statusCode: Int, data: Data) -> String {
        struct APIErrorEnvelope: Decodable {
            struct APIError: Decodable {
                var message: String?
                var type: String?
            }

            var error: APIError?
        }

        let decoded = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
        let type = decoded?.error?.type.map { " type=\($0)" } ?? ""
        return "OpenAI request failed with status \(statusCode)\(type)."
    }
}

private struct OpenAIResponsesRequest: Codable, Equatable {
    var model: String
    var input: [OpenAIInputMessage]
    var temperature: Double
}

private struct OpenAIInputMessage: Codable, Equatable {
    var role: String
    var content: String
}

private struct OpenAIResponsesResponse: Codable, Equatable {
    var output: [OpenAIOutputItem]?
    var outputTextFallback: String?

    enum CodingKeys: String, CodingKey {
        case output
        case outputTextFallback = "output_text"
    }

    var outputText: String {
        if let outputTextFallback, !outputTextFallback.isEmpty {
            return outputTextFallback
        }
        return output?
            .flatMap { $0.content ?? [] }
            .compactMap(\.text)
            .joined(separator: "\n") ?? ""
    }
}

private struct OpenAIOutputItem: Codable, Equatable {
    var content: [OpenAIOutputContent]?
}

private struct OpenAIOutputContent: Codable, Equatable {
    var text: String?
}

private struct OpenAIEmbeddingRequest: Codable, Equatable {
    var model: String
    var input: String
}

private struct OpenAIEmbeddingResponse: Codable, Equatable {
    var data: [OpenAIEmbeddingData]
}

private struct OpenAIEmbeddingData: Codable, Equatable {
    var embedding: [Double]
}
