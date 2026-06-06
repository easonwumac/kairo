import XCTest
import Foundation
@testable import KairoCore

final class KairoDeletionBackendAPITests: XCTestCase {
    func testDeletionBackendAPIDeletesOnDevicePrivacyDataThroughCoreInterfaces() async throws {
        let threadID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let memoryID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let chatStore = InMemoryChatHistoryStore(seed: [
            ChatThread(id: threadID, messages: [
                ChatMessage(role: .user, text: "Private thread")
            ])
        ])
        let memoryStore = InMemoryMemoryStore(seed: [
            MemoryRecord(
                id: memoryID,
                title: "Private memory",
                summary: "Delete through backend API",
                content: "Sensitive user-approved content",
                source: .manual
            )
        ])
        let credentialStore = InMemoryCredentialStore()
        let auditLogger = InMemoryAuditLogger()
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: chatStore,
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            auditLogger: auditLogger
        )

        try await credentialStore.saveSecret("sk-test", for: CredentialKey.openAIAPIKey)
        try await credentialStore.saveSecret(
            try OAuthTokenSet(accessToken: "oauth-token", scopes: ["repo"]).encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "github")
        )
        try await auditLogger.record(AuditEvent(
            actionKind: .saveMemory,
            memoryIDs: [memoryID],
            capabilityKeys: [.memory],
            usedCloudModel: false,
            requiredConfirmation: true,
            userConfirmed: true,
            result: .completed
        ))

        try await deletionAPI.deleteChatThread(id: threadID)
        try await deletionAPI.purgeDeletedChatThreads()
        try await deletionAPI.deleteMemory(id: memoryID)
        try await deletionAPI.purgeDeletedMemories()
        try await deletionAPI.deleteOpenAIAPIKey()
        try await deletionAPI.disconnectOAuthProvider(providerKey: "github")
        try await deletionAPI.clearAuditLog()

        let deletedThread = try await chatStore.thread(id: threadID)
        let remainingMemories = try await memoryStore.list(limit: 10)
        let openAIAPIKey = try await credentialStore.readSecret(for: CredentialKey.openAIAPIKey)
        let githubToken = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "github"))
        let auditEvents = try await auditLogger.list(limit: 10)

        XCTAssertNil(deletedThread)
        XCTAssertTrue(remainingMemories.isEmpty)
        XCTAssertNil(openAIAPIKey)
        XCTAssertNil(githubToken)
        XCTAssertTrue(auditEvents.isEmpty)
    }

    func testDeletionBackendAPIFailsClosedWhenLocalModelServiceIsUnavailable() async throws {
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: InMemoryChatHistoryStore(),
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            auditLogger: InMemoryAuditLogger()
        )

        do {
            try await deletionAPI.deleteLocalModel(id: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected local model deletion to fail closed without a configured service.")
        } catch let error as KairoDeletionAPIError {
            XCTAssertEqual(error, .localModelDeletionUnavailable)
        }
    }

    func testDeletionBackendAPIDeletesLocalModelThroughSettingsService() async throws {
        let localModelSettingsService = try await makeBackendTestLocalModelSettingsService()
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: InMemoryChatHistoryStore(),
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            auditLogger: InMemoryAuditLogger(),
            localModelSettingsService: localModelSettingsService
        )

        try await localModelSettingsService.selectModel(id: "qwen-small")
        var status = await localModelSettingsService.status()
        XCTAssertEqual(status.selectedModelID, "qwen-small")
        XCTAssertTrue(status.installedModels.contains { $0.modelID == "qwen-small" })

        try await deletionAPI.deleteLocalModel(id: "qwen-small")

        status = await localModelSettingsService.status()
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.installedModels.contains { $0.modelID == "qwen-small" })
    }

    func testDeletionBackendAPIUsesInjectedOAuthLoginServiceForDisconnect() async throws {
        let oauthLoginService = CapturingDeletionOAuthLoginService()
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: InMemoryChatHistoryStore(),
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            auditLogger: InMemoryAuditLogger(),
            oauthLoginService: oauthLoginService
        )

        try await deletionAPI.disconnectOAuthProvider(providerKey: "todoist")

        let disconnectedProviderKeys = await oauthLoginService.disconnectedProviderKeys()
        XCTAssertEqual(disconnectedProviderKeys, ["todoist"])
    }

    func testSettingsPrivacyCoordinatorDeletesAllChatHistoryThroughDeletionAPI() async throws {
        let chatStore = InMemoryChatHistoryStore(seed: [
            ChatThread(messages: [ChatMessage(role: .user, text: "First private chat")]),
            ChatThread(messages: [ChatMessage(role: .user, text: "Second private chat")])
        ])
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: chatStore,
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            auditLogger: InMemoryAuditLogger()
        )
        let coordinator = SettingsPrivacyCoordinator(deletionAPI: deletionAPI)

        try await coordinator.deleteAllChatThreads()
        let threads = try await chatStore.listThreads(limit: 10)

        XCTAssertTrue(threads.isEmpty)
    }

    func testSettingsPrivacyCoordinatorFailsClosedWhenDeletionAPIIsUnavailable() async throws {
        let coordinator = SettingsPrivacyCoordinator(deletionAPI: nil)

        do {
            try await coordinator.deleteAllChatThreads()
            XCTFail("Expected unavailable privacy coordinator to fail closed.")
        } catch let error as SettingsPrivacyCoordinatorError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    func testDeletionBackendAPIPurgesDeletedChatHistoryFromDisk() async throws {
        let threadID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let fileURL = temporaryFileURL(named: "chat-history-deletion-proof.json")
        let chatStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        let deletionAPI = KairoDeletionBackendService(
            chatHistoryStore: chatStore,
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            auditLogger: InMemoryAuditLogger()
        )

        try await chatStore.saveThread(ChatThread(id: threadID, messages: [
            ChatMessage(role: .user, text: "Delete this private launch note")
        ]))

        try await deletionAPI.deleteChatThread(id: threadID)
        var rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(threadID.uuidString))
        XCTAssertTrue(rawText.contains("Delete this private launch note"))

        try await deletionAPI.purgeDeletedChatThreads()

        let deletedThread = try await chatStore.thread(id: threadID)
        rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertNil(deletedThread)
        XCTAssertFalse(rawText.contains(threadID.uuidString))
        XCTAssertFalse(rawText.contains("Delete this private launch note"))
    }

    @MainActor
    func testChatViewModelDeleteThreadPurgesDeletedChatHistoryFromDisk() async throws {
        let threadID = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        let fileURL = temporaryFileURL(named: "chat-history-view-model-delete.json")
        let chatStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        let thread = ChatThread(id: threadID, messages: [ChatMessage(role: .user, text: "Delete this UI thread from disk")])
        let viewModel = ChatViewModel(historyStore: chatStore)
        try await chatStore.saveThread(thread)
        await viewModel.load()
        XCTAssertEqual(viewModel.threads.map(\.id), [threadID])
        await viewModel.deleteThread(thread)
        let rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(viewModel.threads.isEmpty)
        XCTAssertFalse(rawText.contains(threadID.uuidString))
        XCTAssertFalse(rawText.contains("Delete this UI thread from disk"))
    }

    private func temporaryFileURL(named name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoDeletionBackendAPITests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}

private actor CapturingDeletionOAuthLoginService: OAuthConnectorLoginServicing {
    private var providerKeys: [String] = []

    func disconnectedProviderKeys() -> [String] {
        providerKeys
    }

    func loginOptions() async throws -> [OAuthConnectorLoginOption] {
        []
    }

    func makeAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession {
        throw OAuthConnectorLoginCenterError.missingIntegration(integrationKey)
    }

    func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        throw OAuthConnectorLoginCenterError.missingIntegration(callbackURL.absoluteString)
    }

    func exchangeCallback(
        _ callbackURL: URL,
        expectedState: String,
        codeVerifier: String?
    ) async throws -> OAuthTokenSet {
        throw OAuthConnectorLoginCenterError.missingIntegration(callbackURL.absoluteString)
    }

    func disconnect(providerKey: String) async throws {
        providerKeys.append(providerKey)
    }
}
