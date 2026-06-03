import Foundation

public struct KairoBackendAPI: Sendable {
    public let chat: any KairoChatAPI
    public let deletion: any KairoDeletionAPI

    public init(chat: any KairoChatAPI, deletion: any KairoDeletionAPI) {
        self.chat = chat
        self.deletion = deletion
    }
}

public protocol KairoChatAPI: Sendable {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse
}

public struct KairoChatBackendService: KairoChatAPI {
    private let agent: AgentCore

    public init(agent: AgentCore) {
        self.agent = agent
    }

    public func respond(
        to message: String,
        attachments: [ChatAttachment] = [],
        privacyMode: ChatPrivacyMode = .standard
    ) async throws -> AICompletionResponse {
        try await agent.respond(
            to: message,
            attachments: attachments,
            privacyMode: privacyMode
        )
    }
}

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

public extension KairoEnvironment {
    var backendAPI: KairoBackendAPI {
        let skillCatalogProvider: AgentSkillCatalogProvider
        if let agentSkillManagerService {
            skillCatalogProvider = .skillManager(agentSkillManagerService)
        } else {
            skillCatalogProvider = .default
        }
        let agent = AgentCore(
            memoryStore: memoryStore,
            aiProvider: aiProvider,
            skillCatalogProvider: skillCatalogProvider
        )
        return KairoBackendAPI(
            chat: KairoChatBackendService(agent: agent),
            deletion: KairoDeletionBackendService(
                chatHistoryStore: chatHistoryStore,
                memoryStore: memoryStore,
                credentialStore: credentialStore,
                auditLogger: auditLogger,
                localModelSettingsService: localModelSettingsService
            )
        )
    }
}
