import Foundation

public struct KairoBackendAPI: Sendable {
    public let chat: any KairoChatAPI
    public let deletion: any KairoDeletionAPI
    public let localModels: any KairoLocalModelAPI
    public let skills: any KairoSkillAPI
    public let settings: any KairoSettingsAPI

    public init(
        chat: any KairoChatAPI,
        deletion: any KairoDeletionAPI,
        localModels: any KairoLocalModelAPI,
        skills: any KairoSkillAPI,
        settings: any KairoSettingsAPI
    ) {
        self.chat = chat
        self.deletion = deletion
        self.localModels = localModels
        self.skills = skills
        self.settings = settings
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

public protocol KairoLocalModelAPI: Sendable {
    func status() async throws -> LocalModelSettingsStatus
    func selectModel(id: String) async throws
    func clearSelectedModel() async throws
    func setPreference(_ preference: ProviderRoutePreference) async throws
    @discardableResult
    func cleanupStaleDownloadingRecords() async throws -> [String]
    func deleteModel(id: String) async throws
}

public enum KairoLocalModelAPIError: Error, Equatable {
    case unavailable
}

public struct KairoLocalModelBackendService: KairoLocalModelAPI {
    private let localModelSettingsService: LocalModelSettingsService?

    public init(localModelSettingsService: LocalModelSettingsService?) {
        self.localModelSettingsService = localModelSettingsService
    }

    public func status() async throws -> LocalModelSettingsStatus {
        try await service().status()
    }

    public func selectModel(id: String) async throws {
        try await service().selectModel(id: id)
    }

    public func clearSelectedModel() async throws {
        try await service().clearSelectedModel()
    }

    public func setPreference(_ preference: ProviderRoutePreference) async throws {
        try await service().setPreference(preference)
    }

    @discardableResult
    public func cleanupStaleDownloadingRecords() async throws -> [String] {
        try await service().cleanupStaleDownloadingRecords()
    }

    public func deleteModel(id: String) async throws {
        try await service().deleteModel(id: id)
    }

    private func service() throws -> LocalModelSettingsService {
        guard let localModelSettingsService else {
            throw KairoLocalModelAPIError.unavailable
        }
        return localModelSettingsService
    }
}

public protocol KairoSkillAPI: Sendable {
    func catalog() async throws -> AgentSkillCatalog
    func effectiveCatalog() async throws -> AgentSkillCatalog
    func previewInstall(jsonString: String) async throws -> AgentSkillInstallPreview
    func installManifest(jsonString: String) async throws -> AgentSkill
    func createUserSkillDraft(_ request: AgentSkillDraftRequest) async throws -> AgentSkill
    func disableSkill(id: String) async throws -> AgentSkill?
    func enableSkill(id: String) async throws -> AgentSkill?
    func removeSkill(id: String) async throws
}

public enum KairoSkillAPIError: Error, Equatable {
    case unavailable
}

public struct KairoSkillBackendService: KairoSkillAPI {
    private let agentSkillManagerService: AgentSkillManagerService?

    public init(agentSkillManagerService: AgentSkillManagerService?) {
        self.agentSkillManagerService = agentSkillManagerService
    }

    public func catalog() async throws -> AgentSkillCatalog {
        try await service().catalog()
    }

    public func effectiveCatalog() async throws -> AgentSkillCatalog {
        try await service().effectiveCatalog()
    }

    public func previewInstall(jsonString: String) async throws -> AgentSkillInstallPreview {
        try await service().previewInstall(jsonString: jsonString)
    }

    public func installManifest(jsonString: String) async throws -> AgentSkill {
        try await service().installManifest(jsonString: jsonString)
    }

    public func createUserSkillDraft(_ request: AgentSkillDraftRequest) async throws -> AgentSkill {
        try await service().createUserSkillDraft(request)
    }

    public func disableSkill(id: String) async throws -> AgentSkill? {
        try await service().disableSkill(id: id)
    }

    public func enableSkill(id: String) async throws -> AgentSkill? {
        try await service().enableSkill(id: id)
    }

    public func removeSkill(id: String) async throws {
        try await service().removeSkill(id: id)
    }

    private func service() throws -> AgentSkillManagerService {
        guard let agentSkillManagerService else {
            throw KairoSkillAPIError.unavailable
        }
        return agentSkillManagerService
    }
}

public protocol KairoSettingsAPI: Sendable {
    func openAIStatus() async throws -> OpenAISettingsStatus
    func saveOpenAIAPIKey(_ apiKey: String) async throws
    func dryRunOpenAIAPIKey(_ apiKey: String?) async throws -> OpenAISettingsDryRunResult
    func deleteOpenAIAPIKey() async throws
    func oauthLoginOptions() async throws -> [OAuthConnectorLoginOption]
    func makeOAuthAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession
    func previewOAuthCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview
    func disconnectOAuthProvider(providerKey: String) async throws
}

public struct KairoSettingsBackendService: KairoSettingsAPI {
    private let openAISettingsService: OpenAISettingsService
    private let oauthLoginCenter: OAuthConnectorLoginCenter

    public init(
        openAISettingsService: OpenAISettingsService,
        oauthLoginCenter: OAuthConnectorLoginCenter
    ) {
        self.openAISettingsService = openAISettingsService
        self.oauthLoginCenter = oauthLoginCenter
    }

    public func openAIStatus() async throws -> OpenAISettingsStatus {
        try await openAISettingsService.status()
    }

    public func saveOpenAIAPIKey(_ apiKey: String) async throws {
        try await openAISettingsService.saveAPIKey(apiKey)
    }

    public func dryRunOpenAIAPIKey(_ apiKey: String?) async throws -> OpenAISettingsDryRunResult {
        try await openAISettingsService.dryRunAPIKey(apiKey)
    }

    public func deleteOpenAIAPIKey() async throws {
        try await openAISettingsService.deleteAPIKey()
    }

    public func oauthLoginOptions() async throws -> [OAuthConnectorLoginOption] {
        try await oauthLoginCenter.loginOptions()
    }

    public func makeOAuthAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession {
        try await oauthLoginCenter.makeAuthorizationSession(
            for: integrationKey,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    public func previewOAuthCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        try await oauthLoginCenter.previewCallback(callbackURL)
    }

    public func disconnectOAuthProvider(providerKey: String) async throws {
        try await oauthLoginCenter.disconnect(providerKey: providerKey)
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
            ),
            localModels: KairoLocalModelBackendService(
                localModelSettingsService: localModelSettingsService
            ),
            skills: KairoSkillBackendService(
                agentSkillManagerService: agentSkillManagerService
            ),
            settings: KairoSettingsBackendService(
                openAISettingsService: OpenAISettingsService(credentialStore: credentialStore),
                oauthLoginCenter: OAuthConnectorLoginCenter(credentialStore: credentialStore)
            )
        )
    }
}
