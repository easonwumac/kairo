import Foundation

public struct CapabilityPromptContextBuilder: Sendable {
    public var capabilityRegistry: CapabilityRegistry
    public var toolCatalog: any BuiltInPhoneToolCatalogProviding
    public var integrationRegistry: IntegrationRegistry
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var backgroundTaskPolicy: BackgroundTaskPolicy
    public var skillCatalog: AgentSkillCatalog

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        integrationRegistry: IntegrationRegistry = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        backgroundTaskPolicy: BackgroundTaskPolicy = BackgroundTaskPolicy(),
        skillCatalog: AgentSkillCatalog = .default
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.toolCatalog = toolCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.backgroundTaskPolicy = backgroundTaskPolicy
        self.skillCatalog = skillCatalog
    }

    public func build() -> String {
        let capabilityLines = capabilityRegistry.capabilities.map { capability in
            "- \(capability.key.rawValue): \(capability.displayName); permission=\(capability.permission.rawValue); status=\(capability.status.rawValue); \(capability.description)"
        }

        let actionLines = toolCatalog.tools.map { tool in
            let actionKinds = tool.sourceBinding.agentActionKinds.map(\.rawValue).joined(separator: ",")
            let capabilities = tool.audit.capabilityKeys.map(\.rawValue).joined(separator: ",")
            return "- \(tool.id.rawValue): \(tool.displayName); actions=\(actionKinds.isEmpty ? "none" : actionKinds); capability=\(capabilities); permission=\(tool.permissionRequirement.rawValue); risk=\(tool.riskTier.rawValue); availability=\(tool.availabilityStatus.rawValue); execution=\(tool.executionKind.rawValue); confirmation=\(tool.confirmationPolicy.rawValue); executable=\(tool.canBeSuggestedAsExecutable); input=\(tool.schema.input); output=\(tool.schema.output)"
        }

        let skillLines = skillCatalog.installedSkills.map { skill in
            let capabilities = skill.requiredCapabilities.map(\.rawValue).joined(separator: ",")
            let actionKind = skill.action?.kind.rawValue ?? "none"
            return "- \(skill.id): \(skill.displayName); kind=\(skill.kind.rawValue); action=\(actionKind); requiresConfirmation=\(skill.action?.requiresConfirmation == true); capabilities=\(capabilities); \(skill.summary)"
        }

        let unsupportedLines = [
            "- unsupportedSandboxAction: Explain why the requested iOS, account, background, or cross-app operation is unavailable and provide a safe alternative. This is explanatory only and must not execute external actions."
        ]

        let integrationLines = integrationRegistry.integrations.map { integration in
            let surfaces = integration.surfaces.map(\.rawValue).joined(separator: ",")
            let scopes = integration.oauth?.defaultScopes.joined(separator: ",") ?? "none"
            return "- \(integration.key): \(integration.displayName); surfaces=\(surfaces); status=\(integration.status.rawValue); oauthScopes=\(scopes); \(integration.sandboxNotes)"
        }

        let appIntegrationLines = appIntegrationSkillCatalog.skills.map { skill in
            let surfaces = skill.supportedSurfaces.map(\.rawValue).joined(separator: ",")
            let capabilities = skill.audit.capabilityKeys.map(\.rawValue).joined(separator: ",")
            let scopes = skill.oauth?.requiredScopes.joined(separator: ",") ?? "none"
            return "- \(skill.id.rawValue): \(skill.appName); integrationKey=\(skill.integrationKey); surfaces=\(surfaces); capability=\(capabilities); permission=\(skill.permissionRequirement.rawValue); risk=\(skill.riskTier.rawValue); availability=\(skill.availabilityStatus.rawValue); setup=\(skill.setupRequirement.rawValue); execution=\(skill.executionMode.rawValue); confirmation=\(skill.confirmationPolicy.rawValue); executable=\(skill.canBeSuggestedAsExecutable); oauthScopes=\(scopes); input=\(skill.schema.input); output=\(skill.schema.output)"
        }

        let backgroundLines = backgroundTaskPolicy.tasks.map { descriptor in
            "- \(descriptor.identifier): kind=\(descriptor.kind.rawValue); minInterval=\(Int(descriptor.minimumInterval))s; maxRuntime=\(Int(descriptor.maxRuntime))s; network=\(descriptor.requiresNetwork); \(descriptor.sandboxNotes)"
        }

        return """
        Kairo tool/capability context:

        Capabilities available through iOS public APIs, user consent, app sandbox, App Intents, Shortcuts, Share Extension, or official APIs:
        \(capabilityLines.joined(separator: "\n"))

        Built-in phone tool catalog the model may propose. Proposed executable actions must map to these tool definitions and action kinds:
        \(actionLines.joined(separator: "\n"))

        Installed skills/tools the model may use. Treat these as named, managed tool packages layered on top of the action catalog:
        \(skillLines.isEmpty ? "- None" : skillLines.joined(separator: "\n"))

        If the user asks for an unavailable or unsafe capability, propose unsupportedSandboxAction with a clear reason and safe alternative. Do not claim completion for unsupported actions:
        \(unsupportedLines.isEmpty ? "- None" : unsupportedLines.joined(separator: "\n"))

        Integration registry. Use these as metadata for user-visible handoff, Shortcuts/App Intents, Share Extension, or official OAuth APIs; never claim private cross-app access:
        \(integrationLines.joined(separator: "\n"))

        App integration skill catalog. Prefer these typed third-party app integration skills for Chat candidates; unavailable, disabled, setup-required, or OAuth-unconnected skills are not executable:
        \(appIntegrationLines.joined(separator: "\n"))

        Background task policy. Only propose bounded BGTaskScheduler-compatible work; never promise continuous background execution or exact launch timing:
        \(backgroundLines.joined(separator: "\n"))

        Confirmation rules:
        - tier0ReadOnly may be answered directly.
        - tier1Draft, tier2LowRiskWrite, and tier3HighRiskExternal require visible user confirmation before execution.
        - External API/account actions require OAuth connector support and user-granted scopes.
        - URL schemes and universal links are user-visible handoffs, not hidden app control.
        - Web search handoff only opens a visible HTTPS search URL; Kairo cannot silently browse, scrape pages, or read Safari history/cookies.
        - HomeKit action metadata is preview/demo/test scaffolding in this beta; do not claim live HomeKit control without entitlement, permission copy, and real-device evidence.
        - BGTaskScheduler work is opportunistic and bounded; Kairo cannot run as a daemon.
        - Local model fallback cannot use tools, browse the web, or perform account actions.
        """
    }

    public static func attachmentContext(_ attachments: [ChatAttachment]) -> String {
        guard !attachments.isEmpty else {
            return "No attachments were supplied."
        }
        return "Attachments available to this turn:\n" + attachments.map(\.promptSummary).joined(separator: "\n")
    }
}
