import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OpenAICodexProvider: AIProvider {
    private let credentialStore: CredentialStore
    private let httpClient: HTTPClient
    private let responsesURL: URL
    private let model: String

    public init(
        credentialStore: CredentialStore,
        httpClient: HTTPClient = URLSessionHTTPClient(),
        responsesURL: URL = URL(string: "https://chatgpt.com/backend-api/codex/responses")!,
        model: String = "gpt-5.5"
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.responsesURL = responsesURL
        self.model = model
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let token = try await tokenSet().accessToken
        let payload = OpenAICodexResponsesRequest(
            model: model,
            instructions: request.systemPrompt,
            input: buildInput(from: request),
            store: false,
            stream: false,
            reasoning: OpenAICodexReasoning(effort: "medium")
        )
        let data = try JSONEncoder().encode(payload)
        var urlRequest = URLRequest(url: responsesURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.setValue("codex_cli_rs/0.0.0", forHTTPHeaderField: "User-Agent")
        urlRequest.setValue("codex_cli_rs", forHTTPHeaderField: "originator")
        urlRequest.setValue("responses=experimental", forHTTPHeaderField: "OpenAI-Beta")
        if let accountID = Self.chatGPTAccountID(fromJWT: token) {
            urlRequest.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        }
        urlRequest.httpBody = data

        let (responseData, response) = try await httpClient.data(for: urlRequest)
        try validate(response, data: responseData)
        let decoded = try JSONDecoder().decode(OpenAICodexResponsesResponse.self, from: responseData)
        let outputText = decoded.outputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outputText.isEmpty else {
            throw AIProviderError.requestFailed(KairoL10n.string("chat.provider.codex.emptyResponse"))
        }
        return AICompletionResponse(message: outputText, proposedActions: [])
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        throw AIProviderError.unsupported
    }

    private func tokenSet() async throws -> OAuthTokenSet {
        guard let encoded = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "openai-codex")),
              let tokenSet = try OAuthTokenSet.decodeStoredSecret(encoded),
              !tokenSet.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingCredential
        }
        return tokenSet
    }

    private func buildInput(from request: AICompletionRequest) -> [OpenAICodexInputItem] {
        var input: [OpenAICodexInputItem] = [
            .message(role: "user", text: AIRequestPromptComposer.sessionContext(from: request))
        ]
        for turn in request.conversationHistory {
            switch turn.role {
            case .user:
                input.append(.message(role: "user", text: turn.text))
            case .assistant:
                input.append(.message(role: "assistant", text: turn.text))
            }
        }
        input.append(.message(role: "user", text: AIRequestPromptComposer.currentUserText(from: request)))
        return input
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw AIProviderError.requestFailed(sanitizedErrorMessage(statusCode: response.statusCode, data: data))
        }
    }

    private func sanitizedErrorMessage(statusCode: Int, data: Data) -> String {
        struct ErrorEnvelope: Decodable {
            struct APIError: Decodable {
                var message: String?
                var type: String?
            }
            var error: APIError?
        }
        let decoded = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
        let type = decoded?.error?.type ?? ""
        return KairoL10n.string("chat.provider.codex.requestFailedStatus", statusCode, type)
    }

    private static func chatGPTAccountID(fromJWT token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let auth = object["https://api.openai.com/auth"] as? [String: Any] else {
            return nil
        }
        return auth["chatgpt_account_id"] as? String
    }
}

private struct OpenAICodexResponsesRequest: Codable, Equatable {
    var model: String
    var instructions: String
    var input: [OpenAICodexInputItem]
    var store: Bool
    var stream: Bool
    var reasoning: OpenAICodexReasoning
}

private struct OpenAICodexReasoning: Codable, Equatable {
    var effort: String
}

private struct OpenAICodexInputItem: Codable, Equatable {
    var type: String
    var role: String
    var content: [OpenAICodexContent]

    static func message(role: String, text: String) -> OpenAICodexInputItem {
        OpenAICodexInputItem(
            type: "message",
            role: role,
            content: [OpenAICodexContent(type: "input_text", text: text)]
        )
    }
}

private struct OpenAICodexContent: Codable, Equatable {
    var type: String
    var text: String
}

private struct OpenAICodexResponsesResponse: Codable, Equatable {
    var output: [OpenAICodexOutputItem]?
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

private struct OpenAICodexOutputItem: Codable, Equatable {
    var content: [OpenAICodexOutputContent]?
}

private struct OpenAICodexOutputContent: Codable, Equatable {
    var text: String?
}
