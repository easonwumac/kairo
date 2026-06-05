import Foundation

public protocol BuiltInPhoneToolCatalogProviding: Sendable {
    var tools: [BuiltInPhoneToolDefinition] { get }
}

public extension BuiltInPhoneToolCatalogProviding {
    func tool(for actionKind: AgentActionKind) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.sourceBinding.agentActionKinds.contains(actionKind) }
    }

    func tool(for shortcutNodeKind: ShortcutNodeKind) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.sourceBinding.shortcutNodeKinds.contains(shortcutNodeKind) }
    }

    func tool(for recipeStepKind: KairoRecipeStepKind) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.sourceBinding.recipeStepKinds.contains(recipeStepKind) }
    }
}

public enum BuiltInPhoneToolID: String, Codable, CaseIterable, Sendable, Identifiable {
    case memorySave = "memory.save"
    case memorySearch = "memory.search"
    case memoryDelete = "memory.delete"
    case memoryExport = "memory.export"
    case shareImport = "share.import"
    case reminderWrite = "reminder.write"
    case calendarWrite = "calendar.write"
    case notificationSchedule = "notification.schedule"
    case contactCreate = "contact.create"
    case emailHandoff = "email.handoff"
    case messageHandoff = "message.handoff"
    case phoneHandoff = "phone.handoff"
    case webSearchHandoff = "web.search.handoff"
    case mapsDirectionsHandoff = "maps.directions.handoff"
    case recipeRun = "recipe.run"
    case shortcutNodeInvocation = "shortcut.node.invoke"
    case oauthConnectorSetupStatus = "oauth.connector.setupStatus"
    case localModelManage = "localModel.manage"
    case homeKitPreview = "homeKit.preview"

    public var id: String { rawValue }
}

public enum BuiltInPhoneToolCategory: String, Codable, CaseIterable, Sendable {
    case memory
    case share
    case reminders
    case calendar
    case notifications
    case contacts
    case handoff
    case recipe
    case shortcuts
    case integrations
    case localModels
    case home
}

public enum BuiltInPhoneToolAvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available
    case permissionRequired
    case setupRequired
    case scaffolded
    case unsupported

    public var allowsExecutableSuggestion: Bool {
        switch self {
        case .available, .permissionRequired, .setupRequired, .scaffolded:
            return true
        case .unsupported:
            return false
        }
    }
}

public enum BuiltInPhoneToolConfirmationPolicy: String, Codable, CaseIterable, Sendable {
    case notRequired
    case previewRequired
    case previewAndExplicitConfirmation
    case manualSetupOnly

    public var allowsExecutionWithoutConfirmation: Bool {
        self == .notRequired
    }
}

public enum BuiltInPhoneToolExecutionKind: String, Codable, CaseIterable, Sendable {
    case readOnly
    case draftOnly
    case confirmedWrite
    case visibleHandoff
    case setupStatusOnly
    case scaffoldPreviewOnly
}

public struct BuiltInPhoneToolSchema: Codable, Equatable, Sendable {
    public var input: String
    public var output: String

    public init(input: String, output: String) {
        self.input = input
        self.output = output
    }
}

public struct BuiltInPhoneToolLifecycleBinding: Codable, Equatable, Sendable {
    public var previewRenderer: String
    public var executor: String

    public init(previewRenderer: String, executor: String) {
        self.previewRenderer = previewRenderer
        self.executor = executor
    }
}

public struct BuiltInPhoneToolAuditMetadata: Codable, Equatable, Sendable {
    public var capabilityKeys: [CapabilityKey]
    public var sensitivePayloadPolicy: String

    public init(capabilityKeys: [CapabilityKey], sensitivePayloadPolicy: String = "redactedPayloadOnly") {
        self.capabilityKeys = capabilityKeys
        self.sensitivePayloadPolicy = sensitivePayloadPolicy
    }
}

public struct BuiltInPhoneToolFallback: Codable, Equatable, Sendable {
    public var unsupportedReason: String
    public var safeAlternative: String

    public init(unsupportedReason: String, safeAlternative: String) {
        self.unsupportedReason = unsupportedReason
        self.safeAlternative = safeAlternative
    }
}

