import XCTest
@testable import KairoCore

final class ChatThreadCompactorTests: XCTestCase {
    func testPressureIsOKForEmptyThread() {
        let compactor = DefaultChatThreadCompactor(
            summarizer: StubSummarizingAIProvider(summary: "ignored")
        )
        let pressure = compactor.pressure(
            for: ChatThread(),
            additionalUserTextChars: 100,
            budget: ChatContextBudget(contextWindow: 8192)
        )
        XCTAssertEqual(pressure, .ok)
    }

    func testPressureUsesActualPromptTokensWhenAvailable() {
        let compactor = DefaultChatThreadCompactor(
            summarizer: StubSummarizingAIProvider(summary: "ignored"),
            systemOverheadTokens: 0
        )
        var thread = ChatThread()
        thread.messages = [
            ChatMessage(role: .user, text: "hi"),
            ChatMessage(role: .assistant, text: "hello back")
        ]
        thread.lastPromptTokens = 5_200
        let budget = ChatContextBudget(contextWindow: 8192, reservedOutputTokens: 1280)
        // inputBudget = 6912; soft = 4838; hard = 5875
        let softPressure = compactor.pressure(
            for: thread,
            additionalUserTextChars: 0,
            budget: budget
        )
        XCTAssertEqual(softPressure, .soft)

        thread.lastPromptTokens = 6_000
        let hardPressure = compactor.pressure(
            for: thread,
            additionalUserTextChars: 0,
            budget: budget
        )
        XCTAssertEqual(hardPressure, .hard)
    }

    func testCompactReplacesOldestTurnsWithRollingSummary() async throws {
        let summarizer = StubSummarizingAIProvider(summary: "user is Eason; topic is chat memory.")
        let compactor = DefaultChatThreadCompactor(
            summarizer: summarizer,
            keepRecentTurns: 2,
            minTurnsToCompact: 2
        )
        var thread = ChatThread()
        thread.messages = [
            ChatMessage(role: .user, text: "我叫 Eason"),
            ChatMessage(role: .assistant, text: "好的 Eason"),
            ChatMessage(role: .user, text: "我們在討論記憶"),
            ChatMessage(role: .assistant, text: "了解"),
            ChatMessage(role: .user, text: "你會記得我嗎"),
            ChatMessage(role: .assistant, text: "會的")
        ]
        thread.lastPromptTokens = 7_000

        let result = try await compactor.compact(
            thread,
            budget: ChatContextBudget(contextWindow: 8192)
        )

        XCTAssertEqual(result.summarizedMessageCount, 2)
        XCTAssertEqual(result.thread.messages.count, 4)
        XCTAssertEqual(result.thread.messages.first?.text, "我們在討論記憶")
        XCTAssertEqual(result.thread.rollingSummary, "user is Eason; topic is chat memory.")
        XCTAssertEqual(result.thread.compactedThroughMessageID, thread.messages[1].id)
        XCTAssertEqual(result.thread.compactionGeneration, 1)
        XCTAssertNil(result.thread.lastPromptTokens)
    }

    func testCompactDoesNothingWhenNotEnoughTurns() async throws {
        let summarizer = StubSummarizingAIProvider(summary: "should not be called")
        let compactor = DefaultChatThreadCompactor(
            summarizer: summarizer,
            keepRecentTurns: 6,
            minTurnsToCompact: 4
        )
        var thread = ChatThread()
        thread.messages = [
            ChatMessage(role: .user, text: "hi"),
            ChatMessage(role: .assistant, text: "hello")
        ]
        let result = try await compactor.compact(
            thread,
            budget: ChatContextBudget(contextWindow: 8192)
        )
        XCTAssertEqual(result.summarizedMessageCount, 0)
        XCTAssertEqual(result.thread.messages.count, 2)
        XCTAssertNil(result.thread.rollingSummary)
        XCTAssertEqual(result.thread.compactionGeneration, 0)
    }
}

