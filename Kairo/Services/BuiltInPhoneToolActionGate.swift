import Foundation

public struct BuiltInPhoneToolActionGate: Sendable {
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding

    public init(toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()) {
        self.toolCatalog = toolCatalog
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
        guard let tool = toolCatalog.tool(for: shortcutNodeKind) else {
            return nil
        }
        return tool.canBeSuggestedAsExecutable ? nil : tool
    }

    public func blockedTool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition? {
        guard let tool = toolCatalog.tool(for: recipeStepKind) else {
            return nil
        }
        return tool.canBeSuggestedAsExecutable ? nil : tool
    }
}
