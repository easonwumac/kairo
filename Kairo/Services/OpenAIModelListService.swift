import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct OpenAIModelSummary: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var owner: String?

    public init(id: String, owner: String? = nil) {
        self.id = id
        self.owner = owner
    }
}

public struct OpenAIModelListService: Sendable {
    private let credentialStore: CredentialStore
    private let httpClient: any HTTPClient
    private let modelsURL: URL

    public init(
        credentialStore: CredentialStore,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        modelsURL: URL = URL(string: "https://api.openai.com/v1/models")!
    ) {
        self.credentialStore = credentialStore
        self.httpClient = httpClient
        self.modelsURL = modelsURL
    }

    public func availableModels() async throws -> [OpenAIModelSummary] {
        guard let apiKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingCredential
        }

        var request = URLRequest(url: modelsURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw AIProviderError.requestFailed(KairoL10n.string("chat.provider.openAI.requestFailedStatus", response.statusCode, ""))
        }

        let decoded = try JSONDecoder().decode(OpenAIModelListResponse.self, from: data)
        return decoded.data.map { OpenAIModelSummary(id: $0.id, owner: $0.ownedBy) }
    }
}

private struct OpenAIModelListResponse: Decodable {
    var data: [OpenAIModelObject]
}

private struct OpenAIModelObject: Decodable {
    var id: String
    var ownedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownedBy = "owned_by"
    }
}
