import Foundation

public struct CapabilityPromptContextBuilder: Sendable {
    public var capabilityRegistry: CapabilityRegistry
    public var actionCatalog: SandboxActionCatalog
    public var integrationRegistry: IntegrationRegistry
    public var backgroundTaskPolicy: BackgroundTaskPolicy
    public var skillCatalog: AgentSkillCatalog

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        actionCatalog: SandboxActionCatalog = SandboxActionCatalog(),
        integrationRegistry: IntegrationRegistry = IntegrationRegistry(),
        backgroundTaskPolicy: BackgroundTaskPolicy = BackgroundTaskPolicy(),
        skillCatalog: AgentSkillCatalog = .default
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.actionCatalog = actionCatalog
        self.integrationRegistry = integrationRegistry
        self.backgroundTaskPolicy = backgroundTaskPolicy
        self.skillCatalog = skillCatalog
    }

    public func build() -> String {
        let capabilityLines = capabilityRegistry.capabilities.map { capability in
            "- \(capability.key.rawValue): \(capability.displayName); permission=\(capability.permission.rawValue); status=\(capability.status.rawValue); \(capability.description)"
        }

        let actionLines = actionCatalog.descriptors.map { descriptor in
            "- \(descriptor.kind.rawValue): \(descriptor.displayName); capability=\(descriptor.capability.rawValue); permission=\(descriptor.permissionRequirement.rawValue); risk=\(descriptor.riskTier.rawValue); support=\(descriptor.supportStatus.rawValue); \(descriptor.description)"
        }

        let skillLines = skillCatalog.installedSkills.map { skill in
            let capabilities = skill.requiredCapabilities.map(\.rawValue).joined(separator: ",")
            let actionKind = skill.action?.kind.rawValue ?? "none"
            return "- \(skill.id): \(skill.displayName); kind=\(skill.kind.rawValue); action=\(actionKind); requiresConfirmation=\(skill.action?.requiresConfirmation == true); capabilities=\(capabilities); \(skill.summary)"
        }

        let unsupportedLines = actionCatalog.unsupportedDescriptors.map { descriptor in
            "- \(descriptor.kind.rawValue): \(descriptor.description)"
        }

        let integrationLines = integrationRegistry.integrations.map { integration in
            let surfaces = integration.surfaces.map(\.rawValue).joined(separator: ",")
            let scopes = integration.oauth?.defaultScopes.joined(separator: ",") ?? "none"
            return "- \(integration.key): \(integration.displayName); surfaces=\(surfaces); status=\(integration.status.rawValue); oauthScopes=\(scopes); \(integration.sandboxNotes)"
        }

        let backgroundLines = backgroundTaskPolicy.tasks.map { descriptor in
            "- \(descriptor.identifier): kind=\(descriptor.kind.rawValue); minInterval=\(Int(descriptor.minimumInterval))s; maxRuntime=\(Int(descriptor.maxRuntime))s; network=\(descriptor.requiresNetwork); \(descriptor.sandboxNotes)"
        }

        return """
        Kairo tool/capability context:

        Capabilities available through iOS public APIs, user consent, app sandbox, App Intents, Shortcuts, Share Extension, or official APIs:
        \(capabilityLines.joined(separator: "\n"))

        Action catalog the model may propose. Proposed actions must use these exact action kinds and payload types:
        \(actionLines.joined(separator: "\n"))

        Installed skills/tools the model may use. Treat these as named, managed tool packages layered on top of the action catalog:
        \(skillLines.isEmpty ? "- None" : skillLines.joined(separator: "\n"))

        If the user asks for an unavailable or unsafe capability, propose unsupportedSandboxAction with a clear reason and safe alternative. Do not claim completion for unsupported actions:
        \(unsupportedLines.isEmpty ? "- None" : unsupportedLines.joined(separator: "\n"))

        Integration registry. Use these as metadata for user-visible handoff, Shortcuts/App Intents, Share Extension, or official OAuth APIs; never claim private cross-app access:
        \(integrationLines.joined(separator: "\n"))

        Background task policy. Only propose bounded BGTaskScheduler-compatible work; never promise continuous background execution or exact launch timing:
        \(backgroundLines.joined(separator: "\n"))

        Confirmation rules:
        - tier0ReadOnly may be answered directly.
        - tier1Draft, tier2LowRiskWrite, and tier3HighRiskExternal require visible user confirmation before execution.
        - External API/account actions require OAuth connector support and user-granted scopes.
        - URL schemes and universal links are user-visible handoffs, not hidden app control.
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
