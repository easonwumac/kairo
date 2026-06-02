import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(EventKit)
import EventKit
#endif
#if canImport(Contacts)
@preconcurrency import Contacts
#endif

public protocol PermissionService: Sendable {
    func status(for capability: CapabilityKey) async -> CapabilityStatus
    func request(_ capability: CapabilityKey) async throws -> CapabilityStatus
}

public struct StubPermissionService: PermissionService {
    public init() {}

    public func status(for capability: CapabilityKey) async -> CapabilityStatus {
        switch capability {
        case .chat, .memory, .shareExtension, .appIntents, .integrationRegistry, .backgroundTasks, .documents, .photos, .mail, .location:
            return .available
        case .homeKit:
            return .unknown
        default:
            return .unknown
        }
    }

    public func request(_ capability: CapabilityKey) async throws -> CapabilityStatus {
        await status(for: capability)
    }
}

public struct SystemPermissionService: PermissionService {
    private let eventKitService: EventKitService

    public init(eventKitService: EventKitService = EventKitService()) {
        self.eventKitService = eventKitService
    }

    public func status(for capability: CapabilityKey) async -> CapabilityStatus {
        switch capability {
        case .chat, .memory, .shareExtension, .appIntents, .integrationRegistry, .backgroundTasks, .documents, .photos, .mail, .location:
            return .available
        case .calendar:
            return calendarStatus()
        case .reminders:
            return reminderStatus()
        case .notifications:
            return await notificationStatus()
        case .contacts:
            return contactStatus()
        case .homeKit, .externalConnectors:
            return .unknown
        }
    }

    public func request(_ capability: CapabilityKey) async throws -> CapabilityStatus {
        switch capability {
        case .calendar:
            return try await eventKitService.requestCalendarAccess() ? .available : .denied
        case .reminders:
            return try await eventKitService.requestReminderAccess() ? .available : .denied
        case .notifications:
            return try await requestNotifications()
        case .contacts:
            return try await requestContacts()
        default:
            return await status(for: capability)
        }
    }

    private func calendarStatus() -> CapabilityStatus {
        #if canImport(EventKit)
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess, .writeOnly:
            return .available
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #else
        return .unsupported
        #endif
    }

    private func reminderStatus() -> CapabilityStatus {
        #if canImport(EventKit)
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .authorized, .fullAccess, .writeOnly:
            return .available
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #else
        return .unsupported
        #endif
    }

    private func contactStatus() -> CapabilityStatus {
        #if canImport(Contacts)
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .authorized {
            return .available
        } else if status == .denied {
            return .denied
        } else if status == .restricted {
            return .restricted
        } else {
            return .unknown
        }
        #else
        return .unsupported
        #endif
    }

    private func requestContacts() async throws -> CapabilityStatus {
        #if canImport(Contacts)
        let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            CNContactStore().requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
        return granted ? .available : .denied
        #else
        return .unsupported
        #endif
    }

    private func notificationStatus() async -> CapabilityStatus {
        #if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .available
        case .denied:
            return .denied
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
        #else
        return .unsupported
        #endif
    }

    private func requestNotifications() async throws -> CapabilityStatus {
        #if canImport(UserNotifications)
        let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        return granted ? .available : .denied
        #else
        return .unsupported
        #endif
    }
}