@MainActor
final class ChatViewModelCompactionIntegrationTests: XCTestCase {
    func testHistoryInjectsRollingSummaryAndRuntimeIDFlipsAfterCompaction() async throws {
        let chatAPI = ConversationHistoryCapturingChatAPI()
        let summarizer = StubSummarizingAIProvider(summary: "Eason 想測試記憶")
        let compactor = AlwaysHardChatThreadCompactor(
            inner: DefaultChatThreadCompactor(
                summarizer: summarizer,
                keepRecentTurns: 2,
                minTurnsToCompact: 2
            )
        )
        let viewModel = ChatViewModel(
            dependencies: ChatFeatureDependencies(
                historyStore: InMemoryChatHistoryStore(),
                shareImportAPI: KairoShareImportBackendService(shareIngestionQueue: InMemoryShareIngestionQueue()),
                chatAPI: chatAPI,
                actionAPI: KairoActionBackendService(
                    actionExecutor: SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
                ),
                threadCompactor: compactor
            )
        )

        await viewModel.send("第一句")
        await viewModel.send("第二句")
        await viewModel.send("第三句")
        await viewModel.send("第四句")

        let captures = await chatAPI.allCalls()
        let last = try XCTUnwrap(captures.last)
        XCTAssertTrue(last.history.first?.text.contains("Eason 想測試記憶") == true)
        XCTAssertNotEqual(last.conversationID, viewModel.currentThread.id.uuidString)
        XCTAssertTrue(last.conversationID?.hasPrefix(viewModel.currentThread.id.uuidString + "#g") == true)
        XCTAssertGreaterThanOrEqual(viewModel.currentThread.compactionGeneration, 1)
        XCTAssertEqual(viewModel.currentThread.rollingSummary, "Eason 想測試記憶")
    }
}

private actor StubSummarizingAIProvider: AIProvider {
    private let summary: String
    init(summary: String) { self.summary = summary }
    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        AICompletionResponse(message: summary)
    }
    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        AIEmbeddingResponse(vector: [])
    }
}

private actor ConversationHistoryCapturingChatAPI: KairoChatAPI {
    struct Call: Sendable {
        var conversationID: String?
        var history: [AIConversationTurn]
        var message: String
    }

    private var calls: [Call] = []

    func respond(to message: String, attachments: [ChatAttachment], privacyMode: ChatPrivacyMode) async throws -> AICompletionResponse {
        try await respond(
            to: message,
            attachments: attachments,
            conversationID: nil,
            conversationHistory: [],
            privacyMode: privacyMode
        )
    }

    func respond(
        to message: String,
        attachments: [ChatAttachment],
        conversationID: String?,
        conversationHistory: [AIConversationTurn],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        calls.append(Call(conversationID: conversationID, history: conversationHistory, message: message))
        return AICompletionResponse(
            message: "ack \(calls.count)",
            inferenceMetrics: AIInferenceMetrics(stage: .complete, promptTokens: 100 * calls.count)
        )
    }

    func allCalls() -> [Call] { calls }
}

private actor ForcingChatThreadCompactor: ChatThreadCompacting {
    private let inner: any ChatThreadCompacting
    init(inner: any ChatThreadCompacting) { self.inner = inner }

    nonisolated func pressure(
        for thread: ChatThread,
        additionalUserTextChars: Int,
        budget: ChatContextBudget
    ) -> ChatContextPressure {
        inner.pressure(for: thread, additionalUserTextChars: additionalUserTextChars, budget: budget)
    }

    nonisolated func compact(
        _ thread: ChatThread,
        budget: ChatContextBudget
    ) async throws -> ChatCompactionResult {
        try await inner.compact(thread, budget: budget)
    }
}

private final class AlwaysHardChatThreadCompactor: ChatThreadCompacting, @unchecked Sendable {
    private let inner: any ChatThreadCompacting
    init(inner: any ChatThreadCompacting) { self.inner = inner }

    func pressure(
        for thread: ChatThread,
        additionalUserTextChars: Int,
        budget: ChatContextBudget
    ) -> ChatContextPressure {
        .hard
    }

    func compact(
        _ thread: ChatThread,
        budget: ChatContextBudget
    ) async throws -> ChatCompactionResult {
        try await inner.compact(thread, budget: budget)
    }
}
