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
        XCTAssertTrue(candidate.handoffSummary.contains(KairoL10n.string("chat.tool.summary.shortcutBoundary")))
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
        XCTAssertTrue(meetingCandidate.handoffSummary.contains(KairoL10n.string("chat.tool.summary.shortcutBoundary")))
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

    func testAgentToolInvocationPlannerSuggestsAppIntegrationCatalogCandidateWithoutPrivateAppClaims() throws {
        let planner = AgentToolInvocationPlanner(integrationRegistry: IntegrationRegistry())

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Read Gmail and draft a reply"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.integrationKey == "gmail-google-workspace" })

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(candidate.skillID, AppIntegrationSkillID.gmailDraftAPI.rawValue)
        XCTAssertEqual(candidate.skillKind, .oauthConnector)
        XCTAssertEqual(candidate.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertNil(candidate.action)
    }

    func testAgentToolInvocationPlannerBuildsAppleMailPreviewFromCatalogCandidate() throws {
        let catalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .appleMailHandoff))
        ])
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: catalog
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(
            userText: "Compose email to alex@example.com about the launch plan"
        ))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == AppIntegrationSkillID.appleMailHandoff.rawValue })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(action.kind, .composeEmailDraft)
        XCTAssertFalse(plan.candidates.contains { $0.id == "action-compose-email-draft" })
    }

    func testAgentToolInvocationPlannerUsesInjectedAppIntegrationActionMapper() throws {
        let catalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .appleMailHandoff))
        ])
        let injectedAction = AgentAction(
            kind: .composeEmailDraft,
            title: "Injected Action",
            rationale: "Injected mapper action.",
            payload: .email(EmailDraft(to: ["ops@example.com"], subject: "Injected", body: "Injected")),
            riskTier: .tier1Draft
        )
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: catalog,
            appIntegrationActionMapper: FixedAppIntegrationActionMapper(action: injectedAction)
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(
            userText: "Compose email to ops@example.com"
        ))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == AppIntegrationSkillID.appleMailHandoff.rawValue })

        XCTAssertEqual(candidate.action, injectedAction)
        XCTAssertEqual(plan.proposedActions, [injectedAction])
    }

    func testAgentToolInvocationPlannerUsesInjectedAppIntegrationActionParser() throws {
        let catalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .appleMailHandoff))
        ])
        let expectedDraft = EmailDraft(
            to: ["parser@example.com"],
            subject: "Parser Injected",
            body: "Built by parser injection."
        )
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: catalog,
            appIntegrationActionParser: FixedAppIntegrationActionParser(emailDraft: expectedDraft)
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(
            userText: "Compose email to ignored@example.com"
        ))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == AppIntegrationSkillID.appleMailHandoff.rawValue })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(action.kind, .composeEmailDraft)
        XCTAssertEqual(action.payload, .email(expectedDraft))
    }

    func testAgentToolInvocationPlannerUsesInjectedVisibleHandoffCandidateProvider() throws {
        let injectedAction = AgentAction(
            kind: .openWebSearchHandoff,
            title: "Injected Search",
            rationale: "Injected visible handoff candidate.",
            payload: .webSearch(WebSearchDraft(query: "injected")),
            riskTier: .tier1Draft
        )
        let injectedCandidate = AgentToolInvocationCandidate(
            id: "injected-visible-handoff",
            title: "Injected Search",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.web],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Injected",
            action: injectedAction
        )
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            visibleHandoffCandidateProvider: FixedVisibleHandoffCandidateProvider(candidates: [injectedCandidate])
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "search web for Kairo"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "injected-visible-handoff" })

        XCTAssertEqual(candidate.action, injectedAction)
        XCTAssertTrue(plan.proposedActions.contains(injectedAction))
    }

    func testAgentToolInvocationPlannerUsesInjectedWriteActionCandidateProvider() throws {
        let injectedAction = AgentAction(
            kind: .sendNotification,
            title: "Injected Notification",
            rationale: "Injected write action candidate.",
            payload: .notification(NotificationDraft(title: "Injected", body: "Injected body")),
            riskTier: .tier2LowRiskWrite
        )
        let injectedCandidate = AgentToolInvocationCandidate(
            id: "injected-write-action",
            title: "Injected Notification",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.notifications],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Injected",
            action: injectedAction
        )
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            writeActionCandidateProvider: FixedWriteActionCandidateProvider(candidates: [injectedCandidate])
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "notify me to stand up"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.id == "injected-write-action" })

        XCTAssertEqual(candidate.action, injectedAction)
        XCTAssertTrue(plan.proposedActions.contains(injectedAction))
    }

    func testAgentToolInvocationPlannerUsesInjectedCandidateMatcher() throws {
        let skill = AgentSkill(
            id: "custom-injected-skill",
            displayName: "Injected Skill",
            summary: "Only the injected matcher should surface this skill.",
            kind: .custom,
            source: .userCreated,
            installationStatus: .installed,
            requiredCapabilities: [.chat]
        )
        let planner = AgentToolInvocationPlanner(
            skillCatalog: AgentSkillCatalog(skills: [skill]),
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            visibleHandoffCandidateProvider: FixedVisibleHandoffCandidateProvider(candidates: []),
            writeActionCandidateProvider: FixedWriteActionCandidateProvider(candidates: []),
            candidateMatcher: FixedAgentToolInvocationCandidateMatcher(skillMatches: true)
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "opaque request"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == "custom-injected-skill" })

        XCTAssertEqual(candidate.source, .installedSkill)
        XCTAssertEqual(candidate.skillKind, .custom)
    }

    func testAgentToolInvocationPlannerUsesInjectedCandidateBuilder() throws {
        let skill = AgentSkill(
            id: "custom-builder-input",
            displayName: "Builder Input",
            summary: "The injected builder should own candidate construction.",
            kind: .custom,
            source: .userCreated,
            installationStatus: .installed,
            requiredCapabilities: [.chat]
        )
        let injectedCandidate = AgentToolInvocationCandidate(
            id: "builder-output-candidate",
            title: "Builder Output",
            source: .installedSkill,
            skillID: "custom-builder-input",
            skillKind: .custom,
            requiredCapabilities: [.chat],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Injected builder output"
        )
        let planner = AgentToolInvocationPlanner(
            skillCatalog: AgentSkillCatalog(skills: [skill]),
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            visibleHandoffCandidateProvider: FixedVisibleHandoffCandidateProvider(candidates: []),
            writeActionCandidateProvider: FixedWriteActionCandidateProvider(candidates: []),
            candidateBuilder: FixedAgentToolInvocationCandidateBuilder(candidate: injectedCandidate)
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "builder route"))

        XCTAssertEqual(plan.candidates.first, injectedCandidate)
    }

    func testAgentToolInvocationPlannerMapsURLHandoffCatalogSkillIDWithoutExecutableAction() throws {
        let planner = AgentToolInvocationPlanner(integrationRegistry: IntegrationRegistry(integrations: []))

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Open Google Maps directions to Taipei 101"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.integrationKey == "google-maps" })

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(candidate.skillID, AppIntegrationSkillID.googleMapsDirectionsHandoff.rawValue)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertTrue(candidate.requiresConfirmation)
        XCTAssertNil(candidate.action)
    }

    func testAgentToolInvocationPlannerBuildsAppleMapsPreviewFromCatalogCandidate() throws {
        let catalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .appleMapsDirectionsHandoff))
        ])
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: catalog
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Open maps directions to Apple Park"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == AppIntegrationSkillID.appleMapsDirectionsHandoff.rawValue })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(action.kind, .openMapDirections)
        XCTAssertFalse(plan.candidates.contains { $0.id == "action-open-map-directions" })
    }

    func testAgentToolInvocationPlannerFallsBackToLegacyIntegrationRegistryForUnmigratedConnectors() throws {
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Open GitHub issue tracker"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.integrationKey == "github" })

        XCTAssertEqual(candidate.source, .integrationRegistry)
        XCTAssertEqual(candidate.skillKind, .oauthConnector)
        XCTAssertNil(candidate.action)
    }

    func testAgentToolInvocationPlannerDoesNotSuggestDisabledOrUnsupportedAppIntegrations() throws {
        let disabled = appIntegrationSkill(id: .slackOpenHandoff, availabilityStatus: .disabled)
        let unsupported = appIntegrationSkill(id: .lineShareHandoff, availabilityStatus: .unsupported)
        let planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [disabled, unsupported])
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Send this to Slack and LINE"))

        XCTAssertFalse(plan.candidates.contains { $0.integrationKey == "slack" })
        XCTAssertFalse(plan.candidates.contains { $0.integrationKey == "line" })
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
        let candidate = try XCTUnwrap(plan.candidates.first { $0.action?.kind == .composeEmailDraft })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(candidate.skillID, AppIntegrationSkillID.appleMailHandoff.rawValue)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.mail])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
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
        let candidate = try XCTUnwrap(plan.candidates.first { $0.action?.kind == .openMessageHandoff })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(candidate.skillID, AppIntegrationSkillID.appleMessagesHandoff.rawValue)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities.map(\.rawValue), ["messages"])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
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
        let candidate = try XCTUnwrap(plan.candidates.first { $0.action?.kind == .openPhoneCallHandoff })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(candidate.skillID, AppIntegrationSkillID.applePhoneHandoff.rawValue)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.phone])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
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
        let candidate = try XCTUnwrap(plan.candidates.first { $0.action?.kind == .openWebSearchHandoff })
        let action = try XCTUnwrap(candidate.action)

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertEqual(candidate.skillID, AppIntegrationSkillID.safariWebSearchHandoff.rawValue)
        XCTAssertEqual(candidate.skillKind, .custom)
        XCTAssertEqual(candidate.requiredCapabilities, [.web])
        XCTAssertEqual(candidate.riskTier, .tier1Draft)
        XCTAssertTrue(candidate.requiresConfirmation)
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
        XCTAssertEqual(plan.unsupportedMessage, KairoL10n.string("chat.provider.localFallback.toolsUnavailable"))
    }

    func testAgentToolInvocationPlannerIgnoresDisabledSkills() {
        let disabledCatalog = AgentSkillCatalog.default.updatingStatus(id: "homekit-desk-lamp", to: .disabled)
        let planner = AgentToolInvocationPlanner(skillCatalog: disabledCatalog)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Turn on the desk lamp"))

        XCTAssertFalse(plan.candidates.contains { $0.skillID == "homekit-desk-lamp" })
        XCTAssertTrue(plan.proposedActions.isEmpty)
    }

    func testAgentToolInvocationPlannerBlocksActionCandidatesWhenCatalogToolIsUnavailable() throws {
        var calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        calendarTool.availabilityStatus = .unsupported
        let planner = AgentToolInvocationPlanner(
            skillCatalog: .default,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [calendarTool])
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "建立行程：週五 10:00 Kairo review"))

        XCTAssertFalse(plan.candidates.contains { $0.id == "action-create-calendar-event" })
        XCTAssertTrue(plan.proposedActions.isEmpty)
    }

    func testAgentToolInvocationPlannerUsesInjectedCandidateFilter() {
        let planner = AgentToolInvocationPlanner(
            skillCatalog: .default,
            candidateFilter: BlockingAgentToolCandidateFilter()
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "建立行程：週五 10:00 Kairo review"))

        XCTAssertTrue(plan.candidates.isEmpty)
        XCTAssertTrue(plan.proposedActions.isEmpty)
    }

    func testAgentToolInvocationPlannerFailsClosedWhenActionCandidateHasNoCatalogTool() {
        let planner = AgentToolInvocationPlanner(
            skillCatalog: .default,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [])
        )

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "通知我五分鐘後喝水"))

        XCTAssertFalse(plan.candidates.contains { $0.id == "action-send-notification" })
        XCTAssertTrue(plan.proposedActions.isEmpty)
    }
}

