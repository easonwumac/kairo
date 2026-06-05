import XCTest
@testable import KairoCore

final class ChatMemorySuggestionTests: XCTestCase {
    @MainActor
    func testChatSuggestsRefinedMemoryAndSavesOnlyAfterConfirmation() async throws {
        let memoryStore = InMemoryMemoryStore()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: makeMemorySuggestionChatAPI(memoryStore: memoryStore),
            actionExecutor: SandboxActionExecutor(memoryStore: memoryStore)
        )

        await viewModel.send("Please remember that I prefer morning standups for Kairo planning.")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let memoryAction = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .saveMemory })
        guard case .text(let proposedMemory) = memoryAction.payload else {
            return XCTFail("Expected saveMemory action to carry refined text.")
        }
        XCTAssertEqual(proposedMemory, "I prefer morning standups for Kairo planning")
        let unsaved = try await memoryStore.list(limit: 10)
        XCTAssertTrue(unsaved.isEmpty)

        viewModel.previewAction(memoryAction)
        await viewModel.confirmPendingAction()

        let saved = try await memoryStore.search(query: "morning standups", limit: 10)
        XCTAssertEqual(saved.map(\.content), [proposedMemory])
    }

    @MainActor
    func testPrivateChatDoesNotSuggestMemorySave() async throws {
        let memoryStore = InMemoryMemoryStore()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: makeMemorySuggestionChatAPI(memoryStore: memoryStore),
            actionExecutor: SandboxActionExecutor(memoryStore: memoryStore)
        )

        viewModel.setPrivateChatEnabled(true)
        await viewModel.send("Please remember that my launch code name is cedar.")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertFalse(assistantMessage.proposedActions.contains { $0.kind == .saveMemory })
        let saved = try await memoryStore.list(limit: 10)
        XCTAssertTrue(saved.isEmpty)
    }

    func testAgentCoreUsesRecentMemoriesToAvoidDuplicateSaveSuggestionsWhenSearchMisses() async throws {
        let existingMemory = MemoryRecord(
            title: "Planning preference",
            summary: "I prefer morning standups for Kairo planning",
            content: "I prefer morning standups for Kairo planning",
            source: .chat
        )
        let memoryStore = SearchMissMemoryStore(recentMemories: [existingMemory])
        let agent = AgentCore(memoryStore: memoryStore, aiProvider: MockAIProvider())

        let response = try await agent.respond(to: "Please remember that I prefer morning standups for Kairo planning.")

        XCTAssertFalse(response.proposedActions.contains { $0.kind == .saveMemory })
    }

    private func makeMemorySuggestionChatAPI(memoryStore: any MemoryStore) -> any KairoChatAPI {
        KairoChatBackendService(agent: AgentCore(memoryStore: memoryStore, aiProvider: MockAIProvider()))
    }
}

private actor SearchMissMemoryStore: MemoryStore {
    private let recentMemories: [MemoryRecord]

    init(recentMemories: [MemoryRecord]) {
        self.recentMemories = recentMemories
    }

    func save(_ memory: MemoryRecord) async throws {}

    func search(query: String, limit: Int) async throws -> [MemoryRecord] {
        return []
    }

    func list(limit: Int) async throws -> [MemoryRecord] {
        return recentMemories
    }

    func delete(id: UUID) async throws {}

    func erase(id: UUID) async throws {}

    func purgeDeleted() async throws {}

    func export(limit: Int) async throws -> MemoryExport {
        MemoryExport(records: recentMemories)
    }
}
