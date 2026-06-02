import Foundation

public struct CapabilityPromptContextBuilder: Sendable {
    public var capabilityRegistry: CapabilityRegistry
    public var actionCatalog: SandboxActionCatalog

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        actionCatalog: SandboxActionCatalog = SandboxActionCatalog()
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.actionCatalog = actionCatalog
    }

    public func build() -> String {
        let capabilityLines = capabilityRegistry.capabilities.map { capability in
            "- \(capability.key.rawValue): \(capability.displayName); permission=\(capability.permission.rawValue); status=\(capability.status.rawValue); \(capability.description)"
        }

        let actionLines = actionCatalog.descriptors.map { descriptor in
            "- \(descriptor.kind.rawValue): \(descriptor.displayName); capability=\(descriptor.capability.rawValue); permission=\(descriptor.permissionRequirement.rawValue); risk=\(descriptor.riskTier.rawValue); support=\(descriptor.supportStatus.rawValue); \(descriptor.description)"
        }

        let unsupportedLines = actionCatalog.unsupportedDescriptors.map { descriptor in
            "- \(descriptor.kind.rawValue): \(descriptor.description)"
        }

        return """
        Kairo tool/capability context:

        Capabilities available through iOS public APIs, user consent, app sandbox, App Intents, Shortcuts, Share Extension, or official APIs:
        \(capabilityLines.joined(separator: "\n"))

        Action catalog the model may propose. Proposed actions must use these exact action kinds and payload types:
        \(actionLines.joined(separator: "\n"))

        If the user asks for an unavailable or unsafe capability, propose unsupportedSandboxAction with a clear reason and safe alternative. Do not claim completion for unsupported actions:
        \(unsupportedLines.isEmpty ? "- None" : unsupportedLines.joined(separator: "\n"))

        Confirmation rules:
        - tier0ReadOnly may be answered directly.
        - tier1Draft, tier2LowRiskWrite, and tier3HighRiskExternal require visible user confirmation before execution.
        - External API/account actions require OAuth connector support and user-granted scopes.
        - Local model fallback cannot use tools, browse the web, or perform account actions.
        """
    }
}
