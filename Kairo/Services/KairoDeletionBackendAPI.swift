import Foundation

public protocol KairoDeletionAPI: Sendable {
    func deleteChatThread(id: UUID) async throws
    func deleteMemory(id: UUID) async throws
    func purgeDeletedMemories() async throws
    func deleteOpenAIAPIKey() async throws
    func disconnectOAuthProvider(providerKey: String) async throws
    func deleteLocalModel(id: String) async throws
    func clearAuditLog() async throws
}

public enum KairoDeletionAPIError: Error, Equatable {
    case localModelDeletionUnavailable
}

public struct KairoDeletionBackendService: KairoDeletionAPI {
    private let chatHistoryStore: any ChatHistoryStore
    private let memoryStore: any MemoryStore
    private let credentialStore: any CredentialStore
    private let auditLogger: any AuditLogger
    private let localModelSettingsService: LocalModelSettingsService?

    public init(
        chatHistoryStore: any ChatHistoryStore,
        memoryStore: any MemoryStore,
        credentialStore: any CredentialStore,
        auditLogger: any AuditLogger,
        localModelSettingsService: LocalModelSettingsService? = nil
    ) {
        self.chatHistoryStore = chatHistoryStore
        self.memoryStore = memoryStore
        self.credentialStore = credentialStore
        self.auditLogger = auditLogger
        self.localModelSettingsService = localModelSettingsService
    }

    public func deleteChatThread(id: UUID) async throws {
        try await chatHistoryStore.deleteThread(id: id)
    }

    public func deleteMemory(id: UUID) async throws {
        try await memoryStore.delete(id: id)
    }

    public func purgeDeletedMemories() async throws {
        try await memoryStore.purgeDeleted()
    }

    public func deleteOpenAIAPIKey() async throws {
        try await credentialStore.deleteSecret(for: CredentialKey.openAIAPIKey)
    }

    public func disconnectOAuthProvider(providerKey: String) async throws {
        try await OAuthConnectorLoginCenter(credentialStore: credentialStore)
            .disconnect(providerKey: providerKey)
    }

    public func deleteLocalModel(id: String) async throws {
        guard let localModelSettingsService else {
            throw KairoDeletionAPIError.localModelDeletionUnavailable
        }
        try await localModelSettingsService.deleteModel(id: id)
    }

    public func clearAuditLog() async throws {
        try await auditLogger.clear()
    }
}
