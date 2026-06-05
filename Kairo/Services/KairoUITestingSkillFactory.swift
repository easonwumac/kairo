import Foundation

public struct KairoUITestingSkillComponents: Sendable {
    public var managerService: AgentSkillManagerService
    public var marketplaceCatalogService: AgentSkillMarketplaceCatalogService

    public init(
        managerService: AgentSkillManagerService,
        marketplaceCatalogService: AgentSkillMarketplaceCatalogService
    ) {
        self.managerService = managerService
        self.marketplaceCatalogService = marketplaceCatalogService
    }
}

public struct KairoUITestingSkillFactory: Sendable {
    public var rootDirectory: URL
    public var seedInstalledWeatherSkill: Bool

    public init(rootDirectory: URL, seedInstalledWeatherSkill: Bool = false) {
        self.rootDirectory = rootDirectory
        self.seedInstalledWeatherSkill = seedInstalledWeatherSkill
    }

    public func makeComponents() async throws -> KairoUITestingSkillComponents {
        let skillStore = try await FileBackedAgentSkillStore(
            fileURL: rootDirectory
                .appendingPathComponent("Skills", isDirectory: true)
                .appendingPathComponent("agent-skills.json")
        )
        let managerService = AgentSkillManagerService(
            store: skillStore,
            builtInCatalog: .defaultWithMarketplaceSamples,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.0",
                grantedEntitlements: [],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: []
            )
        )
        if seedInstalledWeatherSkill {
            try await skillStore.upsert(Self.installedWeatherSkill(version: "2.0.0"))
        }

        return KairoUITestingSkillComponents(
            managerService: managerService,
            marketplaceCatalogService: try Self.marketplaceCatalogService()
        )
    }

    public static func marketplaceCatalogService() throws -> AgentSkillMarketplaceCatalogService {
        let indexURL = AgentSkillMarketplaceCatalogService.defaultIndexURL
        let manifestURL = URL(string: "manifests/weather-briefing.json", relativeTo: indexURL)!.absoluteURL
        let qwenWorkflowManifestURL = URL(string: "manifests/qwen-oauth-workflow.json", relativeTo: indexURL)!.absoluteURL
        var weatherSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: manifestURL
        )
        weatherSkill.version = "2.1.0"
        weatherSkill.author = "Kairo Marketplace"

        let manifest = try AgentSkillManifest(
            skill: weatherSkill,
            packageVersion: "2026.6",
            checksum: AgentSkillManifest.sha256Hex(for: weatherSkill),
            signature: AgentSkillManifestSignature(
                keyID: "kairo-test-key",
                algorithm: .ed25519,
                value: "test-signature"
            ),
            changelog: ["Adds storm alerts."]
        )
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        var qwenWorkflowSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires Google OAuth and a downloaded Qwen model before it can be installed.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: qwenWorkflowManifestURL
        )
        qwenWorkflowSkill.version = "1.0.0"
        qwenWorkflowSkill.author = "Kairo Marketplace"
        qwenWorkflowSkill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let qwenWorkflowManifest = try AgentSkillManifest.signedForTesting(
            skill: qwenWorkflowSkill,
            packageVersion: "2026.6"
        )
        let qwenWorkflowManifestJSON = try AgentSkillManifest.encodeJSONString(qwenWorkflowManifest)
        let indexJSON = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API and returns a compact daily plan.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            },
            {
              "id": "marketplace-qwen-oauth-workflow",
              "displayName": "Qwen OAuth Workflow",
              "summary": "Requires Google OAuth and a downloaded Qwen model before it can be installed.",
              "version": "1.0.0",
              "author": "Kairo Marketplace",
              "category": "Local Model",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 2: local model plus OAuth-gated request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/qwen-oauth-workflow.json",
              "screenshots": ["assets/shortcut-toolkit-card.svg"],
              "changelog": ["Adds compatibility gates for OAuth and local model availability."],
              "compatibilityRequirements": {
                "requiredOAuthProviderKeys": ["google"],
                "requiredLocalModelIDs": ["qwen3-5-0-8b-q4-k-m"]
              }
            }
          ]
        }
        """
        let httpClient = StaticHTTPClient(routes: [
            indexURL: StaticHTTPResponse(body: indexJSON),
            manifestURL: StaticHTTPResponse(body: manifestJSON),
            qwenWorkflowManifestURL: StaticHTTPResponse(body: qwenWorkflowManifestJSON)
        ])

        return AgentSkillMarketplaceCatalogService(indexURL: indexURL, httpClient: httpClient)
    }

    public static func installedWeatherSkill(version: String) -> AgentSkill {
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API and returns a compact daily plan.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(
                string: "manifests/weather-briefing.json",
                relativeTo: AgentSkillMarketplaceCatalogService.defaultIndexURL
            )!.absoluteURL
        )
        skill.version = version
        skill.author = "Kairo Marketplace"
        skill.installationStatus = .installed
        return skill
    }
}