private struct BlockingAgentToolCandidateFilter: AgentToolCandidateFiltering {
    func allowsCandidate(_ candidate: AgentToolInvocationCandidate) -> Bool {
        false
    }
}

private struct FixedAppIntegrationActionMapper: AppIntegrationActionMapping {
    var action: AgentAction

    func visibleHandoffAction(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentAction? {
        action
    }
}

private struct FixedAppIntegrationActionParser: AgentToolInvocationActionParsing {
    var emailDraft: EmailDraft

    func isCalendarWriteRequest(_ normalizedText: String) -> Bool { false }
    func isReminderWriteRequest(_ normalizedText: String) -> Bool { false }
    func isEmailDraftRequest(_ normalizedText: String) -> Bool { true }
    func isMapDirectionsRequest(_ normalizedText: String) -> Bool { false }
    func isMessageHandoffRequest(_ normalizedText: String) -> Bool { false }
    func isPhoneCallHandoffRequest(_ normalizedText: String) -> Bool { false }
    func isWebSearchHandoffRequest(_ normalizedText: String) -> Bool { false }
    func isContactWriteRequest(_ normalizedText: String) -> Bool { false }
    func isNotificationRequest(_ normalizedText: String) -> Bool { false }
    func calendarDraft(from userText: String) -> CalendarEventDraft {
        CalendarEventDraft(
            title: "Parser calendar",
            notes: nil,
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 3_600)
        )
    }
    func reminderTitle(from userText: String) -> String { "Parser reminder" }
    func contactDraft(from userText: String) -> ContactDraft {
        ContactDraft(
            givenName: "Parser",
            familyName: "Contact",
            phoneNumbers: [],
            emailAddresses: [],
            notes: nil
        )
    }
    func notificationBody(from userText: String) -> String { "Parser notification" }
    func emailDraft(from userText: String) -> EmailDraft { emailDraft }
    func mapDirectionsDraft(from userText: String, normalizedText: String) -> MapDirectionsDraft {
        MapDirectionsDraft(destinationQuery: "Parser destination", mode: .driving)
    }
    func messageDraft(from userText: String) -> MessageDraft {
        MessageDraft(recipients: [], body: "Parser message")
    }
    func phoneCallDraft(from userText: String) -> PhoneCallDraft {
        PhoneCallDraft(phoneNumber: "5550100", label: nil, notes: nil)
    }
    func webSearchDraft(from userText: String) -> WebSearchDraft {
        WebSearchDraft(query: "Parser query")
    }
    func isPhoneToken(_ value: String) -> Bool { true }
    func normalize(_ value: String) -> String {
        value.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct FixedWriteActionCandidateProvider: AgentWriteActionCandidateProviding {
    var candidates: [AgentToolInvocationCandidate]

    func candidates(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> [AgentToolInvocationCandidate] {
        candidates
    }
}

private struct FixedAgentToolInvocationCandidateMatcher: AgentToolInvocationCandidateMatching {
    var skillMatches = false
    var integrationMatches = false
    var appIntegrationSkillMatches = false

    func matches(
        skill: AgentSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        skillMatches
    }

    func matches(
        integration: AppIntegration,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        integrationMatches
    }

    func matches(
        appIntegrationSkill: AppIntegrationSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        appIntegrationSkillMatches
    }
}

private struct FixedAgentToolInvocationCandidateBuilder: AgentToolInvocationCandidateBuilding {
    var candidate: AgentToolInvocationCandidate

    func candidate(
        for skill: AgentSkill,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        safetyPolicyEngine: SafetyPolicyEngine
    ) -> AgentToolInvocationCandidate? {
        candidate
    }

    func candidate(
        for integration: AppIntegration,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        nil
    }

    func candidate(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        matcher: any AgentToolInvocationCandidateMatching,
        parser: any AgentToolInvocationActionParsing,
        actionMapper: any AppIntegrationActionMapping
    ) -> AgentToolInvocationCandidate? {
        nil
    }
}

private struct FixedVisibleHandoffCandidateProvider: AgentVisibleHandoffCandidateProviding {
    var candidates: [AgentToolInvocationCandidate]

    func candidates(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> [AgentToolInvocationCandidate] {
        candidates
    }
}

private func appIntegrationSkill(
    id: AppIntegrationSkillID,
    availabilityStatus: AppIntegrationSkillAvailabilityStatus
) -> AppIntegrationSkill {
    AppIntegrationSkill(
        id: id,
        appName: "Example",
        integrationKey: id == .slackOpenHandoff ? "slack" : "line",
        category: .communication,
        supportedSurfaces: [.universalLink],
        schema: AppIntegrationSkillSchema(input: "Input", output: "Output"),
        setupRequirement: availabilityStatus == .unsupported ? .unsupported : .none,
        installedAppRequirement: .none,
        permissionRequirement: availabilityStatus == .unsupported ? .unsupported : .userInitiated,
        availabilityStatus: availabilityStatus,
        riskTier: .tier1Draft,
        confirmationPolicy: .previewAndExplicitConfirmation,
        previewTextKey: "appIntegration.example.preview",
        executionMode: .openURL,
        endpoints: [AppIntegrationSkillEndpoint(universalLinkHost: "example.com")],
        fallback: AppIntegrationFallback(
            reasonKey: "appIntegration.example.fallback.reason",
            safeAlternativeKey: "appIntegration.example.fallback.safeAlternative"
        ),
        audit: AppIntegrationAuditMetadata(capabilityKeys: [.externalConnectors]),
        sourceReference: "test"
    )
}
