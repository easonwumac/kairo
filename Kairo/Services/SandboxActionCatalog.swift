import Foundation

public struct SandboxActionDescriptor: Identifiable, Codable, Equatable, Sendable {
    public var id: String { kind.rawValue }
    public var kind: AgentActionKind
    public var displayName: String
    public var description: String
    public var capability: CapabilityKey
    public var permissionRequirement: PermissionRequirement
    public var riskTier: ActionRiskTier
    public var supportStatus: SandboxActionSupportStatus

    public init(
        kind: AgentActionKind,
        displayName: String,
        description: String,
        capability: CapabilityKey,
        permissionRequirement: PermissionRequirement,
        riskTier: ActionRiskTier,
        supportStatus: SandboxActionSupportStatus
    ) {
        self.kind = kind
        self.displayName = displayName
        self.description = description
        self.capability = capability
        self.permissionRequirement = permissionRequirement
        self.riskTier = riskTier
        self.supportStatus = supportStatus
    }
}

public enum SandboxActionSupportStatus: String, Codable, Equatable, Sendable {
    case implemented
    case scaffolded
    case requiresIntegration
    case unsupportedBySandbox

    public var isExecutableInSandbox: Bool {
        switch self {
        case .implemented, .scaffolded:
            return true
        case .requiresIntegration, .unsupportedBySandbox:
            return false
        }
    }

    public var displayName: String {
        switch self {
        case .implemented:
            return KairoL10n.string("chat.action.support.implemented")
        case .scaffolded:
            return KairoL10n.string("chat.action.support.needsConfirmation")
        case .requiresIntegration:
            return KairoL10n.string("chat.action.support.plannedIntegration")
        case .unsupportedBySandbox:
            return KairoL10n.string("chat.action.support.unavailableInSandbox")
        }
    }
}

public struct SandboxActionCatalog: Sendable {
    public var descriptors: [SandboxActionDescriptor]

    public init(descriptors: [SandboxActionDescriptor] = SandboxActionCatalog.defaultDescriptors) {
        self.descriptors = descriptors
    }

    public func descriptor(for kind: AgentActionKind) -> SandboxActionDescriptor? {
        descriptors.first { $0.kind == kind }
    }

    public var supportedDescriptors: [SandboxActionDescriptor] {
        descriptors.filter { $0.supportStatus.isExecutableInSandbox }
    }

    public var unsupportedDescriptors: [SandboxActionDescriptor] {
        descriptors.filter { !$0.supportStatus.isExecutableInSandbox }
    }

    public func descriptors(for capability: CapabilityKey) -> [SandboxActionDescriptor] {
        descriptors.filter { $0.capability == capability }
    }

    public static let defaultDescriptors: [SandboxActionDescriptor] = [
        SandboxActionDescriptor(
            kind: .answer,
            displayName: KairoL10n.string("chat.action.displayName.answer"),
            description: KairoL10n.string("chat.action.description.answer"),
            capability: .chat,
            permissionRequirement: .none,
            riskTier: .tier0ReadOnly,
            supportStatus: .implemented
        ),
        SandboxActionDescriptor(
            kind: .saveMemory,
            displayName: KairoL10n.string("chat.action.displayName.saveMemory"),
            description: KairoL10n.string("chat.action.description.saveMemory"),
            capability: .memory,
            permissionRequirement: .none,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .implemented
        ),
        SandboxActionDescriptor(
            kind: .createReminderDraft,
            displayName: KairoL10n.string("chat.action.displayName.createReminder"),
            description: KairoL10n.string("chat.action.description.createReminder"),
            capability: .reminders,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .createCalendarDraft,
            displayName: KairoL10n.string("chat.action.displayName.createCalendar"),
            description: KairoL10n.string("chat.action.description.createCalendar"),
            capability: .calendar,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .createContactDraft,
            displayName: KairoL10n.string("chat.action.displayName.createContact"),
            description: KairoL10n.string("chat.action.description.createContact"),
            capability: .contacts,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .composeEmailDraft,
            displayName: KairoL10n.string("chat.action.displayName.composeEmail"),
            description: KairoL10n.string("chat.action.description.composeEmail"),
            capability: .mail,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openMapDirections,
            displayName: KairoL10n.string("chat.action.displayName.openMaps"),
            description: KairoL10n.string("chat.action.description.openMaps"),
            capability: .location,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openMessageHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openMessages"),
            description: KairoL10n.string("chat.action.description.openMessages"),
            capability: .messages,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openPhoneCallHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openPhone"),
            description: KairoL10n.string("chat.action.description.openPhone"),
            capability: .phone,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openWebSearchHandoff,
            displayName: KairoL10n.string("chat.action.displayName.openWeb"),
            description: KairoL10n.string("chat.action.description.openWeb"),
            capability: .web,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .sendNotification,
            displayName: KairoL10n.string("chat.action.displayName.sendNotification"),
            description: KairoL10n.string("chat.action.description.sendNotification"),
            capability: .notifications,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openURL,
            displayName: KairoL10n.string("chat.action.displayName.openURL"),
            description: KairoL10n.string("chat.action.description.openURL"),
            capability: .documents,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .controlHome,
            displayName: KairoL10n.string("chat.action.displayName.controlHome"),
            description: KairoL10n.string("chat.action.description.controlHome"),
            capability: .homeKit,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier3HighRiskExternal,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .externalAPIRequest,
            displayName: KairoL10n.string("chat.action.displayName.externalAPI"),
            description: KairoL10n.string("chat.action.description.externalAPI"),
            capability: .externalConnectors,
            permissionRequirement: .oauth,
            riskTier: .tier3HighRiskExternal,
            supportStatus: .requiresIntegration
        ),
        SandboxActionDescriptor(
            kind: .unsupportedSandboxAction,
            displayName: KairoL10n.string("chat.action.displayName.unsupported"),
            description: KairoL10n.string("chat.action.description.unsupported"),
            capability: .appIntents,
            permissionRequirement: .unsupported,
            riskTier: .tier3HighRiskExternal,
            supportStatus: .unsupportedBySandbox
        )
    ]
}
