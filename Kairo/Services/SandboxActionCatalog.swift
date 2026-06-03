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
            return "Supported"
        case .scaffolded:
            return "Needs confirmation"
        case .requiresIntegration:
            return "Planned integration"
        case .unsupportedBySandbox:
            return "Not available in sandbox"
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
            displayName: "Answer",
            description: "回答問題與整理上下文，不觸碰外部資料。",
            capability: .chat,
            permissionRequirement: .none,
            riskTier: .tier0ReadOnly,
            supportStatus: .implemented
        ),
        SandboxActionDescriptor(
            kind: .saveMemory,
            displayName: "Save Memory",
            description: "把使用者確認的內容存進 Kairo 記憶。",
            capability: .memory,
            permissionRequirement: .none,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .implemented
        ),
        SandboxActionDescriptor(
            kind: .createReminderDraft,
            displayName: "Create Reminder",
            description: "在提醒事項權限允許後建立提醒事項。",
            capability: .reminders,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .createCalendarDraft,
            displayName: "Create Calendar Event",
            description: "在行事曆權限允許後建立行事曆事件。",
            capability: .calendar,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .createContactDraft,
            displayName: "Create Contact",
            description: "在聯絡人權限允許後建立使用者確認的聯絡人。",
            capability: .contacts,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .composeEmailDraft,
            displayName: "Compose Email Draft",
            description: "透過 mailto 建立使用者可見的 Email 草稿 handoff，不會自動寄出。",
            capability: .mail,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openMapDirections,
            displayName: "Open Apple Maps Directions",
            description: "透過 Apple Maps link 開啟使用者可見的路線規劃，不讀取位置、不自動開始導航。",
            capability: .location,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openMessageHandoff,
            displayName: "Open Messages Handoff",
            description: "透過 sms: 開啟使用者可見的 Messages 收件人 handoff；正文留在 Kairo preview，不會自動送出。",
            capability: .messages,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .sendNotification,
            displayName: "Send Notification",
            description: "在通知權限允許後發送本機提醒。",
            capability: .notifications,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier2LowRiskWrite,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .openURL,
            displayName: "Open URL",
            description: "開啟使用者可見的 URL 或 deep link。",
            capability: .documents,
            permissionRequirement: .userInitiated,
            riskTier: .tier1Draft,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .controlHome,
            displayName: "Control Home",
            description: "透過 HomeKit 在使用者授權與確認後執行家庭場景或配件控制。",
            capability: .homeKit,
            permissionRequirement: .runtimePrompt,
            riskTier: .tier3HighRiskExternal,
            supportStatus: .scaffolded
        ),
        SandboxActionDescriptor(
            kind: .externalAPIRequest,
            displayName: "External API Request",
            description: "透過使用者 OAuth 授權的官方 API 執行動作。",
            capability: .externalConnectors,
            permissionRequirement: .oauth,
            riskTier: .tier3HighRiskExternal,
            supportStatus: .requiresIntegration
        ),
        SandboxActionDescriptor(
            kind: .unsupportedSandboxAction,
            displayName: "Unsupported iOS Action",
            description: "清楚標示 iOS sandbox、公開 API 或目前權限不允許的操作，不聲稱可執行。",
            capability: .appIntents,
            permissionRequirement: .unsupported,
            riskTier: .tier3HighRiskExternal,
            supportStatus: .unsupportedBySandbox
        )
    ]
}
