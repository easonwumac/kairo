import Foundation
#if canImport(UIKit)
import UIKit
#endif

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

public struct AllowingURLOpener: URLOpener {
    public init() {}

    public func open(_ url: URL) async -> Bool {
        true
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

public protocol ActionExecutor: Sendable {
    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult
}

public actor SandboxActionExecutor: ActionExecutor {
    private let memoryStore: MemoryStore
    private let safetyPolicyEngine: SafetyPolicyEngine
    private let eventKitService: EventKitService
    private let reminderScheduler: any ReminderScheduling
    private let calendarScheduler: any CalendarScheduling
    private let contactScheduler: any ContactScheduling
    private let urlOpener: any URLOpener
    private let notificationScheduler: any NotificationScheduling
    private let homeControlService: any HomeControlService

    public init(
        memoryStore: MemoryStore,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine(),
        eventKitService: EventKitService = EventKitService(),
        reminderScheduler: (any ReminderScheduling)? = nil,
        calendarScheduler: (any CalendarScheduling)? = nil,
        contactScheduler: any ContactScheduling = ContactsFrameworkContactScheduler(),
        urlOpener: any URLOpener = NoOpURLOpener(),
        notificationScheduler: any NotificationScheduling = UnavailableNotificationScheduler(),
        homeControlService: any HomeControlService = UnavailableHomeControlService()
    ) {
        self.memoryStore = memoryStore
        self.safetyPolicyEngine = safetyPolicyEngine
        self.eventKitService = eventKitService
        self.reminderScheduler = reminderScheduler ?? EventKitReminderScheduler(eventKitService: eventKitService)
        self.calendarScheduler = calendarScheduler ?? EventKitCalendarScheduler(eventKitService: eventKitService)
        self.contactScheduler = contactScheduler
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
            guard try await reminderScheduler.requestAccess() else {
                return ActionExecutionResult(completed: false, message: "Reminder permission was not granted.")
            }
            let identifier = try await reminderScheduler.createReminder(from: draft)
            return ActionExecutionResult(completed: true, message: "Created reminder.", createdIdentifier: identifier)
        case (.createCalendarDraft, .calendarEvent(let draft)):
            guard try await calendarScheduler.requestAccess() else {
                return ActionExecutionResult(completed: false, message: "Calendar permission was not granted.")
            }
            let identifier = try await calendarScheduler.createCalendarEvent(from: draft)
            return ActionExecutionResult(completed: true, message: "Created calendar event.", createdIdentifier: identifier)
        case (.createContactDraft, .contact(let draft)):
            guard try await contactScheduler.requestAccess() else {
                return ActionExecutionResult(completed: false, message: "Contacts permission was not granted.")
            }
            let identifier = try await contactScheduler.createContact(from: draft)
            return ActionExecutionResult(completed: true, message: "Created contact.", createdIdentifier: identifier)
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
        case (.composeEmailDraft, .email(let draft)):
            guard let url = Self.mailtoURL(for: draft) else {
                return ActionExecutionResult(completed: false, message: "Unsupported or invalid email draft.")
            }
            let opened = await urlOpener.open(url)
            return ActionExecutionResult(
                completed: opened,
                message: opened ? "Prepared email draft handoff." : "Email draft handoff is available only when the app supplies a UI opener.",
                requiresExternalUI: true
            )
        case (.openMapDirections, .mapDirections(let draft)):
            guard let url = Self.appleMapsDirectionsURL(for: draft) else {
                return ActionExecutionResult(completed: false, message: "Unsupported or invalid map directions request.")
            }
            let opened = await urlOpener.open(url)
            return ActionExecutionResult(
                completed: opened,
                message: opened ? "Prepared Apple Maps directions handoff." : "Apple Maps directions handoff is available only when the app supplies a UI opener.",
                requiresExternalUI: true
            )
        case (.openMessageHandoff, .message(let draft)):
            guard let url = Self.smsHandoffURL(for: draft) else {
                return ActionExecutionResult(completed: false, message: "Unsupported or invalid message handoff request.")
            }
            let opened = await urlOpener.open(url)
            return ActionExecutionResult(
                completed: opened,
                message: opened ? "Prepared Messages handoff. Message body remains in Kairo preview." : "Messages handoff is available only when the app supplies a UI opener.",
                requiresExternalUI: true
            )
        case (.openPhoneCallHandoff, .phoneCall(let draft)):
            guard let url = Self.phoneCallHandoffURL(for: draft) else {
                return ActionExecutionResult(completed: false, message: "Unsupported or invalid phone call handoff request.")
            }
            let opened = await urlOpener.open(url)
            return ActionExecutionResult(
                completed: opened,
                message: opened ? "Prepared phone call handoff. The call still requires user action in Phone." : "Phone call handoff is available only when the app supplies a UI opener.",
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

    private static func mailtoURL(for draft: EmailDraft) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = draft.to.joined(separator: ",")
        var queryItems: [URLQueryItem] = []
        if !draft.cc.isEmpty {
            queryItems.append(URLQueryItem(name: "cc", value: draft.cc.joined(separator: ",")))
        }
        if !draft.bcc.isEmpty {
            queryItems.append(URLQueryItem(name: "bcc", value: draft.bcc.joined(separator: ",")))
        }
        if !draft.subject.isEmpty {
            queryItems.append(URLQueryItem(name: "subject", value: draft.subject))
        }
        if !draft.body.isEmpty {
            queryItems.append(URLQueryItem(name: "body", value: draft.body))
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        return components.url
    }

    private static func appleMapsDirectionsURL(for draft: MapDirectionsDraft) -> URL? {
        let destination = draft.destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "maps.apple.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "daddr", value: destination),
            URLQueryItem(name: "dirflg", value: draft.mode.appleMapsDirectionFlag)
        ]
        return components.url
    }

    private static func smsHandoffURL(for draft: MessageDraft) -> URL? {
        guard let rawRecipient = draft.recipients.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawRecipient.isEmpty else {
            return URL(string: "sms:")
        }

        let allowedScalars = CharacterSet(charactersIn: "+-().").union(.decimalDigits)
        let recipient = String(rawRecipient.unicodeScalars.filter { allowedScalars.contains($0) })
        guard !recipient.isEmpty else {
            return URL(string: "sms:")
        }

        return URL(string: "sms:\(recipient)")
    }

    private static func phoneCallHandoffURL(for draft: PhoneCallDraft) -> URL? {
        let sanitized = sanitizedDialString(from: draft.phoneNumber)
        guard !sanitized.isEmpty else {
            return nil
        }
        return URL(string: "tel:\(sanitized)")
    }

    private static func sanitizedDialString(from rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var output = ""
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                output.unicodeScalars.append(scalar)
            } else if scalar == "+", output.isEmpty {
                output.unicodeScalars.append(scalar)
            }
        }
        return output
    }

    private static func isSupportedUserVisibleURL(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https", "mailto", "tel", "sms":
            return true
        case "shortcuts":
            return url.host?.lowercased() == "run-shortcut"
        default:
            return false
        }
    }
}

private extension MapDirectionsMode {
    var appleMapsDirectionFlag: String {
        switch self {
        case .driving:
            return "d"
        case .walking:
            return "w"
        case .transit:
            return "r"
        }
    }
}
