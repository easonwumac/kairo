import Foundation

extension AgentToolInvocationPlanner {
    func notificationActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard !isCalendarWriteRequest(normalizedText) else {
            return nil
        }
        guard !isReminderWriteRequest(normalizedText) else {
            return nil
        }
        guard !isContactWriteRequest(normalizedText) else {
            return nil
        }
        guard !isEmailDraftRequest(normalizedText) else {
            return nil
        }
        guard containsAny(normalizedText, [
            "notify me",
            "notification",
            "send notification",
            "remind me",
            "reminder alert",
            "通知我",
            "通知",
            "提醒我",
            "提醒"
        ]) else {
            return nil
        }

        let draft = NotificationDraft(
            title: KairoL10n.string("chat.action.notification.defaultTitle"),
            body: notificationBody(from: userText)
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

    func contactActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isContactWriteRequest(normalizedText) else {
            return nil
        }

        let draft = contactDraft(from: userText)
        let action = AgentAction(
            kind: .createContactDraft,
            title: KairoL10n.string("chat.action.displayName.createContact"),
            rationale: KairoL10n.string("chat.action.rationale.contact"),
            payload: .contact(draft),
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

    func calendarActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isCalendarWriteRequest(normalizedText) else {
            return nil
        }

        let draft = calendarDraft(from: userText)
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: KairoL10n.string("chat.action.displayName.createCalendar"),
            rationale: KairoL10n.string("chat.action.rationale.calendar"),
            payload: .calendarEvent(draft),
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

    func reminderActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isReminderWriteRequest(normalizedText) else {
            return nil
        }

        let draft = ReminderDraft(
            title: reminderTitle(from: userText),
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
