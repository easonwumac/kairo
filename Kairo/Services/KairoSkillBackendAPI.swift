import Foundation

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
