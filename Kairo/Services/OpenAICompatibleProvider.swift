import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private let kairoOmlxLogFileURL: URL = {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KairoUITesting", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("omlx-cloud.log")
}()

private func kairoOmlxLog(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    print("[KAIRO_OMLX] \(message)")
    fflush(stdout)
    if let data = line.data(using: .utf8) {
        if let fh = try? FileHandle(forUpdating: kairoOmlxLogFileURL) {
            _ = try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
            try? fh.close()
        } else {
            try? data.write(to: kairoOmlxLogFileURL, options: .atomic)
        }
    }
}

public struct OpenAICompatibleProvider: AIProvider {
    private let credentialStore: CredentialStore
    private let httpClient: HTTPClient
    private let baseURL: URL
    private let model: String
    private let directAPIKey: String?

    public init(
        credentialStore: CredentialStore,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        baseURL: URL,
        model: String
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.directAPIKey = nil
        self.baseURL = baseURL
        self.model = model
    }

    public init(
        credentialStore: CredentialStore,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        endpoint: String,
        apiKey: String,
        model: String
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.directAPIKey = apiKey
        self.baseURL = URL(string: endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint)!
        self.model = model
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let apiKey = try await apiKey()
        let chatURL = baseURL.appendingPathComponent("chat/completions")
        let payload = OAICompatRequest(
            model: model,
            messages: buildMessages(from: request),
            temperature: 0.2,
            maxTokens: 1024
        )
        kairoOmlxLog("[OMLX] url=\(chatURL.absoluteString) model=\(model) messagesCount=\(payload.messages.count)")
        let data = try JSONEncoder().encode(payload)
        var urlRequest = URLRequest(url: chatURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data
        urlRequest.timeoutInterval = 120

        let startTime = CFAbsoluteTimeGetCurrent()
        let (responseData, response) = try await httpClient.data(for: urlRequest)
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        try validate(response, data: responseData)

        let decoded = try JSONDecoder().decode(OAICompatResponse.self, from: responseData)
        let message = decoded.choices.first?.message.content ?? ""
        kairoOmlxLog("[OMLX] response status=\(response.statusCode) elapsed=\(String(format: "%.0f", elapsed))ms tokens=\(decoded.usage?.totalTokens ?? 0) messageLen=\(message.count)")
        kairoOmlxLog("[OMLX] message=\(String(message.prefix(200)))")
        return AICompletionResponse(message: message, proposedActions: [])
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        let apiKey = try await apiKey()
        let embedURL = baseURL.appendingPathComponent("embeddings")
        let payload: [String: Any] = ["model": model, "input": request.input]
        let data = try JSONSerialization.data(withJSONObject: payload)
        var urlRequest = URLRequest(url: embedURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = data
        urlRequest.timeoutInterval = 30

        let (responseData, response) = try await httpClient.data(for: urlRequest)
        try validate(response, data: responseData)

        guard let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let first = dataArray.first,
              let embedding = first["embedding"] as? [Double]
        else {
            throw AIProviderError.requestFailed("Missing embedding vector in response")
        }
        return AIEmbeddingResponse(vector: embedding)
    }

    public static func defaultOmlxProvider(credentialStore: CredentialStore) -> OpenAICompatibleProvider {
        OpenAICompatibleProvider(
            credentialStore: credentialStore,
            baseURL: URL(string: "http://localhost:8000/v1")!,
            model: "gemma-4-e2b-it-4bit"
        )
    }

    private func apiKey() async throws -> String {
        if let directAPIKey { return directAPIKey }
        guard let apiKey = try await credentialStore.readSecret(for: CredentialKey.openAICompatibleAPIKey), !apiKey.isEmpty else {
            throw AIProviderError.missingCredential
        }
        return apiKey
    }

    private func buildMessages(from request: AICompletionRequest) -> [OAICompatMessage] {
        let memoryContext = MemoryPromptContextBuilder().build(from: request.memoryContext)
        let capabilities = request.allowedCapabilities.map(\.rawValue).joined(separator: ", ")
        let attachmentContext = CapabilityPromptContextBuilder.attachmentContext(request.attachmentContext)
        let libraryClassificationContext = LibraryAssetClassificationPromptBuilder.context(for: request.attachmentContext)
        let context = """
        Relevant memory:
        \(memoryContext)

        Allowed capabilities:
        \(capabilities.isEmpty ? "None" : capabilities)

        \(attachmentContext)

        \(libraryClassificationContext)

        Tool context:
        \(request.toolContext ?? "No tool context supplied.")
        """

        var messages: [OAICompatMessage] = [
            OAICompatMessage(role: "system", content: request.systemPrompt),
            OAICompatMessage(role: "system", content: context)
        ]

        for turn in request.conversationHistory.suffix(10) {
            switch turn.role {
            case .user:
                messages.append(OAICompatMessage(role: "user", content: turn.text))
            case .assistant:
                messages.append(OAICompatMessage(role: "assistant", content: turn.text))
            }
        }

        messages.append(OAICompatMessage(role: "user", content: request.userPrompt))
        return messages
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "no body"
            let prefix = String(body.prefix(500))
            throw AIProviderError.requestFailed("HTTP \(response.statusCode): \(prefix)")
        }
    }
}

private struct OAICompatRequest: Codable {
    var model: String
    var messages: [OAICompatMessage]
    var temperature: Double
    var maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct OAICompatMessage: Codable {
    var role: String
    var content: String
}

private struct OAICompatResponse: Codable {
    var choices: [OAICompatChoice]
    var usage: OAICompatUsage?
}

private struct OAICompatUsage: Codable {
    var totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case totalTokens = "total_tokens"
    }
}

private struct OAICompatChoice: Codable {
    var message: OAICompatMessage
    var index: Int?
    var finishReason: String?

    enum CodingKeys: String, CodingKey {
        case message
        case index
        case finishReason = "finish_reason"
    }
}
