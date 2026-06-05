import Foundation

public struct BuiltInPhoneToolActionDescriptorProvider: AgentActionDescriptorProviding {
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding
    private let fallbackCatalog: any AgentActionDescriptorProviding

    public init(
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        fallbackCatalog: any AgentActionDescriptorProviding = SandboxActionCatalog()
    ) {
        self.toolCatalog = toolCatalog
        self.fallbackCatalog = fallbackCatalog
    }

    public func descriptor(for kind: AgentActionKind) -> SandboxActionDescriptor? {
        guard let tool = toolCatalog.tool(for: kind) else {
            return fallbackCatalog.descriptor(for: kind)
        }
        return SandboxActionDescriptor(
            kind: kind,
            displayName: tool.displayName,
            description: tool.fallback.safeAlternative,
            capability: tool.audit.capabilityKeys.first ?? .appIntents,
            permissionRequirement: tool.permissionRequirement,
            riskTier: tool.riskTier,
            supportStatus: supportStatus(for: tool)
        )
    }

    private func supportStatus(for tool: BuiltInPhoneToolDefinition) -> SandboxActionSupportStatus {
        switch tool.availabilityStatus {
        case .unsupported:
            return .unsupportedBySandbox
        case .setupRequired:
            return .requiresIntegration
        case .scaffolded:
            return .scaffolded
        case .available, .permissionRequired:
            return tool.executionKind == .setupStatusOnly ? .requiresIntegration : .implemented
        }
    }
}
