import XCTest
@testable import KairoCore

final class KairoBackendAPITests: XCTestCase {
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
}