public struct BuiltInPhoneToolSourceBinding: Codable, Equatable, Sendable {
    public var agentActionKinds: [AgentActionKind]
    public var shortcutNodeKinds: [ShortcutNodeKind]
    public var recipeStepKinds: [KairoRecipeStepKind]
    public var skillKinds: [AgentSkillKind]

    public init(
        agentActionKinds: [AgentActionKind] = [],
        shortcutNodeKinds: [ShortcutNodeKind] = [],
        recipeStepKinds: [KairoRecipeStepKind] = [],
        skillKinds: [AgentSkillKind] = []
    ) {
        self.agentActionKinds = agentActionKinds
        self.shortcutNodeKinds = shortcutNodeKinds
        self.recipeStepKinds = recipeStepKinds
        self.skillKinds = skillKinds
    }
}

public struct BuiltInPhoneToolDefinition: Identifiable, Codable, Equatable, Sendable {
    public var id: BuiltInPhoneToolID
    public var displayName: String
    public var category: BuiltInPhoneToolCategory
    public var schema: BuiltInPhoneToolSchema
    public var permissionRequirement: PermissionRequirement
    public var availabilityStatus: BuiltInPhoneToolAvailabilityStatus
    public var riskTier: ActionRiskTier
    public var confirmationPolicy: BuiltInPhoneToolConfirmationPolicy
    public var executionKind: BuiltInPhoneToolExecutionKind
    public var lifecycle: BuiltInPhoneToolLifecycleBinding
    public var audit: BuiltInPhoneToolAuditMetadata
    public var fallback: BuiltInPhoneToolFallback
    public var sourceBinding: BuiltInPhoneToolSourceBinding

    public init(
        id: BuiltInPhoneToolID,
        displayName: String,
        category: BuiltInPhoneToolCategory,
        schema: BuiltInPhoneToolSchema,
        permissionRequirement: PermissionRequirement,
        availabilityStatus: BuiltInPhoneToolAvailabilityStatus,
        riskTier: ActionRiskTier,
        confirmationPolicy: BuiltInPhoneToolConfirmationPolicy,
        executionKind: BuiltInPhoneToolExecutionKind,
        lifecycle: BuiltInPhoneToolLifecycleBinding,
        audit: BuiltInPhoneToolAuditMetadata,
        fallback: BuiltInPhoneToolFallback,
        sourceBinding: BuiltInPhoneToolSourceBinding = BuiltInPhoneToolSourceBinding()
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.schema = schema
        self.permissionRequirement = permissionRequirement
        self.availabilityStatus = availabilityStatus
        self.riskTier = riskTier
        self.confirmationPolicy = confirmationPolicy
        self.executionKind = executionKind
        self.lifecycle = lifecycle
        self.audit = audit
        self.fallback = fallback
        self.sourceBinding = sourceBinding
    }

    public var requiresConfirmation: Bool {
        riskTier.requiresConfirmation || !confirmationPolicy.allowsExecutionWithoutConfirmation
    }

    public var canBeSuggestedAsExecutable: Bool {
        availabilityStatus.allowsExecutableSuggestion && executionKind != .setupStatusOnly
    }
}

public protocol BuiltInPhoneToolSeeding: Sendable {
    var tools: [BuiltInPhoneToolDefinition] { get }
}

public struct BuiltInPhoneToolCatalog: BuiltInPhoneToolCatalogProviding {
    public var tools: [BuiltInPhoneToolDefinition]

    public init(seedSource: any BuiltInPhoneToolSeeding = DefaultBuiltInPhoneToolSeedFactory()) {
        self.tools = seedSource.tools
    }

    public init(tools: [BuiltInPhoneToolDefinition]) {
        self.tools = tools
    }

    public func tool(id: BuiltInPhoneToolID) -> BuiltInPhoneToolDefinition? {
        tools.first { $0.id == id }
    }

    public var executableSuggestionTools: [BuiltInPhoneToolDefinition] {
        tools.filter(\.canBeSuggestedAsExecutable)
    }

    public static let defaultTools: [BuiltInPhoneToolDefinition] = DefaultBuiltInPhoneToolSeedFactory.defaultTools
}
