import Foundation
@testable import KairoCore

actor BackendAPICapturingAIProvider: AIProvider {
    private var lastRequest: AICompletionRequest?
    private let response: AICompletionResponse

    init(response: AICompletionResponse) {
        self.response = response
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        lastRequest = request
        return response
    }

    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        return AIEmbeddingResponse(vector: [])
    }

    func capturedRequest() -> AICompletionRequest? {
        lastRequest
    }
}

actor ChatBackendCapturingHTTPClient: HTTPClient {
    private let statusCode: Int
    private let body: String
    private var capturedRequest: URLRequest?

    init(statusCode: Int = 200, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.openai.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }

    func lastRequest() throws -> URLRequest {
        guard let capturedRequest else {
            throw ChatBackendCapturingHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private enum ChatBackendCapturingHTTPClientError: Error {
    case missingRequest
}

func makeBackendTestAgentSkillManagerService(
    runtimeContext: AgentSkillRuntimeContext = .permissive
) async throws -> AgentSkillManagerService {
    let storeURL = temporaryBackendTestFileURL(named: "agent-skills.json")
    let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
    return AgentSkillManagerService(
        store: store,
        builtInCatalog: .default,
        runtimeContext: runtimeContext
    )
}

func encodeBackendTestManifestJSON(_ manifest: AgentSkillManifest) throws -> String {
    let data = try JSONEncoder().encode(manifest)
    return String(decoding: data, as: UTF8.self)
}

func makeBackendTestLocalModelSettingsService() async throws -> LocalModelSettingsService {
    let registryURL = temporaryBackendTestFileURL(named: "install-registry.json")
    let settingsURL = temporaryBackendTestFileURL(named: "local-model-settings.json")
    let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
    try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
    let qwenURL = modelsDirectory.appendingPathComponent("qwen-small.gguf")
    try Data("installed-model".utf8).write(to: qwenURL)
    let staleURL = modelsDirectory.appendingPathComponent("llama-stale.gguf")
    let stalePartialURL = staleURL.appendingPathExtension("download")
    try Data("partial-model".utf8).write(to: stalePartialURL)

    let catalog = LocalModelCatalog(
        signingKeyID: "test-key",
        signature: "test-signature",
        minimumSafetyPolicyVersion: "2026.1",
        models: [
            makeBackendTestLocalModelManifest(id: "qwen-small"),
            makeBackendTestLocalModelManifest(id: "llama-stale")
        ]
    )
    let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
    try await registry.upsert(LocalModelInstallRecord(
        modelID: "qwen-small",
        version: "1.0",
        status: .installed,
        fileURL: qwenURL,
        installedSizeBytes: 1024,
        sha256: "abc123"
    ))
    try await registry.upsert(LocalModelInstallRecord(
        modelID: "llama-stale",
        version: "1.0",
        status: .downloading,
        fileURL: staleURL,
        installedSizeBytes: 0,
        sha256: "def456"
    ))
    let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
    return LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)
}

func temporaryBackendTestFileURL(named name: String) -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
        .appendingPathComponent(name)
}

private func makeBackendTestLocalModelManifest(id: String) -> LocalModelManifest {
    LocalModelManifest(
        id: id,
        displayName: "Qwen Small Test",
        family: "Qwen",
        version: "1.0",
        parameterCount: "0.8B",
        quantization: "Q4",
        fileSizeBytes: 512,
        installedSizeBytes: 1024,
        contextWindow: 2048,
        tokenizerID: "qwen-test-tokenizer",
        licenseName: "Apache-2.0",
        licenseURL: URL(string: "https://example.com/license")!,
        minOSVersion: "17.0",
        minDeviceClass: "A15",
        minRAMGB: 4,
        supportedLocales: ["en", "zh-Hant"],
        capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat],
        disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
        downloadURL: URL(string: "https://example.com/model.gguf")!,
        sha256: "abc123",
        safetyPolicyVersion: "2026.1",
        deprecated: false
    )
}
