import Foundation

public enum KairoBackendModuleID: String, CaseIterable, Sendable {
    case chat
    case memory
    case recipes
    case shareImports
    case deletion
    case localModels
    case skills
    case settings
    case access
}

public struct KairoBackendModuleDescriptor: Equatable, Sendable {
    public let id: KairoBackendModuleID
    public let displayName: String

    public init(id: KairoBackendModuleID, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

public struct KairoBackendModuleRegistry: Equatable, Sendable {
    public let modules: [KairoBackendModuleDescriptor]

    public init(modules: [KairoBackendModuleDescriptor]) {
        self.modules = modules
    }

    public static let production = KairoBackendModuleRegistry(
        modules: KairoBackendModuleID.allCases.map { id in
            KairoBackendModuleDescriptor(id: id, displayName: id.productionDisplayName)
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
}
