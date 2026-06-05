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
}
