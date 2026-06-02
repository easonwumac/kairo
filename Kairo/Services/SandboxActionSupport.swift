import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

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

public struct HomeKitControlDemoCatalog: Codable, Equatable, Sendable {
    public var recipes: [HomeKitControlDemoRecipe]

    public init(recipes: [HomeKitControlDemoRecipe]) {
        self.recipes = recipes
    }

    public func recipe(id: String) -> HomeKitControlDemoRecipe? {
        recipes.first { $0.id == id }
    }

    public static let `default` = HomeKitControlDemoCatalog(recipes: [
        HomeKitControlDemoRecipe(
            id: "evening-scene",
            title: "Evening Scene",
            summary: "Preview a confirmed HomeKit scene handoff for winding down the living room.",
            sandboxNotes: "HomeKit entitlement, Home authorization, and explicit user confirmation are required before execution.",
            action: AgentAction(
                id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                kind: .controlHome,
                title: "Run Evening Wind Down",
                rationale: "User confirmed Kairo may run a HomeKit scene.",
                payload: .homeControl(HomeControlRequest(
                    homeName: "Home",
                    roomName: "Living Room",
                    targetName: "Evening Wind Down",
                    command: .runScene
                )),
                riskTier: .tier3HighRiskExternal
            )
        ),
        HomeKitControlDemoRecipe(
            id: "desk-lamp",
            title: "Desk Lamp",
            summary: "Preview a confirmed HomeKit accessory write for a focused work setup.",
            sandboxNotes: "HomeKit entitlement, Home authorization, and visible confirmation protect accessory writes.",
            action: AgentAction(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                kind: .controlHome,
                title: "Turn On Desk Lamp",
                rationale: "User confirmed Kairo may update a HomeKit accessory.",
                payload: .homeControl(HomeControlRequest(
                    homeName: "Home",
                    roomName: "Office",
                    targetName: "Desk Lamp",
                    command: .setPower,
                    value: .bool(true)
                )),
                riskTier: .tier3HighRiskExternal
            )
        )
    ])
}

public struct HomeKitControlDemoRecipe: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var sandboxNotes: String
    public var action: AgentAction

    public init(
        id: String,
        title: String,
        summary: String,
        sandboxNotes: String,
        action: AgentAction
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.sandboxNotes = sandboxNotes
        self.action = action
    }

    public var targetSummary: String {
        guard case let .homeControl(request) = action.payload else {
            return "Unsupported HomeKit payload"
        }

        let location = [request.homeName, request.roomName].compactMap { $0 }.joined(separator: " / ")
        let prefix = location.isEmpty ? request.targetName : "\(location) / \(request.targetName)"
        return "\(prefix) · \(request.command.settingsTitle)"
    }

    public var confirmationSummary: String {
        guard case let .homeControl(request) = action.payload else {
            return "Confirm before Kairo runs this HomeKit action."
        }

        switch request.command {
        case .runScene:
            return "Confirm before Kairo runs the HomeKit scene."
        case .setPower, .setBrightness, .setTargetTemperature:
            return "Confirm before Kairo writes to the HomeKit accessory."
        }
    }
}

public extension HomeControlCommand {
    var settingsTitle: String {
        switch self {
        case .runScene:
            return "Run Scene"
        case .setPower:
            return "Set Power"
        case .setBrightness:
            return "Set Brightness"
        case .setTargetTemperature:
            return "Set Temperature"
        }
    }
}

public struct ActionExecutionResult: Equatable, Sendable {
    public var completed: Bool
    public var message: String
    public var createdIdentifier: String?
    public var requiresExternalUI: Bool

    public init(
        completed: Bool,
        message: String,
        createdIdentifier: String? = nil,
        requiresExternalUI: Bool = false
    ) {
        self.completed = completed
        self.message = message
        self.createdIdentifier = createdIdentifier
        self.requiresExternalUI = requiresExternalUI
    }
}

public protocol URLOpener: Sendable {
    func open(_ url: URL) async -> Bool
}

public struct NoOpURLOpener: URLOpener {
    public init() {}

    public func open(_ url: URL) async -> Bool {
        false
    }
}

#if canImport(UIKit)
@MainActor
public struct UIApplicationURLOpener: URLOpener {
    public init() {}

    public func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}
#endif

public protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(_ draft: NotificationDraft) async throws -> String
}

public struct UnavailableNotificationScheduler: NotificationScheduling {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        false
    }

    public func schedule(_ draft: NotificationDraft) async throws -> String {
        throw NotificationSchedulingError.unavailable
    }
}

public enum NotificationSchedulingError: Error, Equatable {
    case unavailable
    case authorizationDenied
}

#if canImport(UserNotifications)
public struct UserNotificationScheduler: NotificationScheduling {
    public init() {}

