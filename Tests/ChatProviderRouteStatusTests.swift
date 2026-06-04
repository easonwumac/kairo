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
        XCTAssertEqual(
            viewModel.providerRouteStatus.title,
            KairoL10n.string("chat.provider.route.title", KairoL10n.string("chat.provider.route.cloud"))
        )
        XCTAssertEqual(
            viewModel.providerRouteStatus.warning,
            KairoL10n.string("chat.provider.warning.openAIKeyMissing", "OpenAI")
        )
        XCTAssertEqual(
            viewModel.providerRouteStatus.detail,
            KairoL10n.string("chat.provider.detail.cloudKeyMissing", "OpenAI")
        )

        try await settingsService.saveAPIKey("sk-test-chat-route")
        await viewModel.refreshProviderRouteStatus()
        XCTAssertNil(viewModel.providerRouteStatus.warning)
        XCTAssertEqual(
            viewModel.providerRouteStatus.detail,
            KairoL10n.string("chat.provider.detail.cloudConfigured", "OpenAI")
        )

        try await settingsService.deleteAPIKey()
        await viewModel.refreshProviderRouteStatus()
        XCTAssertEqual(
            viewModel.providerRouteStatus.warning,
            KairoL10n.string("chat.provider.warning.openAIKeyMissing", "OpenAI")
        )
    }
}
