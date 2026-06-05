import Foundation

public protocol KairoAccessAPI: Sendable {
    func capabilities() async -> [Capability]
    func tools() async -> [KairoAccessToolSummary]
    func appIntegrations() async -> [KairoAccessIntegrationSummary]
    func status(for capability: CapabilityKey) async -> CapabilityStatus
    func request(_ capability: CapabilityKey) async throws -> CapabilityStatus
}

public enum KairoAccessToolReadiness: String, Codable, Sendable {
    case available
    case needsPermission
    case needsSetup
    case scaffolded
    case unavailable

    public var displayName: String {
        switch self {
        case .available:
            return KairoL10n.string("access.tool.readiness.available")
        case .needsPermission:
            return KairoL10n.string("access.tool.readiness.needsPermission")
        case .needsSetup:
            return KairoL10n.string("access.tool.readiness.needsSetup")
        case .scaffolded:
            return KairoL10n.string("access.tool.readiness.scaffolded")
        case .unavailable:
            return KairoL10n.string("access.tool.readiness.unavailable")
        }
    }
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

public enum KairoAccessIntegrationReadiness: String, Codable, CaseIterable, Sendable {
    case available
    case needsPermission
    case needsInstalledApp
    case needsUserShortcut
    case needsOAuth
    case previewOnly
    case unsupported
    case disabled

    public var displayName: String {
        switch self {
        case .available:
            return KairoL10n.string("access.integration.readiness.available")
        case .needsPermission:
            return KairoL10n.string("access.integration.readiness.needsPermission")
        case .needsInstalledApp:
            return KairoL10n.string("access.integration.readiness.needsInstalledApp")
        case .needsUserShortcut:
            return KairoL10n.string("access.integration.readiness.needsUserShortcut")
        case .needsOAuth:
            return KairoL10n.string("access.integration.readiness.needsOAuth")
        case .previewOnly:
            return KairoL10n.string("access.integration.readiness.previewOnly")
        case .unsupported:
            return KairoL10n.string("access.integration.readiness.unsupported")
        case .disabled:
            return KairoL10n.string("access.integration.readiness.disabled")
        }
    }
}

public struct KairoAccessIntegrationSummary: Identifiable, Codable, Equatable, Sendable {
    public var id: AppIntegrationSkillID { skillID }
    public var skillID: AppIntegrationSkillID
    public var appName: String
    public var bundleID: String?
    public var integrationKey: String
    public var category: AppIntegrationSkillCategory
    public var supportedSurfaces: [AppIntegrationSkillSurface]
    public var setupRequirement: AppIntegrationSkillSetupRequirement
    public var installedAppRequirement: AppIntegrationInstalledAppRequirement
    public var permissionRequirement: PermissionRequirement
    public var availabilityStatus: AppIntegrationSkillAvailabilityStatus
    public var riskTier: ActionRiskTier
    public var confirmationPolicy: BuiltInPhoneToolConfirmationPolicy
    public var executionMode: AppIntegrationExecutionMode
    public var examplePromptKey: String
    public var readiness: KairoAccessIntegrationReadiness
    public var capabilityStatuses: [CapabilityKey: CapabilityStatus]
    public var requiresConfirmation: Bool
    public var canBeSuggestedAsExecutable: Bool
    public var fallback: AppIntegrationFallback

    public init(
        skill: AppIntegrationSkill,
        capabilityStatuses: [CapabilityKey: CapabilityStatus]
    ) {
        self.skillID = skill.id
        self.appName = skill.appName
        self.bundleID = skill.bundleID
        self.integrationKey = skill.integrationKey
        self.category = skill.category
        self.supportedSurfaces = skill.supportedSurfaces
        self.setupRequirement = skill.setupRequirement
        self.installedAppRequirement = skill.installedAppRequirement
        self.permissionRequirement = skill.permissionRequirement
        self.availabilityStatus = skill.availabilityStatus
        self.riskTier = skill.riskTier
        self.confirmationPolicy = skill.confirmationPolicy
        self.executionMode = skill.executionMode
        self.examplePromptKey = skill.examplePromptKey
        self.readiness = Self.readiness(for: skill, capabilityStatuses: capabilityStatuses)
        self.capabilityStatuses = capabilityStatuses
        self.requiresConfirmation = skill.requiresConfirmation
        self.canBeSuggestedAsExecutable = skill.canBeSuggestedAsExecutable && readiness == .available
        self.fallback = skill.fallback
    }

    private static func readiness(
        for skill: AppIntegrationSkill,
        capabilityStatuses: [CapabilityKey: CapabilityStatus]
    ) -> KairoAccessIntegrationReadiness {
        if skill.availabilityStatus == .disabled {
            return .disabled
        }
        if skill.availabilityStatus == .unsupported || skill.setupRequirement == .unsupported {
            return .unsupported
        }
        if capabilityStatuses.values.contains(where: { status in
            status == .denied || status == .restricted || status == .unsupported
        }) {
            return .unsupported
        }
        switch skill.availabilityStatus {
        case .available:
            return capabilityStatuses.values.contains(.unknown) ? .needsPermission : .available
        case .requiresInstalledApp:
            return .needsInstalledApp
        case .requiresUserShortcut:
            return .needsUserShortcut
        case .requiresOAuth:
            return .needsOAuth
        case .previewOnly:
            return .previewOnly
        case .unsupported:
            return .unsupported
        case .disabled:
            return .disabled
        }
    }
}

public struct KairoAccessBackendService: KairoAccessAPI {
    private let capabilityRegistry: any CapabilityRegistryProviding
    private let permissionService: any PermissionService
    private let toolCatalog: any BuiltInPhoneToolCatalogProviding
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(
        capabilityRegistry: any CapabilityRegistryProviding = CapabilityRegistry(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        permissionService: any PermissionService
    ) {
        self.capabilityRegistry = capabilityRegistry
        self.toolCatalog = toolCatalog
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
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

    public func appIntegrations() async -> [KairoAccessIntegrationSummary] {
        var summaries: [KairoAccessIntegrationSummary] = []
        summaries.reserveCapacity(appIntegrationSkillCatalog.skills.count)

        for skill in appIntegrationSkillCatalog.skills {
            var capabilityStatuses: [CapabilityKey: CapabilityStatus] = [:]
            for capabilityKey in skill.audit.capabilityKeys {
                capabilityStatuses[capabilityKey] = await permissionService.status(for: capabilityKey)
            }
            summaries.append(
                KairoAccessIntegrationSummary(
                    skill: skill,
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
