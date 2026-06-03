import Foundation
#if canImport(Contacts)
@preconcurrency import Contacts
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

public protocol NotificationScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func schedule(_ draft: NotificationDraft) async throws -> String
}

public protocol ReminderScheduling: Sendable {
    func requestAccess() async throws -> Bool
    func createReminder(from draft: ReminderDraft) async throws -> String
}

public protocol CalendarScheduling: Sendable {
    func requestAccess() async throws -> Bool
    func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String
}

public protocol ContactScheduling: Sendable {
    func requestAccess() async throws -> Bool
    func createContact(from draft: ContactDraft) async throws -> String
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

public struct AllowingNotificationScheduler: NotificationScheduling {
    private let identifier: String

    public init(identifier: String = "notification-id") {
        self.identifier = identifier
    }

    public func requestAuthorization() async throws -> Bool {
        true
    }

    public func schedule(_ draft: NotificationDraft) async throws -> String {
        identifier
    }
}

public enum NotificationSchedulingError: Error, Equatable {
    case unavailable
    case authorizationDenied
}

public struct UnavailableReminderScheduler: ReminderScheduling {
    public init() {}

    public func requestAccess() async throws -> Bool {
        false
    }

    public func createReminder(from draft: ReminderDraft) async throws -> String {
        throw ReminderSchedulingError.unavailable
    }
}

public struct AllowingReminderScheduler: ReminderScheduling {
    private let identifier: String

    public init(identifier: String = "reminder-id") {
        self.identifier = identifier
    }

    public func requestAccess() async throws -> Bool {
        true
    }

    public func createReminder(from draft: ReminderDraft) async throws -> String {
        identifier
    }
}

public struct EventKitReminderScheduler: ReminderScheduling {
    private let eventKitService: EventKitService

    public init(eventKitService: EventKitService = EventKitService()) {
        self.eventKitService = eventKitService
    }

    public func requestAccess() async throws -> Bool {
        try await eventKitService.requestReminderAccess()
    }

    public func createReminder(from draft: ReminderDraft) async throws -> String {
        try await eventKitService.createReminder(from: draft)
    }
}

public enum ReminderSchedulingError: Error, Equatable {
    case unavailable
    case authorizationDenied
}

public struct UnavailableCalendarScheduler: CalendarScheduling {
    public init() {}

    public func requestAccess() async throws -> Bool {
        false
    }

    public func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        throw CalendarSchedulingError.unavailable
    }
}

public struct AllowingCalendarScheduler: CalendarScheduling {
    private let identifier: String

    public init(identifier: String = "calendar-event-id") {
        self.identifier = identifier
    }

    public func requestAccess() async throws -> Bool {
        true
    }

    public func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        identifier
    }
}

public struct EventKitCalendarScheduler: CalendarScheduling {
    private let eventKitService: EventKitService

    public init(eventKitService: EventKitService = EventKitService()) {
        self.eventKitService = eventKitService
    }

    public func requestAccess() async throws -> Bool {
        try await eventKitService.requestCalendarAccess()
    }

    public func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        try await eventKitService.createCalendarEvent(from: draft)
    }
}

public enum CalendarSchedulingError: Error, Equatable {
    case unavailable
    case authorizationDenied
}

public struct UnavailableContactScheduler: ContactScheduling {
    public init() {}

    public func requestAccess() async throws -> Bool {
        false
    }

    public func createContact(from draft: ContactDraft) async throws -> String {
        throw ContactSchedulingError.unavailable
    }
}

public struct AllowingContactScheduler: ContactScheduling {
    private let identifier: String

    public init(identifier: String = "contact-id") {
        self.identifier = identifier
    }

    public func requestAccess() async throws -> Bool {
        true
    }

    public func createContact(from draft: ContactDraft) async throws -> String {
        identifier
    }
}

#if canImport(Contacts)
public struct ContactsFrameworkContactScheduler: ContactScheduling {
    private let store: CNContactStore

    public init(store: CNContactStore = CNContactStore()) {
        self.store = store
    }

    public func requestAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            store.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    public func createContact(from draft: ContactDraft) async throws -> String {
        let contact = CNMutableContact()
        contact.givenName = draft.givenName
        contact.familyName = draft.familyName
        contact.note = draft.notes ?? ""
        contact.phoneNumbers = draft.phoneNumbers.map {
            CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: $0))
        }
        contact.emailAddresses = draft.emailAddresses.map {
            CNLabeledValue(label: CNLabelHome, value: $0 as NSString)
        }

        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
        return contact.identifier
    }
}
#else
public struct ContactsFrameworkContactScheduler: ContactScheduling {
    public init() {}

    public func requestAccess() async throws -> Bool {
        throw ContactSchedulingError.unavailable
    }

    public func createContact(from draft: ContactDraft) async throws -> String {
        throw ContactSchedulingError.unavailable
    }
}
#endif

public enum ContactSchedulingError: Error, Equatable {
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
