import XCTest
@testable import KairoCore

final class KairoChatBackendAPITests: XCTestCase {
    func testChatBackendUsesSavedOpenAIKeyForOpenAIProviderRequest() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("chat-openai-key-1234567890", for: CredentialKey.openAIAPIKey)
        let httpClient = ChatBackendCapturingHTTPClient(body: #"{"output_text":"Live provider response"}"#)
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(title: "Tone", summary: "Prefers concise Traditional Chinese replies", content: "Keep answers short.", source: .manual)
            ]),
            aiProvider: OpenAIProvider(credentialStore: credentials, httpClient: httpClient)
        ))

        let response = try await api.respond(to: "Tone", attachments: [], privacyMode: .standard)

        XCTAssertEqual(response.message, "Live provider response")
        XCTAssertEqual(response.memoryContextCount, 1)
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer chat-openai-key-1234567890")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "gpt-4.1")
        let input = try XCTUnwrap(payload["input"] as? [[String: String]])
        XCTAssertTrue(input.contains { $0["role"] == "user" && $0["content"] == "Tone" })
        XCTAssertTrue(input.contains { message in
            message["role"] == "system"
                && (message["content"]?.contains("Prefers concise Traditional Chinese replies") == true)
        })
    }

    @MainActor
    func testChatViewModelSurfacesMissingOpenAIKeyAsActionableSettingsError() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            agent: AgentCore(aiProvider: FailingChatBackendAIProvider(error: AIProviderError.missingCredential))
        )

        await viewModel.send("Hello Kairo")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.status, .failed)
        XCTAssertEqual(assistantMessage.text, KairoL10n.string("chat.error.openAIKeyMissing"))
        XCTAssertEqual(viewModel.errorMessage, assistantMessage.text)
    }

    @MainActor
    func testChatViewModelSurfacesLocalOnlyUnavailableAsFailedMessage() async throws {
        let reason = KairoL10n.string("chat.error.localInference.reason.localOnlyNoModel")
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            agent: AgentCore(aiProvider: FailingChatBackendAIProvider(error: AIProviderError.localInferenceUnavailable(reason)))
        )

        await viewModel.send("Draft a private reply")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.status, .failed)
        XCTAssertEqual(assistantMessage.text, KairoL10n.string("chat.error.localInferenceUnavailable", reason))
        XCTAssertEqual(viewModel.errorMessage, assistantMessage.text)
    }

    func testChatBackendAPIForwardsPrivacyModeThroughAgentCore() async throws {
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Private response"))
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(title: "Private note", summary: "Should not be queried", content: "private content", source: .manual)
            ]),
            aiProvider: provider
        ))

        let response = try await api.respond(to: "summarize private content", attachments: [], privacyMode: .privateChat)
        let request = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(request)

        XCTAssertEqual(response.message, "Private response")
        XCTAssertEqual(capturedRequest.privacyMode, .privateChat)
        XCTAssertTrue(capturedRequest.memoryContext.isEmpty)
    }

    func testChatBackendUsesNaturalLanguageMemoryMatchesInStandardChat() async throws {
        let memoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Used saved context"))
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(
                    id: memoryID,
                    title: "Launch plan",
                    summary: "Send beta invites after the QA pass.",
                    content: "The Kairo beta launch plan depends on QA sign-off.",
                    source: .manual
                )
            ]),
            aiProvider: provider
        ))

        let response = try await api.respond(
            to: "What should I remember about the launch?",
            attachments: [],
            privacyMode: .standard
        )
        let capturedRequestResult = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(capturedRequestResult)

        XCTAssertEqual(response.memoryContextCount, 1)
        XCTAssertEqual(capturedRequest.memoryContext.map(\.id), [memoryID])
    }

    @MainActor
    func testChatViewModelPersistsAssistantMemoryContextCount() async throws {
        let memory = MemoryRecord(
            title: "Launch memory",
            summary: "Use this context in Chat.",
            content: "Kairo should visibly report memory context usage.",
            source: .manual
        )
        let historyStore = InMemoryChatHistoryStore()
        let viewModel = ChatViewModel(
            historyStore: historyStore,
            agent: AgentCore(
                memoryStore: InMemoryMemoryStore(seed: [memory]),
                aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Used memory."))
            )
        )

        await viewModel.send("memory context")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.memoryContextCount, 1)

        let savedThreadResult = try await historyStore.thread(id: viewModel.currentThread.id)
        let savedThread = try XCTUnwrap(savedThreadResult)
        XCTAssertEqual(savedThread.messages.last?.memoryContextCount, 1)
    }
}
