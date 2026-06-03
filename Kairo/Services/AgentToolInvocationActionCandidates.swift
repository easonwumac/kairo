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
            title: "Kairo Notification",
            body: notificationBody(from: userText)
        )
        let action = AgentAction(
            kind: .sendNotification,
            title: "Schedule Local Notification",
            rationale: "User asked Kairo to prepare a local notification through the public UserNotifications API.",
            payload: .notification(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-send-notification",
            title: "Schedule Local Notification",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.notifications],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use UserNotifications for a local notification after runtime permission and visible confirmation.",
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
            title: "Compose Email Draft",
            rationale: "User asked Kairo to prepare a visible email draft handoff without sending mail automatically.",
            payload: .email(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-compose-email-draft",
            title: "Compose Email Draft",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.mail],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Use a visible mailto handoff for a user-reviewed email draft; Kairo cannot read Apple Mail or send silently.",
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
            title: "Open Apple Maps Directions",
            rationale: "User asked Kairo to open a visible Apple Maps directions handoff.",
            payload: .mapDirections(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-map-directions",
            title: "Open Apple Maps Directions",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.location],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Use an Apple Maps link after visible confirmation; Kairo does not read current location or start navigation silently.",
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
            title: "Open Messages Handoff",
            rationale: "User asked Kairo to prepare a visible Messages recipient handoff; Apple's SMS link does not carry message body text.",
            payload: .message(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-message-handoff",
            title: "Open Messages Handoff",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.messages],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Use a visible sms: recipient handoff after confirmation; body stays in Kairo preview and Kairo cannot read Messages or send silently.",
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
            title: "Open Phone Handoff",
            rationale: "User asked Kairo to prepare a visible Phone handoff. Kairo opens only a tel: URL after confirmation and does not place calls silently.",
            payload: .phoneCall(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-phone-call-handoff",
            title: "Open Phone Handoff",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.phone],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Use a visible tel: handoff after confirmation; Kairo cannot read call history or place calls silently.",
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
            title: "Create Contact",
            rationale: "User asked Kairo to create a contact through the public Contacts.framework API.",
            payload: .contact(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-contact",
            title: "Create Contact",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.contacts],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use Contacts.framework after runtime permission and visible confirmation.",
            action: action
        )
    }

    func calendarActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isCalendarWriteRequest(normalizedText) else {
            return nil
        }

        let startDate = Date().addingTimeInterval(3600)
        let draft = CalendarEventDraft(
            title: calendarTitle(from: userText),
            notes: "Drafted from a Kairo chat request.",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600)
        )
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User asked Kairo to create a calendar event through the public EventKit Calendar API.",
            payload: .calendarEvent(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-calendar-event",
            title: "Create Calendar Event",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.calendar],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use EventKit Calendar after runtime permission and visible confirmation.",
            action: action
        )
    }

    func reminderActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isReminderWriteRequest(normalizedText) else {
            return nil
        }

        let draft = ReminderDraft(
            title: reminderTitle(from: userText),
            notes: "Drafted from a Kairo chat request.",
            dueDate: nil
        )
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User asked Kairo to create a reminder through the public EventKit Reminders API.",
            payload: .reminder(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-reminder",
            title: "Create Reminder",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.reminders],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use EventKit Reminders after runtime permission and visible confirmation.",
            action: action
        )
    }
}
