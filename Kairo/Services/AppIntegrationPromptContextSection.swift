import Foundation

public protocol AppIntegrationPromptContextProviding: Sendable {
    func buildAppIntegrationSection() -> String
}

public struct AppIntegrationPromptContextSection: AppIntegrationPromptContextProviding {
    public var catalog: any AppIntegrationSkillCatalogProviding

    public init(catalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()) {
        self.catalog = catalog
    }

    public func buildAppIntegrationSection() -> String {
        catalog.skills.map { skill in
            let surfaces = skill.supportedSurfaces.map(\.rawValue).joined(separator: ",")
            let capabilities = skill.audit.capabilityKeys.map(\.rawValue).joined(separator: ",")
            let scopes = skill.oauth?.requiredScopes.joined(separator: ",") ?? "none"
            return "- \(skill.id.rawValue): \(skill.appName); integrationKey=\(skill.integrationKey); surfaces=\(surfaces); capability=\(capabilities); permission=\(skill.permissionRequirement.rawValue); risk=\(skill.riskTier.rawValue); availability=\(skill.availabilityStatus.rawValue); setup=\(skill.setupRequirement.rawValue); execution=\(skill.executionMode.rawValue); confirmation=\(skill.confirmationPolicy.rawValue); executable=\(skill.canBeSuggestedAsExecutable); oauthScopes=\(scopes); input=\(skill.schema.input); output=\(skill.schema.output)"
        }
        .joined(separator: "\n")
    }
}
