import Foundation

#if canImport(EventKit)
import EventKit

public actor EventKitService {
    private let store: EKEventStore

    public init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    public func requestCalendarAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await store.requestFullAccessToEvents()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    public func requestReminderAccess() async throws -> Bool {
        if #available(iOS 17.0, macOS 14.0, *) {
            return try await store.requestFullAccessToReminders()
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .reminder) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    public func createReminder(from draft: ReminderDraft) async throws -> String {
        let reminder = EKReminder(eventStore: store)
        reminder.title = draft.title
        reminder.notes = draft.notes
        reminder.calendar = store.defaultCalendarForNewReminders()

        if let dueDate = draft.dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }

        try store.save(reminder, commit: true)
        return reminder.calendarItemIdentifier
    }

    public func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.notes = draft.notes
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent, commit: true)
        return event.calendarItemIdentifier
    }
}
#else
public actor EventKitService {
    public init() {}

    public func requestCalendarAccess() async throws -> Bool {
        throw EventKitServiceError.unavailable
    }

    public func requestReminderAccess() async throws -> Bool {
        throw EventKitServiceError.unavailable
    }

    public func createReminder(from draft: ReminderDraft) async throws -> String {
        throw EventKitServiceError.unavailable
    }

    public func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        throw EventKitServiceError.unavailable
    }
}

public enum EventKitServiceError: Error, Equatable {
    case unavailable
}
#endif
