import Foundation

public enum KairoBackendModuleID: String, CaseIterable, Sendable {
    case chat
    case memory
    case recipes
    case shareImports
    case actionInbox
    case actions
    case deletion
    case localModels
    case skills
    case settings
    case access
}

public struct KairoBackendModuleDescriptor: Equatable, Sendable {
    public let id: KairoBackendModuleID
    public let displayName: String
    public let boundarySummary: String

    public init(id: KairoBackendModuleID, displayName: String, boundarySummary: String) {
        self.id = id
        self.displayName = displayName
        self.boundarySummary = boundarySummary
    }
}

public struct KairoBackendModuleRegistry: Equatable, Sendable {
    public let modules: [KairoBackendModuleDescriptor]

    public init(modules: [KairoBackendModuleDescriptor]) {
        self.modules = modules
    }

    public static let production = KairoBackendModuleRegistry(
        modules: KairoBackendModuleID.allCases.map { id in
            KairoBackendModuleDescriptor(
                id: id,
                displayName: id.productionDisplayName,
                boundarySummary: id.productionBoundarySummary
            )
        }
    )
}

private extension KairoBackendModuleID {
    var productionDisplayName: String {
        switch self {
        case .chat:
            return "Chat"
        case .memory:
            return "Memory"
        case .recipes:
            return "Internal Recipes"
        case .shareImports:
            return "Share Imports"
        case .actionInbox:
            return "Action Inbox"
        case .actions:
            return "Actions"
        case .deletion:
            return "Data Deletion"
        case .localModels:
            return "Local Models"
        case .skills:
            return "Skill Manager"
        case .settings:
            return "Settings"
        case .access:
            return "Access"
        }
    }

    var productionBoundarySummary: String {
        switch self {
        case .chat:
            return "Agent response orchestration, privacy routing, memory context, and tool/action preview candidates."
        case .memory:
            return "Memory list, search, save, delete, export, and purge lifecycle."
        case .recipes:
            return "Kairo-owned internal recipe lifecycle and dry-run execution without Apple Shortcut mutation."
        case .shareImports:
            return "Share Extension queue import and imported-state updates without extension-side actions."
        case .actionInbox:
            return "Pending captured content, summaries, and action drafts before any confirmed write."
        case .actions:
            return "Action preview, safety decision, and explicit user-confirmed execution."
        case .deletion:
            return "User-triggered deletion for chat, memory, credentials, OAuth tokens, local models, and audit metadata."
        case .localModels:
            return "Local model catalog status, explicit download state, selection, preference, deletion, and stale cleanup."
        case .skills:
            return "Skill catalog, effective tool catalog, manifest preview/install, enable/disable/remove, and user drafts."
        case .settings:
            return "OpenAI key and OAuth connector status, authorization sessions, callbacks, dry-runs, and disconnect."
        case .access:
            return "Capability permission status reads and explicit permission requests through system services."
        }
    }
}
