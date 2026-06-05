import Foundation

public protocol AgentWriteActionCandidateProviding: Sendable {
    func candidates(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentWriteActionCandidateProvider: AgentWriteActionCandidateProviding {
    public init() {}

    public func candidates(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> [AgentToolInvocationCandidate] {
        [
            contactCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            calendarCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            reminderCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            notificationCandidate(userText: userText, normalizedText: normalizedText, parser: parser)
        ].compactMap { $0 }
    }

    private func notificationCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard !parser.isCalendarWriteRequest(normalizedText),
              !parser.isReminderWriteRequest(normalizedText),
              !parser.isContactWriteRequest(normalizedText),
              !parser.isEmailDraftRequest(normalizedText),
              parser.isNotificationRequest(normalizedText) else {
            return nil
        }

        let draft = NotificationDraft(
            title: KairoL10n.string("chat.action.notification.defaultTitle"),
            body: parser.notificationBody(from: userText)
        )
        let action = AgentAction(
            kind: .sendNotification,
            title: KairoL10n.string("chat.action.displayName.scheduleNotification"),
            rationale: KairoL10n.string("chat.action.rationale.notification"),
            payload: .notification(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-send-notification",
            title: KairoL10n.string("chat.action.displayName.scheduleNotification"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.notifications],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.notification"),
            action: action
        )
    }

    private func contactCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard parser.isContactWriteRequest(normalizedText) else {
            return nil
        }

        let action = AgentAction(
            kind: .createContactDraft,
            title: KairoL10n.string("chat.action.displayName.createContact"),
            rationale: KairoL10n.string("chat.action.rationale.contact"),
            payload: .contact(parser.contactDraft(from: userText)),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-contact",
            title: KairoL10n.string("chat.action.displayName.createContact"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.contacts],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.contact"),
            action: action
        )
    }

    private func calendarCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard parser.isCalendarWriteRequest(normalizedText) else {
            return nil
        }

        let action = AgentAction(
            kind: .createCalendarDraft,
            title: KairoL10n.string("chat.action.displayName.createCalendar"),
            rationale: KairoL10n.string("chat.action.rationale.calendar"),
            payload: .calendarEvent(parser.calendarDraft(from: userText)),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-calendar-event",
            title: KairoL10n.string("chat.action.displayName.createCalendar"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.calendar],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.calendar"),
            action: action
        )
    }

    private func reminderCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard parser.isReminderWriteRequest(normalizedText) else {
            return nil
        }

        let draft = ReminderDraft(
            title: parser.reminderTitle(from: userText),
            notes: KairoL10n.string("chat.action.reminder.defaultNotes"),
            dueDate: nil
        )
        let action = AgentAction(
            kind: .createReminderDraft,
            title: KairoL10n.string("chat.action.displayName.createReminder"),
            rationale: KairoL10n.string("chat.action.rationale.reminder"),
            payload: .reminder(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-reminder",
            title: KairoL10n.string("chat.action.displayName.createReminder"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.reminders],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.reminder"),
            action: action
        )
    }
}
