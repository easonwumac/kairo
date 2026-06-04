import XCTest
@testable import KairoCore

final class KairoChatBackendAPITests: XCTestCase {
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
        XCTAssertTrue(assistantMessage.text.contains("OpenAI API key 尚未設定"), assistantMessage.text)
        XCTAssertTrue(assistantMessage.text.contains("Settings"), assistantMessage.text)
        XCTAssertTrue(assistantMessage.text.contains("local-only fallback"), assistantMessage.text)
        XCTAssertEqual(viewModel.errorMessage, assistantMessage.text)
    }

    func testChatBackendAPIForwardsPrivacyModeThroughAgentCore() async throws {
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Private response"))
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(
                    title: "Private note",
                    summary: "Should not be queried",
                    content: "private content",
                    source: .manual
                )
            ]),
            aiProvider: provider
        ))

        let response = try await api.respond(
            to: "summarize private content",
            attachments: [],
            privacyMode: .privateChat
        )
        let request = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(request)

        XCTAssertEqual(response.message, "Private response")
        XCTAssertEqual(capturedRequest.privacyMode, .privateChat)
        XCTAssertTrue(capturedRequest.memoryContext.isEmpty)
    }
}

private actor FailingChatBackendAIProvider: AIProvider {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        _ = request
        throw error
    }

    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        throw error
    }
}
