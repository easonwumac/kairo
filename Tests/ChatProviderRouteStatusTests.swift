import XCTest
@testable import KairoCore

final class ChatProviderRouteStatusTests: XCTestCase {
    @MainActor
    func testChatRouteStatusReflectsOpenAIKeySaveAndDelete() async throws {
        let credentials = InMemoryCredentialStore()
        let settingsService = OpenAISettingsService(credentialStore: credentials)
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            openAISettingsService: settingsService
        )

        await viewModel.refreshProviderRouteStatus()
        XCTAssertEqual(viewModel.providerRouteStatus.title, "Route: Cloud")
        XCTAssertEqual(viewModel.providerRouteStatus.warning, "OpenAI API key is not saved.")
        XCTAssertTrue(viewModel.providerRouteStatus.detail.contains("Chat will fail closed"))

        try await settingsService.saveAPIKey("sk-test-chat-route")
        await viewModel.refreshProviderRouteStatus()
        XCTAssertNil(viewModel.providerRouteStatus.warning)
        XCTAssertTrue(viewModel.providerRouteStatus.detail.contains("OpenAI is configured"))

        try await settingsService.deleteAPIKey()
        await viewModel.refreshProviderRouteStatus()
        XCTAssertEqual(viewModel.providerRouteStatus.warning, "OpenAI API key is not saved.")
    }
}
