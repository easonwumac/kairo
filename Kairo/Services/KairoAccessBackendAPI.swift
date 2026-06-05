import Foundation

public protocol KairoAccessAPI: Sendable {
    func capabilities() async -> [Capability]
    func tools() async -> [KairoAccessToolSummary]
    func status(for capability: CapabilityKey) async -> CapabilityStatus
    func request(_ capability: CapabilityKey) async throws -> CapabilityStatus
}

public enum KairoAccessToolReadiness: String, Codable, Sendable {
    case available
    case needsPermission
    case needsSetup
    case scaffolded
    case unavailable
}

public struct KairoAccessToolSummary: Identifiable, Codable, Equatable, Sendable {
    public var id: BuiltInPhoneToolID { toolID }
    public var toolID: BuiltInPhoneToolID
    public var displayName: String
    public var category: BuiltInPhoneToolCategory
    public var permissionRequirement: PermissionRequirement
    public var availabilityStatus: BuiltInPhoneToolAvailabilityStatus
    public var riskTier: ActionRiskTier
    public var confirmationPolicy: BuiltInPhoneToolConfirmationPolicy
    public var executionKind: BuiltInPhoneToolExecutionKind
    public var readiness: KairoAccessToolReadiness
    public var capabilityStatuses: [CapabilityKey: CapabilityStatus]
    public var requiresConfirmation: Bool
    public var canBeSuggestedAsExecutable: Bool
    public var fallback: BuiltInPhoneToolFallback

    public init(
        definition: BuiltInPhoneToolDefinition,
        capabilityStatuses: [CapabilityKey: CapabilityStatus]
    ) {
        self.toolID = definition.id
        self.displayName = definition.displayName
        self.category = definition.category
        self.permissionRequirement = definition.permissionRequirement
        self.availabilityStatus = definition.availabilityStatus
        self.riskTier = definition.riskTier
        self.confirmationPolicy = definition.confirmationPolicy
        self.executionKind = definition.executionKind
        self.readiness = Self.readiness(for: definition, capabilityStatuses: capabilityStatuses)
        self.capabilityStatuses = capabilityStatuses
        self.requiresConfirmation = definition.requiresConfirmation
        self.canBeSuggestedAsExecutable = definition.canBeSuggestedAsExecutable && readiness != .unavailable
        self.fallback = definition.fallback
    }

    private static func readiness(
        for definition: BuiltInPhoneToolDefinition,
        capabilityStatuses: [CapabilityKey: CapabilityStatus]
    ) -> KairoAccessToolReadiness {
        if definition.availabilityStatus == .unsupported {
            return .unavailable
        }
        if capabilityStatuses.values.contains(where: { status in
            status == .denied || status == .restricted || status == .unsupported
        }) {
            return .unavailable
        }
        switch definition.availabilityStatus {
        case .available:
            return .available
        case .permissionRequired:
            return capabilityStatuses.values.contains(.unknown) ? .needsPermission : .available
        case .setupRequired:
            return .needsSetup
        case .scaffolded:
            return .scaffolded
        case .unsupported:
            return .unavailable
        }
    }
}

public struct KairoAccessBackendService: KairoAccessAPI {
    private let capabilityRegistry: CapabilityRegistry
    private let permissionService: any PermissionService
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding

    public init(
        capabilityRegistry: CapabilityRegistry = CapabilityRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        permissionService: any PermissionService
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.toolCatalog = toolCatalog
        self.permissionService = permissionService
    }

    public func capabilities() async -> [Capability] {
        var resolvedCapabilities: [Capability] = []
        resolvedCapabilities.reserveCapacity(capabilityRegistry.capabilities.count)
        for var capability in capabilityRegistry.capabilities {
            capability.status = await permissionService.status(for: capability.key)
            resolvedCapabilities.append(capability)
        }
        return resolvedCapabilities
    }

    public func tools() async -> [KairoAccessToolSummary] {
        var summaries: [KairoAccessToolSummary] = []
        summaries.reserveCapacity(toolCatalog.tools.count)

        for definition in toolCatalog.tools {
            var capabilityStatuses: [CapabilityKey: CapabilityStatus] = [:]
            for capabilityKey in definition.audit.capabilityKeys {
                capabilityStatuses[capabilityKey] = await permissionService.status(for: capabilityKey)
            }
            summaries.append(
                KairoAccessToolSummary(
                    definition: definition,
                    capabilityStatuses: capabilityStatuses
                )
            )
        }

        return summaries
    }

    public func status(for capability: CapabilityKey) async -> CapabilityStatus {
        await permissionService.status(for: capability)
    }

    public func request(_ capability: CapabilityKey) async throws -> CapabilityStatus {
        try await permissionService.request(capability)
    }
}
