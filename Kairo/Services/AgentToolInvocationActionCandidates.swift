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

    func emailActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isEmailDraftRequest(normalizedText) else {
            return nil
        }

        let draft = emailDraft(from: userText)
        let action = AgentAction(
            kind: .composeEmailDraft,
            title: KairoL10n.string("chat.action.displayName.composeEmail"),
            rationale: KairoL10n.string("chat.action.rationale.email"),
            payload: .email(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-compose-email-draft",
            title: KairoL10n.string("chat.action.displayName.composeEmail"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.mail],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.email"),
            action: action
        )
    }

    func mapDirectionsActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isMapDirectionsRequest(normalizedText) else {
            return nil
        }

        let draft = mapDirectionsDraft(from: userText, normalizedText: normalizedText)
        let action = AgentAction(
            kind: .openMapDirections,
            title: KairoL10n.string("chat.action.displayName.openMaps"),
            rationale: KairoL10n.string("chat.action.rationale.maps"),
            payload: .mapDirections(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-map-directions",
            title: KairoL10n.string("chat.action.displayName.openMaps"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.location],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.maps"),
            action: action
        )
    }

    func messageHandoffActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard !isEmailDraftRequest(normalizedText) else {
            return nil
        }
        guard isMessageHandoffRequest(normalizedText) else {
            return nil
        }

        let draft = messageDraft(from: userText)
        let action = AgentAction(
            kind: .openMessageHandoff,
            title: KairoL10n.string("chat.action.displayName.openMessages"),
            rationale: KairoL10n.string("chat.action.rationale.messages"),
            payload: .message(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-message-handoff",
            title: KairoL10n.string("chat.action.displayName.openMessages"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.messages],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.messages"),
            action: action
        )
    }

    func phoneCallHandoffActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard !isContactWriteRequest(normalizedText) else {
            return nil
        }
        guard isPhoneCallHandoffRequest(normalizedText) else {
            return nil
        }

        let draft = phoneCallDraft(from: userText)
        guard isPhoneToken(draft.phoneNumber) else {
            return nil
        }

        let action = AgentAction(
            kind: .openPhoneCallHandoff,
            title: KairoL10n.string("chat.action.displayName.openPhone"),
            rationale: KairoL10n.string("chat.action.rationale.phone"),
            payload: .phoneCall(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-phone-call-handoff",
            title: KairoL10n.string("chat.action.displayName.openPhone"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.phone],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.phone"),
            action: action
        )
    }

    func webSearchHandoffActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard !isMapDirectionsRequest(normalizedText),
              !isEmailDraftRequest(normalizedText),
              !isMessageHandoffRequest(normalizedText),
              !isPhoneCallHandoffRequest(normalizedText),
              !isContactWriteRequest(normalizedText),
              isWebSearchHandoffRequest(normalizedText) else {
            return nil
        }

        let draft = webSearchDraft(from: userText)
        let action = AgentAction(
            kind: .openWebSearchHandoff,
            title: KairoL10n.string("chat.action.displayName.openWebSearch"),
            rationale: KairoL10n.string("chat.action.rationale.web"),
            payload: .webSearch(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-web-search-handoff",
            title: KairoL10n.string("chat.action.displayName.openWebSearch"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.web],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.web"),
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
