import XCTest
import Foundation
@testable import KairoCore

final class AgentSkillEffectiveCatalogTests: XCTestCase {
    func testAgentCoreUsesLiveSkillManagerCatalogWhenPlanningToolCandidates() async throws {
        let service = try await makeSkillManagerService()
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalogProvider: .skillManager(service)
        )

        _ = try await service.disableSkill(id: "shortcut-save-shared-text")
        let disabledResponse = try await agent.respond(to: "Turn this shared text into todo tasks")
        XCTAssertFalse(disabledResponse.toolCandidates.contains { $0.skillID == "shortcut-save-shared-text" })

        _ = try await service.enableSkill(id: "shortcut-save-shared-text")
        let enabledResponse = try await agent.respond(to: "Turn this shared text into todo tasks")
        XCTAssertTrue(enabledResponse.toolCandidates.contains { $0.skillID == "shortcut-save-shared-text" })
    }

    func testAgentCoreEffectiveCatalogIncludesInstalledMarketplaceSkillCandidates() async throws {
        let service = try await makeSkillManagerService()
        let weatherSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: weatherSkill, packageVersion: "2026.6")
        try await service.install(manifest: manifest)
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalogProvider: .skillManager(service)
        )

        let response = try await agent.respond(to: "Use the weather briefing skill")

        let candidate = try XCTUnwrap(response.toolCandidates.first { $0.skillID == "marketplace-weather-briefing" })
        XCTAssertEqual(candidate.source, .installedSkill)
        XCTAssertEqual(candidate.skillKind, .custom)
    }

    func testAgentCoreEffectiveCatalogExcludesCompatibilityBlockedInstalledSkills() async throws {
        var blockedSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-blocked-oauth-weather",
            displayName: "Blocked OAuth Weather",
            summary: "Weather skill that requires Google OAuth before execution.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/blocked-weather.json")!
        )
        blockedSkill.installationStatus = .installed
        blockedSkill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"]
        )
        let service = try await makeSkillManagerService(
            builtInCatalog: AgentSkillCatalog(skills: [blockedSkill]),
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.0",
                connectedOAuthProviderKeys: []
            )
        )
        let fullCatalog = try await service.catalog()
        XCTAssertEqual(fullCatalog.skill(id: "marketplace-blocked-oauth-weather")?.installationStatus, .installed)

        let effectiveCatalog = try await service.effectiveCatalog()
        XCTAssertFalse(effectiveCatalog.installedSkills.contains { $0.id == "marketplace-blocked-oauth-weather" })

        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalogProvider: .skillManager(service)
        )
        let response = try await agent.respond(to: "Use blocked OAuth weather")

        XCTAssertFalse(response.toolCandidates.contains { $0.skillID == "marketplace-blocked-oauth-weather" })
    }

    private func makeSkillManagerService(
        builtInCatalog: AgentSkillCatalog = .default,
        runtimeContext: AgentSkillRuntimeContext = .permissive
    ) async throws -> AgentSkillManagerService {
        let store = try await FileBackedAgentSkillStore(fileURL: temporaryFileURL(named: "agent-skills.json"))
        return AgentSkillManagerService(
            store: store,
            builtInCatalog: builtInCatalog,
            runtimeContext: runtimeContext
        )
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }
}