    public func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    public func schedule(_ draft: NotificationDraft) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = draft.title
        content.body = draft.body
        content.sound = .default

        let trigger: UNNotificationTrigger?
        if let deliveryDate = draft.deliveryDate {
            let interval = max(deliveryDate.timeIntervalSinceNow, 1)
            trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        } else {
            trigger = nil
        }

        let identifier = UUID().uuidString
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
        return identifier
    }
}
#endif

public protocol ActionExecutor: Sendable {
    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult
}

public actor SandboxActionExecutor: ActionExecutor {
    private let memoryStore: MemoryStore
    private let safetyPolicyEngine: SafetyPolicyEngine
    private let eventKitService: EventKitService
    private let urlOpener: any URLOpener
    private let notificationScheduler: any NotificationScheduling
    private let homeControlService: any HomeControlService

    public init(
        memoryStore: MemoryStore,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        eventKitService: EventKitService = EventKitService(),
        urlOpener: any URLOpener = NoOpURLOpener(),
        notificationScheduler: any NotificationScheduling = UnavailableNotificationScheduler(),
        homeControlService: any HomeControlService = UnavailableHomeControlService()
    ) {
        self.memoryStore = memoryStore
        self.safetyPolicyEngine = safetyPolicyEngine
        self.eventKitService = eventKitService
        self.urlOpener = urlOpener
        self.notificationScheduler = notificationScheduler
        self.homeControlService = homeControlService
    }

    public func execute(_ action: AgentAction, confirmed: Bool = false) async throws -> ActionExecutionResult {
        let decision = safetyPolicyEngine.evaluate(action)
        guard decision.allowed else {
            return ActionExecutionResult(completed: false, message: decision.reason)
        }
        guard !decision.requiresConfirmation || confirmed else {
            return ActionExecutionResult(completed: false, message: "Action requires user confirmation.")
        }

        switch (action.kind, action.payload) {
        case (.saveMemory, .text(let text)):
            let memory = MemoryRecord(title: String(text.prefix(40)), summary: String(text.prefix(160)), content: text, source: .chat)
            try await memoryStore.save(memory)
            return ActionExecutionResult(completed: true, message: "Saved memory.", createdIdentifier: memory.id.uuidString)
        case (.createReminderDraft, .reminder(let draft)):
            let identifier = try await eventKitService.createReminder(from: draft)
            return ActionExecutionResult(completed: true, message: "Created reminder.", createdIdentifier: identifier)
        case (.createCalendarDraft, .calendarEvent(let draft)):
            let identifier = try await eventKitService.createCalendarEvent(from: draft)
            return ActionExecutionResult(completed: true, message: "Created calendar event.", createdIdentifier: identifier)
        case (.answer, _):
            return ActionExecutionResult(completed: true, message: "No external action required.")
        case (.openURL, .url(let urlString)):
            guard let url = URL(string: urlString), Self.isSupportedUserVisibleURL(url) else {
                return ActionExecutionResult(completed: false, message: "Unsupported or invalid URL.")
            }
            let opened = await urlOpener.open(url)
            return ActionExecutionResult(
                completed: opened,
                message: opened ? "Opened URL." : "Open URL is available only when the app supplies a UI opener.",
                requiresExternalUI: true
            )
        case (.sendNotification, .notification(let draft)):
            guard try await notificationScheduler.requestAuthorization() else {
                return ActionExecutionResult(completed: false, message: "Notification permission was not granted.")
            }
            let identifier = try await notificationScheduler.schedule(draft)
            return ActionExecutionResult(completed: true, message: "Scheduled notification.", createdIdentifier: identifier)
        case (.controlHome, .homeControl(let request)):
            guard try await homeControlService.requestAuthorization() else {
                return ActionExecutionResult(completed: false, message: "HomeKit permission was not granted.")
            }
            let identifier = try await homeControlService.execute(request)
            return ActionExecutionResult(completed: true, message: "Executed HomeKit control.", createdIdentifier: identifier)
        case (.unsupportedSandboxAction, .unsupported(let explanation)):
            let alternative = explanation.safeAlternative.map { " Safe alternative: \($0)" } ?? ""
            return ActionExecutionResult(completed: false, message: "Unsupported by iOS sandbox: \(explanation.reason).\(alternative)")
        case (.externalAPIRequest, _):
            return ActionExecutionResult(completed: false, message: "External API actions require an OAuth connector integration.")
        default:
            return ActionExecutionResult(completed: false, message: "Unsupported action payload for \(action.kind.rawValue).")
        }
    }

    private static func isSupportedUserVisibleURL(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https", "mailto", "tel":
            return true
        case "shortcuts":
            return url.host?.lowercased() == "run-shortcut"
        default:
            return false
        }
    }
}
