import XCTest
@testable import KairoCore

final class AgentToolInvocationPlannerTests: XCTestCase {
    func testAgentToolInvocationPlannerSuggestsInstalledShortcutSkillForTaskExtraction() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "把這段內容變成待辦 todo"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == "shortcut-save-shared-text" })

        XCTAssertEqual(candidate.source, .installedSkill)
        XCTAssertEqual(candidate.skillKind, .shortcutWorkflow)
        XCTAssertEqual(candidate.shortcutRecipeID, "save-shared-text")
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("Kairo does not install Apple Shortcuts silently"))
        XCTAssertTrue(candidate.handoffSummary.contains("2 steps: saveMemory -> extractTasks"))
        XCTAssertTrue(candidate.handoffSummary.contains("Input: text, sourceName, variables"))
        XCTAssertTrue(candidate.handoffSummary.contains("Output: memoryID, fields.taskCount"))
        XCTAssertTrue(plan.proposedActions.isEmpty)
    }

    func testAgentToolInvocationPlannerSuggestsReplyDraftAndMeetingPrepShortcutSkills() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let replyPlan = planner.plan(for: AgentToolInvocationRequest(userText: "幫我回覆這封信，語氣簡短一點"))
        let replyCandidate = try XCTUnwrap(replyPlan.candidates.first { $0.skillID == "shortcut-reply-draft-from-shared-text" })
        XCTAssertEqual(replyCandidate.shortcutRecipeID, "reply-draft-from-shared-text")
        XCTAssertEqual(replyCandidate.riskTier, .tier1Draft)
        XCTAssertTrue(replyCandidate.requiresConfirmation)

        let emailPlan = planner.plan(for: AgentToolInvocationRequest(userText: "triage this vendor email and draft a reply with tasks"))
        let emailCandidate = try XCTUnwrap(emailPlan.candidates.first { $0.skillID == "shortcut-email-triage" })
        XCTAssertEqual(emailCandidate.shortcutRecipeID, "email-triage")
        XCTAssertEqual(emailCandidate.riskTier, .tier1Draft)
        XCTAssertTrue(emailCandidate.requiresConfirmation)
        XCTAssertTrue(emailCandidate.handoffSummary.contains("3 steps: summarize -> extractTasks -> draftReply"))
        XCTAssertTrue(emailCandidate.handoffSummary.contains("Input: text, sourceName, variables, previousStepOutput"))
        XCTAssertTrue(emailCandidate.handoffSummary.contains("Output: displayText, fields.summary, fields.chainText"))

        let emailDraftPlan = planner.plan(for: AgentToolInvocationRequest(userText: "write an email draft from this shared text"))
        let emailDraftCandidate = try XCTUnwrap(emailDraftPlan.candidates.first { $0.skillID == "shortcut-email-draft-from-shared-text" })
        XCTAssertEqual(emailDraftCandidate.shortcutRecipeID, "email-draft-from-shared-text")
        XCTAssertEqual(emailDraftCandidate.riskTier, .tier1Draft)
        XCTAssertTrue(emailDraftCandidate.requiresConfirmation)

        let meetingPlan = planner.plan(for: AgentToolInvocationRequest(userText: "Prepare me for the customer meeting from memory notes"))
        let meetingCandidate = try XCTUnwrap(meetingPlan.candidates.first { $0.skillID == "shortcut-meeting-prep-brief" })
        XCTAssertEqual(meetingCandidate.shortcutRecipeID, "meeting-prep-brief")
        XCTAssertEqual(meetingCandidate.riskTier, .tier1Draft)
        XCTAssertTrue(meetingCandidate.handoffSummary.contains("Shortcuts handoff"))
    }

    func testAgentToolInvocationPlannerSuggestsHomeKitActionWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Turn on the desk lamp"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == "homekit-desk-lamp" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .installedSkill)
        XCTAssertEqual(candidate.skillKind, .homeKitControl)
        XCTAssertEqual(candidate.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertEqual(action.kind, .controlHome)
        XCTAssertEqual(action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Office",
            targetName: "Desk Lamp",
            command: .setPower,
            value: .bool(true)
        )))
        XCTAssertEqual(plan.proposedActions, [action])

        let lockPlan = planner.plan(for: AgentToolInvocationRequest(userText: "請幫我處理前門門鎖"))
        let lockCandidate = try XCTUnwrap(lockPlan.candidates.first { $0.skillID == "homekit-front-door-lock" })
        let lockAction = try XCTUnwrap(lockCandidate.action)

        XCTAssertEqual(lockCandidate.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(lockCandidate.requiresConfirmation)
        XCTAssertEqual(lockAction.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Entry",
            targetName: "Front Door Lock",
            command: .setPower,
            value: .bool(false)
        )))
    }

    func testAgentToolInvocationPlannerSuggestsOAuthConnectorWithoutPrivateAppClaims() throws {
        let planner = AgentToolInvocationPlanner(integrationRegistry: IntegrationRegistry())

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Read Gmail and draft a reply"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.integrationKey == "gmail-google-workspace" })

        XCTAssertEqual(candidate.source, .integrationRegistry)
        XCTAssertEqual(candidate.skillKind, .oauthConnector)
        XCTAssertEqual(candidate.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("official OAuth/API"))
        XCTAssertTrue(candidate.handoffSummary.contains("private app data is unavailable"))
        XCTAssertNil(candidate.action)
    }

    func testAgentToolInvocationPlannerSuggestsNotificationActionWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "通知我五分鐘後喝水"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-send-notification" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.notifications])
        XCTAssertEqual(candidate.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertEqual(candidate.handoffSummary, KairoL10n.string("chat.action.handoffSummary.notification"))
        XCTAssertEqual(action.kind, .sendNotification)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .notification(draft) = action.payload else {
            return XCTFail("Expected notification payload.")
        }
        XCTAssertEqual(draft.title, KairoL10n.string("chat.action.notification.defaultTitle"))
        XCTAssertTrue(draft.body.contains("喝水"))
        XCTAssertNil(draft.deliveryDate)
    }

    func testAgentToolInvocationPlannerSuggestsReminderActionWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "建立提醒事項：下班前整理 Kairo model list"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-create-reminder" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.reminders])
        XCTAssertEqual(candidate.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertEqual(candidate.handoffSummary, KairoL10n.string("chat.action.handoffSummary.reminder"))
        XCTAssertEqual(action.kind, .createReminderDraft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .reminder(draft) = action.payload else {
            return XCTFail("Expected reminder payload.")
        }
        XCTAssertTrue(draft.title.contains("下班前整理"))
        XCTAssertEqual(draft.notes, KairoL10n.string("chat.action.reminder.defaultNotes"))
        XCTAssertNil(draft.dueDate)
        XCTAssertFalse(plan.candidates.contains { $0.id == "action-send-notification" })
    }

    func testAgentToolInvocationPlannerSuggestsCalendarActionWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "建立行程：週五 10:00 Kairo roadmap review"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-create-calendar-event" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.calendar])
        XCTAssertEqual(candidate.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("EventKit"))
        XCTAssertEqual(action.kind, .createCalendarDraft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .calendarEvent(draft) = action.payload else {
            return XCTFail("Expected calendar payload.")
        }
        XCTAssertTrue(draft.title.contains("Kairo roadmap review"))
        XCTAssertEqual(draft.notes, "Drafted from a Kairo chat request.")
        XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), 3600, accuracy: 0.1)
        XCTAssertFalse(plan.candidates.contains { $0.id == "action-send-notification" })
    }

    func testAgentToolInvocationPlannerExtractsNaturalLanguageMeetingDraft() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "幫我安排週五 10:00 Kairo roadmap review 會議"))
        let action = try XCTUnwrap(plan.candidates.first { $0.id == "action-create-calendar-event" }?.action)

        guard case let .calendarEvent(draft) = action.payload else {
            return XCTFail("Expected calendar payload.")
        }
        let components = Calendar.current.dateComponents([.weekday, .hour, .minute], from: draft.startDate)
        XCTAssertEqual(draft.title, "Kairo roadmap review")
        XCTAssertEqual(components.weekday, 6)
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(draft.endDate.timeIntervalSince(draft.startDate), 3600, accuracy: 0.1)
    }

    func testAgentToolInvocationPlannerSuggestsContactActionWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "建立聯絡人：王小明 0912-345-678 ming@example.com"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-create-contact" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.contacts])
        XCTAssertEqual(candidate.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("Contacts.framework"))
        XCTAssertEqual(action.kind, .createContactDraft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .contact(draft) = action.payload else {
            return XCTFail("Expected contact payload.")
        }
        XCTAssertEqual(draft.givenName, "王小明")
        XCTAssertEqual(draft.phoneNumbers, ["0912-345-678"])
        XCTAssertEqual(draft.emailAddresses, ["ming@example.com"])
        XCTAssertEqual(draft.notes, "Drafted from a Kairo chat request.")
    }

    func testAgentToolInvocationPlannerSuggestsEmailDraftHandoffWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(
            userText: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap."
        ))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-compose-email-draft" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.mail])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("mailto"))
        XCTAssertEqual(action.kind, .composeEmailDraft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .email(draft) = action.payload else {
            return XCTFail("Expected email payload.")
        }
        XCTAssertEqual(draft.to, ["alex@example.com"])
        XCTAssertEqual(draft.subject, "Kairo update")
        XCTAssertEqual(draft.body, "Please review the roadmap.")
    }

    func testAgentToolInvocationPlannerSuggestsMapDirectionsHandoffWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Drive to Apple Park"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-open-map-directions" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.location])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("Apple Maps"))
        XCTAssertEqual(action.kind, .openMapDirections)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .mapDirections(draft) = action.payload else {
            return XCTFail("Expected map directions payload.")
        }
        XCTAssertEqual(draft.destinationQuery, "Apple Park")
        XCTAssertEqual(draft.mode, .driving)
    }

    func testAgentToolInvocationPlannerSuggestsMessageHandoffWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(
            userText: "Text 0912-345-678 body I am running late."
        ))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-open-message-handoff" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities.map(\.rawValue), ["messages"])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertEqual(candidate.handoffSummary, KairoL10n.string("chat.action.handoffSummary.messages"))
        XCTAssertEqual(action.kind.rawValue, "openMessageHandoff")
        XCTAssertTrue(action.requiresConfirmation)
        let payloadData = try JSONEncoder().encode(action.payload)
        let payloadText = try XCTUnwrap(String(data: payloadData, encoding: .utf8))
        XCTAssertTrue(payloadText.contains(#""message""#))
        XCTAssertTrue(payloadText.contains("0912-345-678"))
        XCTAssertTrue(payloadText.contains("I am running late."))
    }

    func testAgentToolInvocationPlannerSuggestsPhoneCallHandoffWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Call 0912-345-678"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-open-phone-call-handoff" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.phone])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertTrue(candidate.handoffSummary.contains("tel:"))
        XCTAssertEqual(action.kind, .openPhoneCallHandoff)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .phoneCall(draft) = action.payload else {
            return XCTFail("Expected phone call payload.")
        }
        XCTAssertEqual(draft.phoneNumber, "0912-345-678")
        XCTAssertNil(draft.label)
        XCTAssertEqual(draft.notes, "0912-345-678")
    }

    func testAgentToolInvocationPlannerSuggestsWebSearchHandoffWithConfirmation() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Search web for SwiftUI App Intents examples"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "action-open-web-search-handoff" })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .actionCatalog)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.web])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertEqual(candidate.handoffSummary, KairoL10n.string("chat.action.handoffSummary.web"))
        XCTAssertEqual(action.kind, .openWebSearchHandoff)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .webSearch(draft) = action.payload else {
            return XCTFail("Expected web search payload.")
        }
        XCTAssertEqual(draft.query, "SwiftUI App Intents examples")
        XCTAssertEqual(draft.searchURL, "https://duckduckgo.com/?q=SwiftUI%20App%20Intents%20examples")
    }

    func testAgentToolInvocationPlannerRefusesToolUseWhenDisabled() {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(
            userText: "Use HomeKit to open the garage",
            allowsToolUse: false
        ))

        XCTAssertTrue(plan.candidates.isEmpty)
        XCTAssertEqual(plan.proposedActions, [])
        XCTAssertTrue(plan.unsupportedMessage?.contains("Local model fallback cannot use tools") == true)
    }

    func testAgentToolInvocationPlannerIgnoresDisabledSkills() {
        let disabledCatalog = AgentSkillCatalog.default.updatingStatus(id: "homekit-desk-lamp", to: .disabled)
        let planner = AgentToolInvocationPlanner(skillCatalog: disabledCatalog)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Turn on the desk lamp"))

        XCTAssertFalse(plan.candidates.contains { $0.skillID == "homekit-desk-lamp" })
        XCTAssertTrue(plan.proposedActions.isEmpty)
    }
}
