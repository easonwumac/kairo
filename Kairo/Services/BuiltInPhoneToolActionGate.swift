import Foundation

public protocol PhoneToolActionGating: Sendable {
    func allowsExecutablePreview(_ action: AgentAction) -> Bool
    func filterExecutablePreviews(_ actions: [AgentAction]) -> [AgentAction]
    func blockedTool(for shortcutNodeKind: ShortcutNodeKind) -> BuiltInPhoneToolDefinition?
    func blockedTool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition?
}

public struct BuiltInPhoneToolActionGate: PhoneToolActionGating {
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding
    private let referenceCatalog: any BuiltInPhoneToolCatalogProviding

    public init(
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        referenceCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) {
        self.toolCatalog = toolCatalog
        self.referenceCatalog = referenceCatalog
    }

    public func allowsExecutablePreview(_ action: AgentAction) -> Bool {
        if action.kind == .unsupportedSandboxAction {
            return true
        }
        guard let tool = toolCatalog.tool(for: action.kind) else {
            return false
        }
        return tool.canBeSuggestedAsExecutable
    }

    public func filterExecutablePreviews(_ actions: [AgentAction]) -> [AgentAction] {
        actions.filter(allowsExecutablePreview)
    }

    public func blockedTool(for shortcutNodeKind: ShortcutNodeKind) -> BuiltInPhoneToolDefinition? {
        if let tool = toolCatalog.tool(for: shortcutNodeKind) {
            return tool.canBeSuggestedAsExecutable ? nil : tool
        }
        guard let referenceTool = referenceCatalog.tool(for: shortcutNodeKind),
              shouldFailClosedWhenMissing(referenceTool) else {
            return nil
        }
        return missingCatalogTool(referenceTool)
    }

    public func blockedTool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition? {
        if let tool = toolCatalog.tool(for: recipeStepKind) {
            return tool.canBeSuggestedAsExecutable ? nil : tool
        }
        guard let referenceTool = referenceCatalog.tool(for: recipeStepKind),
              shouldFailClosedWhenMissing(referenceTool) else {
            return nil
        }
        return missingCatalogTool(referenceTool)
    }

    private func shouldFailClosedWhenMissing(_ tool: BuiltInPhoneToolDefinition) -> Bool {
        tool.id != .recipeRun
    }

    private func missingCatalogTool(_ tool: BuiltInPhoneToolDefinition) -> BuiltInPhoneToolDefinition {
        var blockedTool = tool
        blockedTool.availabilityStatus = .unsupported
        blockedTool.fallback = BuiltInPhoneToolFallback(
            unsupportedReason: "Tool is not enabled in the active phone tool catalog.",
            safeAlternative: tool.fallback.safeAlternative
        )
        return blockedTool
    }
}
