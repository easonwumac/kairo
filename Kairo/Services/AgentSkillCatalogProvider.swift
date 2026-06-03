import Foundation

public struct AgentSkillCatalogProvider: Sendable {
    private let loadCatalog: @Sendable () async throws -> AgentSkillCatalog

    public init(loadCatalog: @escaping @Sendable () async throws -> AgentSkillCatalog) {
        self.loadCatalog = loadCatalog
    }

    public func catalog() async throws -> AgentSkillCatalog {
        try await loadCatalog()
    }

    public static func constant(_ catalog: AgentSkillCatalog) -> AgentSkillCatalogProvider {
        AgentSkillCatalogProvider { catalog }
    }

    public static func skillManager(_ service: AgentSkillManagerService) -> AgentSkillCatalogProvider {
        AgentSkillCatalogProvider {
            try await service.effectiveCatalog()
        }
    }

    public static let `default` = AgentSkillCatalogProvider.constant(.default)
}
