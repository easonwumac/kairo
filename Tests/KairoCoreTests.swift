import XCTest
import Foundation
import CryptoKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KairoCore

final class KairoCoreTests: XCTestCase {
    func testMemoryStoreSearchesSavedMemory() async throws {
        let store = InMemoryMemoryStore()
        let memory = MemoryRecord(
            title: "Project Kairo",
            summary: "iOS agent with memory",
            content: "Kairo can remember user-approved content.",
            source: .manual
        )

        try await store.save(memory)
        let results = try await store.search(query: "agent", limit: 10)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, memory.id)
    }

    func testJSONFileMemoryStorePersistsSavedMemory() async throws {
        let fileURL = temporaryFileURL(named: "memory-store.json")
        let memory = MemoryRecord(
            title: "Persistent Memory",
            summary: "Stored on disk",
            content: "Kairo should preserve user-approved memory between launches.",
            source: .manual,
            tags: ["persistence"]
        )

        let firstStore = try await JSONFileMemoryStore(fileURL: fileURL)
        try await firstStore.save(memory)

        let secondStore = try await JSONFileMemoryStore(fileURL: fileURL)
        let results = try await secondStore.search(query: "preserve", limit: 10)

        XCTAssertEqual(results.map(\.id), [memory.id])
    }

    func testJSONFileMemoryStoreSoftDeletesMemory() async throws {
        let fileURL = temporaryFileURL(named: "memory-delete.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let memory = MemoryRecord(
            title: "Delete Me",
            summary: "Soft delete test",
            content: "This should disappear from active lists.",
            source: .manual
        )

        try await store.save(memory)
        try await store.delete(id: memory.id)

        let listed = try await store.list(limit: 10)
        let searched = try await store.search(query: "disappear", limit: 10)

        XCTAssertTrue(listed.isEmpty)
        XCTAssertTrue(searched.isEmpty)
        let rawData = try Data(contentsOf: fileURL)
        let rawText = String(data: rawData, encoding: .utf8) ?? ""
        XCTAssertTrue(rawText.contains(memory.id.uuidString))
        XCTAssertTrue(rawText.contains("deletedAt"))
    }

    func testSafetyPolicyRequiresConfirmationForWrites() {
        let engine = SafetyPolicyEngine()
        let action = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "User asked to remember this.",
            payload: .text("Remember this"),
            riskTier: .tier2LowRiskWrite
        )

        let decision = engine.evaluate(action)

        XCTAssertTrue(decision.allowed)
        XCTAssertTrue(decision.requiresConfirmation)
    }

    func testSandboxActionCatalogSeparatesSupportedAndUnsupportedActions() throws {
        let catalog = SandboxActionCatalog()

        XCTAssertEqual(catalog.descriptor(for: .saveMemory)?.supportStatus, .implemented)
        XCTAssertEqual(catalog.descriptor(for: .sendNotification)?.supportStatus, .scaffolded)
        XCTAssertEqual(catalog.descriptor(for: .createContactDraft)?.capability, .contacts)
        XCTAssertEqual(catalog.descriptor(for: .createContactDraft)?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(catalog.descriptor(for: .createContactDraft)?.riskTier, .tier2LowRiskWrite)
        let messageKind = try XCTUnwrap(AgentActionKind(rawValue: "openMessageHandoff"))
        XCTAssertEqual(catalog.descriptor(for: messageKind)?.capability.rawValue, "messages")
        XCTAssertEqual(catalog.descriptor(for: messageKind)?.permissionRequirement, .userInitiated)
        XCTAssertEqual(catalog.descriptor(for: messageKind)?.riskTier, .tier1Draft)
        XCTAssertEqual(catalog.descriptor(for: .unsupportedSandboxAction)?.supportStatus, .unsupportedBySandbox)
        XCTAssertTrue(catalog.supportedDescriptors.contains { $0.kind == .openURL })
        XCTAssertFalse(catalog.supportedDescriptors.contains { $0.kind == .unsupportedSandboxAction })
        XCTAssertTrue(catalog.unsupportedDescriptors.contains { $0.kind == .unsupportedSandboxAction })
    }

    func testCapabilityPromptContextListsToolsAndUnsupportedBoundaries() {
        let context = CapabilityPromptContextBuilder().build()

        XCTAssertTrue(context.contains("Kairo tool/capability context"))
        XCTAssertTrue(context.contains("saveMemory"))
        XCTAssertTrue(context.contains("createReminderDraft"))
        XCTAssertTrue(context.contains("createContactDraft"))
        XCTAssertTrue(context.contains("composeEmailDraft"))
        XCTAssertTrue(context.contains("openMapDirections"))
        XCTAssertTrue(context.contains("openMessageHandoff"))
        XCTAssertTrue(context.contains("unsupportedSandboxAction"))
        XCTAssertTrue(context.contains("require visible user confirmation"))
        XCTAssertTrue(context.contains("Integration registry"))
        XCTAssertTrue(context.contains("apple-shortcuts"))
        XCTAssertTrue(context.contains("BGTaskScheduler"))
        XCTAssertTrue(context.contains("Local model fallback cannot use tools"))
        XCTAssertTrue(context.contains("homeKit"))
        XCTAssertTrue(context.contains("controlHome"))
    }

    func testCapabilityPromptContextIncludesInstalledSkillsAsToolOptions() {
        let context = CapabilityPromptContextBuilder(skillCatalog: .default).build()

        XCTAssertTrue(context.contains("Installed skills/tools the model may use"))
        XCTAssertTrue(context.contains("homekit-evening-scene"))
        XCTAssertTrue(context.contains("shortcut-daily-briefing"))
        XCTAssertTrue(context.contains("shortcut-save-shared-text"))
        XCTAssertTrue(context.contains("shortcut-screenshot-to-reminders"))
        XCTAssertTrue(context.contains("shortcut-reply-draft-from-shared-text"))
        XCTAssertTrue(context.contains("shortcut-email-triage"))
        XCTAssertTrue(context.contains("shortcut-email-draft-from-shared-text"))
        XCTAssertTrue(context.contains("shortcut-contact-draft-from-shared-text"))
        XCTAssertTrue(context.contains("shortcut-meeting-prep-brief"))
        XCTAssertTrue(context.contains("requiresConfirmation=true"))
    }

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
        XCTAssertTrue(candidate.handoffSummary.contains("UserNotifications"))
        XCTAssertEqual(action.kind, .sendNotification)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .notification(draft) = action.payload else {
            return XCTFail("Expected notification payload.")
        }
        XCTAssertEqual(draft.title, "Kairo Notification")
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
        XCTAssertTrue(candidate.handoffSummary.contains("EventKit"))
        XCTAssertEqual(action.kind, .createReminderDraft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .reminder(draft) = action.payload else {
            return XCTFail("Expected reminder payload.")
        }
        XCTAssertTrue(draft.title.contains("下班前整理"))
        XCTAssertEqual(draft.notes, "Drafted from a Kairo chat request.")
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
        XCTAssertTrue(candidate.handoffSummary.contains("sms:"))
        XCTAssertTrue(candidate.handoffSummary.contains("body stays in Kairo"))
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
        XCTAssertTrue(candidate.handoffSummary.contains("Safari"))
        XCTAssertTrue(candidate.handoffSummary.contains("does not browse silently"))
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

    func testAgentToolInvocationPlannerStaysSplitAcrossSupportFiles() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let plannerSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationPlanner.swift"),
            encoding: .utf8
        )
        let modelsSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationModels.swift"),
            encoding: .utf8
        )
        let matchingSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationSkillMatching.swift"),
            encoding: .utf8
        )
        let actionSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationActionCandidates.swift"),
            encoding: .utf8
        )
        let parsingSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationParsing.swift"),
            encoding: .utf8
        )

        XCTAssertLessThan(plannerSource.split(separator: "\n").count, 120)
        XCTAssertTrue(plannerSource.contains("public func plan(for request: AgentToolInvocationRequest)"))
        XCTAssertTrue(modelsSource.contains("public struct AgentToolInvocationCandidate"))
        XCTAssertTrue(matchingSource.contains("func candidate(for skill: AgentSkill"))
        XCTAssertTrue(matchingSource.contains("func candidate(for integration: AppIntegration"))
        XCTAssertTrue(actionSource.contains("func notificationActionCandidate"))
        XCTAssertTrue(actionSource.contains("func emailActionCandidate"))
        XCTAssertTrue(actionSource.contains("func phoneCallHandoffActionCandidate"))
        XCTAssertTrue(actionSource.contains("func webSearchHandoffActionCandidate"))
        XCTAssertTrue(parsingSource.contains("func calendarTitle(from userText: String)"))
        XCTAssertTrue(parsingSource.contains("func isPhoneCallHandoffRequest"))
        XCTAssertTrue(parsingSource.contains("func isWebSearchHandoffRequest"))
        XCTAssertTrue(parsingSource.contains("func uniqueCandidates"))
    }

    func testAgentCoreAddsDeterministicHomeKitPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Turn on the desk lamp")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .controlHome })
        XCTAssertEqual(action.title, "Turn On Desk Lamp")
        XCTAssertEqual(action.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(action.requiresConfirmation)
    }

    func testAgentCoreReturnsShortcutToolCandidateWithoutActionExecution() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Turn this shared text into todo tasks")

        let candidate = try XCTUnwrap(response.toolCandidates.first { $0.skillID == "shortcut-save-shared-text" })
        XCTAssertEqual(candidate.skillKind, .shortcutWorkflow)
        XCTAssertEqual(candidate.shortcutRecipeID, "save-shared-text")
        XCTAssertTrue(candidate.handoffSummary.contains("Kairo does not install Apple Shortcuts silently"))
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testAgentCoreAddsDeterministicNotificationPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "提醒我下班前整理 Kairo model list")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .sendNotification })
        XCTAssertEqual(action.title, "Schedule Local Notification")
        XCTAssertEqual(action.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-send-notification" })
    }

    func testAgentCoreAddsDeterministicReminderPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Create a reminder to review the Shortcut node outputs")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .createReminderDraft })
        XCTAssertEqual(action.title, "Create Reminder")
        XCTAssertEqual(action.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-create-reminder" })
    }

    func testAgentCoreAddsDeterministicCalendarPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Create a calendar event: Kairo launch review")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .createCalendarDraft })
        XCTAssertEqual(action.title, "Create Calendar Event")
        XCTAssertEqual(action.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-create-calendar-event" })
    }

    func testAgentCoreAddsDeterministicContactPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Create a contact: Alex Chen 555-0100 alex@example.com")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .createContactDraft })
        XCTAssertEqual(action.title, "Create Contact")
        XCTAssertEqual(action.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-create-contact" })
    }

    func testAgentCoreAddsDeterministicEmailDraftPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .composeEmailDraft })
        XCTAssertEqual(action.title, "Compose Email Draft")
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-compose-email-draft" })
    }

    func testAgentCoreAddsDeterministicMapDirectionsPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Drive to Apple Park")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .openMapDirections })
        XCTAssertEqual(action.title, "Open Apple Maps Directions")
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-open-map-directions" })
    }

    func testAgentCoreAddsDeterministicMessagePreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Text 0912-345-678 body I am running late.")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind.rawValue == "openMessageHandoff" })
        XCTAssertEqual(action.title, "Open Messages Handoff")
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-open-message-handoff" })
    }

    func testAgentCoreAddsDeterministicPhoneCallPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Call 0912-345-678")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .openPhoneCallHandoff })
        XCTAssertEqual(action.title, "Open Phone Handoff")
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-open-phone-call-handoff" })
    }

    func testAgentCoreAddsDeterministicWebSearchPreviewAction() async throws {
        let agent = AgentCore(
            memoryStore: InMemoryMemoryStore(),
            aiProvider: MockAIProvider(),
            skillCatalog: .default,
            integrationRegistry: IntegrationRegistry()
        )

        let response = try await agent.respond(to: "Search web for SwiftUI App Intents examples")

        let action = try XCTUnwrap(response.proposedActions.first { $0.kind == .openWebSearchHandoff })
        XCTAssertEqual(action.title, "Open Web Search Handoff")
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(response.toolCandidates.contains { $0.id == "action-open-web-search-handoff" })
    }

#if canImport(SwiftUI)
    @MainActor
    func testChatViewModelConfirmsNotificationActionThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("通知我喝水")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .sendNotification })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .sendNotification)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Scheduled notification.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.sendNotification])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsReminderActionThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("建立提醒事項：下班前整理 Kairo model list")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createReminderDraft })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Created reminder.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.createReminderDraft])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsCalendarActionThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("建立行程：週五 10:00 Kairo roadmap review")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createCalendarDraft })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .createCalendarDraft)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Created calendar event.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.createCalendarDraft])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsContactActionThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("建立聯絡人：王小明 0912-345-678 ming@example.com")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createContactDraft })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .createContactDraft)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Created contact.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.createContactDraft])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsEmailDraftHandoffThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("Draft an email to alex@example.com subject Kairo update body Please review the roadmap.")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .composeEmailDraft })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .composeEmailDraft)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Prepared email draft handoff.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.composeEmailDraft])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsMapDirectionsHandoffThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("Drive to Apple Park")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .openMapDirections })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .openMapDirections)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Prepared Apple Maps directions handoff.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.openMapDirections])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsMessageHandoffThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("Text 0912-345-678 body I am running late.")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind.rawValue == "openMessageHandoff" })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind.rawValue, "openMessageHandoff")

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Prepared Messages handoff.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind.rawValue), ["openMessageHandoff"])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsPhoneCallHandoffThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("Call 0912-345-678")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .openPhoneCallHandoff })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .openPhoneCallHandoff)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Prepared phone call handoff.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.openPhoneCallHandoff])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testChatViewModelConfirmsWebSearchHandoffThroughInjectedExecutor() async throws {
        let executor = MockActionExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            actionExecutor: executor
        )

        await viewModel.send("Search web for SwiftUI App Intents examples")
        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .openWebSearchHandoff })

        viewModel.previewAction(action)
        XCTAssertEqual(viewModel.pendingAction?.kind, .openWebSearchHandoff)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertTrue(viewModel.actionResultMessage?.contains("Prepared Safari web search handoff.") == true)
        let executedActions = await executor.executedActions
        let confirmations = await executor.confirmations
        XCTAssertEqual(executedActions.map(\.kind), [.openWebSearchHandoff])
        XCTAssertEqual(confirmations, [true])
    }
#endif

    func testKairoRecipeTemplateFactoryProvidesInternalSampleRecipes() throws {
        let catalog = KairoRecipeTemplateFactory.sampleCatalog()

        let dailyBriefing = try XCTUnwrap(catalog.recipe(id: "daily-briefing"))
        let sharedTextToTasks = try XCTUnwrap(catalog.recipe(id: "shared-text-to-tasks"))
        let keyboardTodoCapture = try XCTUnwrap(catalog.recipe(id: "keyboard-todo-capture"))

        XCTAssertEqual(dailyBriefing.title, "Daily Briefing")
        XCTAssertEqual(dailyBriefing.createdBy, .template)
        XCTAssertEqual(dailyBriefing.triggerHint, .dailyTime(hour: 8, minute: 30))
        XCTAssertEqual(dailyBriefing.riskTier, .tier1Draft)
        XCTAssertTrue(dailyBriefing.requiredCapabilities.contains(.memory))
        XCTAssertTrue(dailyBriefing.requiredCapabilities.contains(.notifications))
        XCTAssertTrue(dailyBriefing.steps.contains { $0.kind == .askKairo })
        XCTAssertTrue(sharedTextToTasks.steps.contains { $0.kind == .extractTasks })
        XCTAssertTrue(sharedTextToTasks.steps.contains { $0.kind == .createReminderDraft })
        XCTAssertTrue(keyboardTodoCapture.requiredCapabilities.contains(.keyboard))
        XCTAssertFalse(catalog.recipes.contains { $0.title.contains("Apple Shortcut") })
    }

    func testFileBackedKairoRecipeStorePersistsAndTogglesInternalRecipes() async throws {
        let fileURL = temporaryFileURL(named: "kairo-recipes.json")
        let recipe = try XCTUnwrap(KairoRecipeTemplateFactory.sampleCatalog().recipe(id: "daily-briefing"))

        let firstStore = try await FileBackedKairoRecipeStore(fileURL: fileURL)
        try await firstStore.save(recipe)
        try await firstStore.setEnabled(false, id: recipe.id)

        let secondStore = try await FileBackedKairoRecipeStore(fileURL: fileURL)
        let reloadedRecipe = try await secondStore.recipe(id: recipe.id)
        let reloaded = try XCTUnwrap(reloadedRecipe)
        let listedRecipeIDs = try await secondStore.listRecipes().map(\.id)

        XCTAssertEqual(listedRecipeIDs, [recipe.id])
        XCTAssertFalse(reloaded.isEnabled)

        try await secondStore.delete(id: recipe.id)
        let recipesAfterDelete = try await secondStore.listRecipes()
        XCTAssertTrue(recipesAfterDelete.isEmpty)
    }

    func testKairoRecipeRunnerRequiresConfirmationBeforeLowRiskWrites() async throws {
        let recipe = KairoRecipe(
            id: "low-risk-write",
            title: "Low Risk Write",
            summary: "Tests confirmation gating.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "save-memory",
                    title: "Save Memory",
                    kind: .saveMemory,
                    input: .literal("Remember the confirmation gate.")
                )
            ],
            requiredCapabilities: [.memory],
            riskTier: .tier2LowRiskWrite,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let memoryStore = InMemoryMemoryStore()
        let recipeStore = InMemoryKairoRecipeStore(recipes: [recipe])
        let runner = KairoRecipeRunner(recipeStore: recipeStore, memoryStore: memoryStore)

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: false
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertTrue(result.summary.contains("requires confirmation"))
        let memories = try await memoryStore.list(limit: 10)
        XCTAssertTrue(memories.isEmpty)
    }

    func testKairoRecipeRunnerExtractsTasksAndCreatesDraftsDeterministically() async throws {
        let recipe = KairoRecipe(
            id: "task-draft",
            title: "Task Draft",
            summary: "Extracts tasks into drafts.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "extract",
                    title: "Extract Tasks",
                    kind: .extractTasks,
                    input: .sharedContent
                ),
                KairoRecipeStep(
                    id: "draft",
                    title: "Reminder Draft",
                    kind: .createReminderDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.reminders],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .shareExtension,
            input: "TODO: Send Automations UI screenshot\n- Book review meeting",
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        XCTAssertFalse(result.requiresConfirmation)
        XCTAssertEqual(result.proposedActions.count, 2)
        XCTAssertEqual(result.proposedActions.map(\.kind), [.createReminderDraft, .createReminderDraft])
        XCTAssertTrue(result.stepResults.first?.outputText?.contains("Send Automations UI screenshot") == true)
        XCTAssertTrue(result.summary.contains("2 draft"))
    }

    func testKairoRecipeEngineStaysSplitAcrossSupportFiles() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let modelsSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeModels.swift"),
            encoding: .utf8
        )
        let storesSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeStores.swift"),
            encoding: .utf8
        )
        let templatesSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeTemplates.swift"),
            encoding: .utf8
        )
        let planningSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipePlanning.swift"),
            encoding: .utf8
        )
        let runnerSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeRunner.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Kairo/Services/KairoRecipeEngine.swift").path))
        XCTAssertLessThan(modelsSource.split(separator: "\n").count, 260)
        XCTAssertLessThan(runnerSource.split(separator: "\n").count, 380)
        XCTAssertTrue(modelsSource.contains("public struct KairoRecipe"))
        XCTAssertTrue(storesSource.contains("public actor FileBackedKairoRecipeStore"))
        XCTAssertTrue(templatesSource.contains("public enum KairoRecipeTemplateFactory"))
        XCTAssertTrue(planningSource.contains("public struct KairoRecipePlanner"))
        XCTAssertTrue(runnerSource.contains("public struct KairoRecipeRunner"))
    }

    func testChatMessageDecodesMissingToolCandidatesAsEmptyForOldHistory() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "role": "assistant",
          "text": "Old assistant message",
          "createdAt": 0,
          "proposedActions": [],
          "attachments": [],
          "status": "sent"
        }
        """

        let message = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))

        XCTAssertEqual(message.text, "Old assistant message")
        XCTAssertTrue(message.toolCandidates.isEmpty)
    }

    func testIntegrationRegistryListsOAuthAndUserVisibleHandoffs() throws {
        let registry = IntegrationRegistry()

        let google = try XCTUnwrap(registry.integration(for: "gmail-google-workspace"))
        XCTAssertEqual(google.oauth?.providerKey, "google")
        XCTAssertTrue(google.oauth?.requiresBackendTokenExchange == true)
        XCTAssertTrue(google.sandboxNotes.contains("official APIs"))
        XCTAssertTrue(registry.integrations(for: .shortcuts).contains { $0.key == "apple-shortcuts" })
        XCTAssertTrue(registry.userVisibleHandoffs.contains { $0.key == "chatgpt" })
    }

    func testBackgroundTaskPolicySchedulesBoundedRefreshAndRejectsDaemonClaims() throws {
        let policy = BackgroundTaskPolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let scheduled = policy.plan(
            for: BackgroundTaskRequest(
                identifier: "com.kairo.app.refresh",
                trigger: .systemRefresh,
                estimatedDuration: 10
            ),
            now: now
        )
        XCTAssertEqual(scheduled.decision, .schedule)
        XCTAssertEqual(scheduled.earliestBeginDate, now.addingTimeInterval(15 * 60))
        XCTAssertTrue(scheduled.rationale.contains("BGTaskScheduler"))

        let daemon = policy.plan(
            for: BackgroundTaskRequest(
                identifier: "com.kairo.app.refresh",
                trigger: .systemRefresh,
                estimatedDuration: 10,
                requiresContinuousExecution: true
            ),
            now: now
        )
        XCTAssertEqual(daemon.decision, .reject)
        XCTAssertTrue(daemon.rationale.contains("continuous background daemon"))
    }

    func testBackgroundTaskPolicyDefersOversizedConnectorWork() {
        let policy = BackgroundTaskPolicy()
        let now = Date(timeIntervalSince1970: 2_000)

        let plan = policy.plan(
            for: BackgroundTaskRequest(
                identifier: "com.kairo.app.processing.connectors",
                trigger: .afterOAuthRefresh,
                estimatedDuration: 10 * 60
            ),
            now: now
        )

        XCTAssertEqual(plan.decision, .deferred)
        XCTAssertEqual(plan.earliestBeginDate, now.addingTimeInterval(60 * 60))
        XCTAssertTrue(plan.rationale.contains("bounded runtime budget"))
    }

    func testSandboxActionExecutorSavesConfirmedMemory() async throws {
        let store = InMemoryMemoryStore()
        let executor = SandboxActionExecutor(memoryStore: store)
        let action = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "User asked Kairo to remember this.",
            payload: .text("Remember that Kairo must not overclaim sandbox access."),
            riskTier: .tier2LowRiskWrite
        )

        let unconfirmed = try await executor.execute(action, confirmed: false)
        XCTAssertFalse(unconfirmed.completed)

        let confirmed = try await executor.execute(action, confirmed: true)
        XCTAssertTrue(confirmed.completed)
        XCTAssertNotNil(confirmed.createdIdentifier)

        let memories = try await store.search(query: "overclaim", limit: 10)
        XCTAssertEqual(memories.count, 1)
    }

    func testSandboxActionExecutorReportsUnsupportedSandboxActionWithoutExecuting() async throws {
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        let action = AgentAction(
            kind: .unsupportedSandboxAction,
            title: "Read another app",
            rationale: "The user asked for cross-app data access.",
            payload: .unsupported(UnsupportedActionExplanation(
                requestedAction: "Read messages from another app",
                reason: "iOS does not expose another app's private container to Kairo",
                safeAlternative: "Ask the user to share the content into Kairo"
            )),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: false)

        XCTAssertFalse(result.completed)
        XCTAssertTrue(result.message.contains("Unsupported by iOS sandbox"))
        XCTAssertTrue(result.message.contains("share the content"))
    }

    func testSandboxActionExecutorOpensURLThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openURL,
            title: "Open website",
            rationale: "User asked to open a visible URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        let openedURLs = await opener.openedURLs
        XCTAssertEqual(openedURLs, [URL(string: "https://example.com")!])
    }

    func testSandboxActionExecutorOpensConfirmedShortcutHandoffURLThroughInjectedOpener() async throws {
        let handoffURL = try ShortcutHandoffService().runShortcutURL(for: ShortcutHandoffRequest(
            shortcutName: "Kairo Daily Briefing",
            input: ShortcutNodeInput(text: "Action: Review Shortcut handoff"),
            callbackBaseURL: URL(string: "kairo://shortcuts/callback")!,
            requestID: "handoff-123"
        ))
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openURL,
            title: "Run Shortcut",
            rationale: "User confirmed a visible Shortcuts handoff.",
            payload: .url(handoffURL.absoluteString),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        let openedURLs = await opener.openedURLs
        XCTAssertEqual(openedURLs, [handoffURL])
    }

    func testSandboxActionExecutorOpensEmailDraftHandoffThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .composeEmailDraft,
            title: "Compose Email Draft",
            rationale: "User confirmed Kairo may prepare a visible email draft handoff.",
            payload: .email(EmailDraft(
                to: ["alex@example.com"],
                subject: "Kairo update",
                body: "Please review the roadmap."
            )),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, "Prepared email draft handoff.")
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "mailto")
        XCTAssertTrue(openedURL.absoluteString.contains("alex@example.com"))
        XCTAssertTrue(openedURL.absoluteString.contains("subject=Kairo%20update"))
        XCTAssertTrue(openedURL.absoluteString.contains("body=Please%20review%20the%20roadmap."))
    }

    func testSandboxActionExecutorOpensMapDirectionsHandoffThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openMapDirections,
            title: "Open Apple Maps Directions",
            rationale: "User confirmed Kairo may open a visible Apple Maps directions handoff.",
            payload: .mapDirections(MapDirectionsDraft(destinationQuery: "Apple Park", mode: .driving)),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, "Prepared Apple Maps directions handoff.")
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host(), "maps.apple.com")
        XCTAssertTrue(openedURL.absoluteString.contains("daddr=Apple%20Park"))
        XCTAssertTrue(openedURL.absoluteString.contains("dirflg=d"))
    }

    func testSandboxActionExecutorOpensMessageHandoffThroughInjectedOpenerWithoutBodyInURL() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openMessageHandoff,
            title: "Open Messages Handoff",
            rationale: "User confirmed Kairo may open a visible Messages recipient handoff.",
            payload: .message(MessageDraft(recipients: ["0912-345-678"], body: "I am running late.")),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, "Prepared Messages handoff. Message body remains in Kairo preview.")
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "sms")
        XCTAssertTrue(openedURL.absoluteString.contains("0912-345-678"))
        XCTAssertFalse(openedURL.absoluteString.contains("I%20am%20running%20late"))
        XCTAssertFalse(openedURL.absoluteString.contains("body="))
    }

    func testSandboxActionExecutorOpensPhoneCallHandoffThroughInjectedOpenerWithoutCallingSilently() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openPhoneCallHandoff,
            title: "Open Phone Handoff",
            rationale: "User confirmed Kairo may open a visible Phone handoff.",
            payload: .phoneCall(PhoneCallDraft(phoneNumber: "+1 (555) 0100", label: "Alex", notes: "Follow up")),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, "Prepared phone call handoff. The call still requires user action in Phone.")
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "tel")
        XCTAssertEqual(openedURL.absoluteString, "tel:+15550100")
    }

    func testSandboxActionExecutorOpensWebSearchHandoffThroughInjectedOpenerWithoutBrowsingSilently() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openWebSearchHandoff,
            title: "Open Web Search Handoff",
            rationale: "User confirmed Kairo may open a visible Safari search handoff.",
            payload: .webSearch(WebSearchDraft(query: "SwiftUI App Intents examples")),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, "Prepared Safari web search handoff. No browsing has happened inside Kairo.")
        let openedURLs = await opener.openedURLs
        let openedURL = try XCTUnwrap(openedURLs.first)
        XCTAssertEqual(openedURL.scheme, "https")
        XCTAssertEqual(openedURL.host(), "duckduckgo.com")
        XCTAssertEqual(openedURL.absoluteString, "https://duckduckgo.com/?q=SwiftUI%20App%20Intents%20examples")
    }

    func testSandboxActionExecutorSchedulesNotificationThroughInjectedScheduler() async throws {
        let scheduler = MockNotificationScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), notificationScheduler: scheduler)
        let action = AgentAction(
            kind: .sendNotification,
            title: "Notify",
            rationale: "User asked for a local notification.",
            payload: .notification(NotificationDraft(title: "Kairo", body: "Time to review")),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.createdIdentifier, "notification-id")
        let scheduledTitles = await scheduler.scheduledDrafts.map(\.title)
        XCTAssertEqual(scheduledTitles, ["Kairo"])
    }

    func testSandboxActionExecutorCreatesReminderThroughInjectedScheduler() async throws {
        let scheduler = MockReminderScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), reminderScheduler: scheduler)
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User confirmed Kairo may write an EventKit reminder.",
            payload: .reminder(ReminderDraft(title: "Review Shortcut node outputs", notes: "From Kairo chat", dueDate: nil)),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.message, "Created reminder.")
        XCTAssertEqual(result.createdIdentifier, "reminder-id")
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, ["Review Shortcut node outputs"])
    }

    func testSandboxActionExecutorCreatesCalendarEventThroughInjectedScheduler() async throws {
        let scheduler = MockCalendarScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), calendarScheduler: scheduler)
        let startDate = Date(timeIntervalSince1970: 1_780_358_400)
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User confirmed Kairo may write an EventKit calendar event.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Kairo roadmap review",
                notes: "From Kairo chat",
                startDate: startDate,
                endDate: startDate.addingTimeInterval(3600)
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.message, "Created calendar event.")
        XCTAssertEqual(result.createdIdentifier, "calendar-event-id")
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, ["Kairo roadmap review"])
    }

    func testSandboxActionExecutorReportsCalendarPermissionDenied() async throws {
        let scheduler = MockCalendarScheduler(granted: false)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), calendarScheduler: scheduler)
        let startDate = Date(timeIntervalSince1970: 1_780_358_400)
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User confirmed Kairo may write an EventKit calendar event.",
            payload: .calendarEvent(CalendarEventDraft(
                title: "Kairo roadmap review",
                notes: nil,
                startDate: startDate,
                endDate: startDate.addingTimeInterval(3600)
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, "Calendar permission was not granted.")
        let createdTitles = await scheduler.createdDrafts.map(\.title)
        XCTAssertEqual(createdTitles, [])
    }

    func testSandboxActionExecutorCreatesContactThroughInjectedScheduler() async throws {
        let scheduler = MockContactScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), contactScheduler: scheduler)
        let action = AgentAction(
            kind: .createContactDraft,
            title: "Create Contact",
            rationale: "User confirmed Kairo may write a Contacts.framework contact.",
            payload: .contact(ContactDraft(
                givenName: "Alex",
                familyName: "Chen",
                phoneNumbers: ["555-0100"],
                emailAddresses: ["alex@example.com"],
                notes: "From Kairo chat"
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.message, "Created contact.")
        XCTAssertEqual(result.createdIdentifier, "contact-id")
        let createdNames = await scheduler.createdDrafts.map { "\($0.givenName) \($0.familyName)" }
        XCTAssertEqual(createdNames, ["Alex Chen"])
    }

    func testSandboxActionExecutorReportsContactPermissionDenied() async throws {
        let scheduler = MockContactScheduler(granted: false)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), contactScheduler: scheduler)
        let action = AgentAction(
            kind: .createContactDraft,
            title: "Create Contact",
            rationale: "User confirmed Kairo may write a Contacts.framework contact.",
            payload: .contact(ContactDraft(
                givenName: "Alex",
                familyName: "Chen",
                phoneNumbers: ["555-0100"],
                emailAddresses: [],
                notes: nil
            )),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, "Contacts permission was not granted.")
        let createdNames = await scheduler.createdDrafts.map(\.givenName)
        XCTAssertEqual(createdNames, [])
    }

    func testSandboxActionCatalogIncludesHomeKitControlWithRuntimePermission() {
        let catalog = SandboxActionCatalog()

        let descriptor = catalog.descriptor(for: .controlHome)

        XCTAssertEqual(descriptor?.capability, .homeKit)
        XCTAssertEqual(descriptor?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(descriptor?.riskTier, .tier3HighRiskExternal)
        XCTAssertEqual(descriptor?.supportStatus, .scaffolded)
    }

    func testHomeKitControlDemoCatalogBuildsConfirmedSceneAndAccessoryActions() throws {
        let catalog = HomeKitControlDemoCatalog.default
        let sceneRecipe = try XCTUnwrap(catalog.recipe(id: "evening-scene"))
        let accessoryRecipe = try XCTUnwrap(catalog.recipe(id: "desk-lamp"))
        let lockRecipe = try XCTUnwrap(catalog.recipe(id: "front-door-lock"))

        XCTAssertEqual(catalog.recipes.map(\.id), ["evening-scene", "desk-lamp", "front-door-lock"])
        XCTAssertEqual(sceneRecipe.action.kind, .controlHome)
        XCTAssertEqual(sceneRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Living Room",
            targetName: "Evening Wind Down",
            command: .runScene
        )))
        XCTAssertTrue(sceneRecipe.action.requiresConfirmation)
        XCTAssertEqual(sceneRecipe.confirmationSummary, "Confirm before Kairo runs the HomeKit scene.")
        XCTAssertEqual(accessoryRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Office",
            targetName: "Desk Lamp",
            command: .setPower,
            value: .bool(true)
        )))
        XCTAssertTrue(accessoryRecipe.sandboxNotes.contains("HomeKit entitlement"))
        XCTAssertEqual(lockRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Entry",
            targetName: "Front Door Lock",
            command: .setPower,
            value: .bool(false)
        )))
        XCTAssertEqual(lockRecipe.action.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(lockRecipe.sandboxNotes.contains("Locks and security devices"))
        XCTAssertEqual(lockRecipe.confirmationSummary, "Confirm in Kairo before any HomeKit security-device write.")
    }

    func testAgentSkillCatalogExposesInstalledToolsAndDownloadableMarketplaceSkills() throws {
        let catalog = AgentSkillCatalog.default
        let homeKitSkill = try XCTUnwrap(catalog.skill(id: "homekit-evening-scene"))
        let lockSkill = try XCTUnwrap(catalog.skill(id: "homekit-front-door-lock"))
        let shortcutSkill = try XCTUnwrap(catalog.skill(id: "shortcut-daily-briefing"))
        let marketplaceSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Downloadable skill package that summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )

        XCTAssertEqual(catalog.installedSkills.map(\.id), [
            "homekit-evening-scene",
            "homekit-desk-lamp",
            "homekit-front-door-lock",
            "shortcut-daily-briefing",
            "shortcut-save-shared-text",
            "shortcut-screenshot-to-reminders",
            "shortcut-reply-draft-from-shared-text",
            "shortcut-message-reply-handoff",
            "shortcut-email-triage",
            "shortcut-email-draft-from-shared-text",
            "shortcut-phone-call-handoff",
            "shortcut-web-search-handoff",
            "shortcut-contact-draft-from-shared-text",
            "shortcut-meeting-prep-brief",
            "shortcut-request-to-recipe-draft",
            "shortcut-meeting-text-to-calendar-draft",
            "shortcut-generic-node-runner",
            "shortcut-home-action-preview"
        ])
        XCTAssertEqual(homeKitSkill.kind, .homeKitControl)
        XCTAssertEqual(homeKitSkill.installationStatus, .installed)
        XCTAssertEqual(homeKitSkill.action?.kind, .controlHome)
        XCTAssertTrue(homeKitSkill.managementSummary.contains("Requires confirmation"))
        XCTAssertEqual(lockSkill.kind, .homeKitControl)
        XCTAssertEqual(lockSkill.action?.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(lockSkill.managementSummary.contains("Requires confirmation"))
        XCTAssertEqual(shortcutSkill.kind, .shortcutWorkflow)
        XCTAssertTrue(marketplaceSkill.canDownload)
        XCTAssertEqual(marketplaceSkill.source, .marketplace)
    }

    func testAgentSkillCatalogExposesEveryShortcutDemoAsInstalledSkill() throws {
        let catalog = AgentSkillCatalog.default

        for recipe in ShortcutDemoCatalog.default.recipes {
            let skill = try XCTUnwrap(catalog.skill(id: "shortcut-\(recipe.id)"))
            XCTAssertEqual(skill.kind, .shortcutWorkflow)
            XCTAssertEqual(skill.source, .builtIn)
            XCTAssertEqual(skill.installationStatus, .installed)
            XCTAssertEqual(skill.requiredCapabilities, [.appIntents])
            XCTAssertEqual(skill.shortcutRecipeID, recipe.id)
            XCTAssertTrue(skill.summary.contains(recipe.title))
        }
    }

    func testAgentSkillManifestRequiresSignatureAndVerifiesChecksum() throws {
        let downloadableSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let checksum = try AgentSkillManifest.sha256Hex(for: downloadableSkill)
        let manifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: checksum,
            signature: AgentSkillManifestSignature(
                keyID: "kairo-marketplace-2026",
                algorithm: .ed25519,
                value: "signed-weather-briefing"
            )
        )

        XCTAssertNoThrow(try manifest.validateForInstall())
        XCTAssertEqual(manifest.installableSkill.installationStatus, .installed)
        XCTAssertEqual(manifest.installableSkill.source, .marketplace)
        XCTAssertEqual(manifest.installableSkill.version, "1.0")

        let tamperedManifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: "invalid-checksum",
            signature: manifest.signature
        )
        XCTAssertThrowsError(try tamperedManifest.validateForInstall()) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .checksumMismatch)
        }

        let unsignedManifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: checksum,
            signature: nil
        )
        XCTAssertThrowsError(try unsignedManifest.validateForInstall()) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .missingSignature)
        }
    }

    func testAgentSkillManifestTrustStoreVerifiesPublicKeySignatureAndRejectsUnknownKeys() throws {
        let downloadableSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        var manifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: try AgentSkillManifest.sha256Hex(for: downloadableSkill),
            signature: nil
        )
        let signingKey = P256.Signing.PrivateKey()
        let signature = try signingKey.signature(for: manifest.signingPayloadData())
        manifest.signature = AgentSkillManifestSignature(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            value: signature.derRepresentation.base64EncodedString()
        )
        let trustedKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
        )
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [trustedKey])

        XCTAssertNoThrow(try manifest.validateForInstall(trustStore: trustStore))

        let emptyTrustStore = AgentSkillManifestTrustStore(trustedKeys: [])
        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: emptyTrustStore)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .unknownSigningKey("kairo-marketplace-2026"))
        }

        manifest.signature?.value = Data("tampered-signature".utf8).base64EncodedString()
        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: trustStore)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .invalidSignature)
        }
    }

    func testAgentSkillManagerUsesTrustStoreWhenProvided() async throws {
        let storeURL = temporaryFileURL(named: "trusted-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.installationStatus, .installed)

        let untrustedKey = P256.Signing.PrivateKey()
        let untrustedManifest = try AgentSkillManifest.signedForTesting(
            skill: AgentSkill.marketplaceTemplate(
                id: "marketplace-untrusted",
                displayName: "Untrusted Skill",
                summary: "A marketplace skill signed by an unknown key.",
                requiredCapabilities: [.externalConnectors],
                downloadURL: URL(string: "https://skills.kairo.app/untrusted.json")!
            ),
            packageVersion: "2026.6",
            keyID: "unknown-key",
            signingKey: untrustedKey
        )
        await XCTAssertThrowsErrorAsync(try await service.install(manifest: untrustedManifest)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .unknownSigningKey("unknown-key"))
        }
    }

    func testAgentSkillManagerInstallsSignedManifestFromJSONString() async throws {
        let storeURL = temporaryFileURL(named: "imported-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)

        let installed = try await service.installManifest(jsonString: manifestJSON)
        let catalog = try await service.catalog()

        XCTAssertEqual(installed.id, "marketplace-weather-briefing")
        XCTAssertEqual(installed.installationStatus, .installed)
        XCTAssertEqual(catalog.skill(id: "marketplace-weather-briefing")?.source, .marketplace)
    }

    func testAgentSkillManagerRejectsInvalidManifestJSONString() async throws {
        let storeURL = temporaryFileURL(named: "invalid-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        await XCTAssertThrowsErrorAsync(try await service.installManifest(jsonString: "{not-json")) { error in
            XCTAssertEqual(error as? AgentSkillManifestImportError, .invalidJSON)
        }
    }

    func testAgentSkillManagerRejectsDowngradeAndAllowsSameOrNewerSignedManifestVersions() async throws {
        let storeURL = temporaryFileURL(named: "versioned-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)

        let installed = try await service.install(manifest: signedWeatherSkillManifest(version: "2.0.0", signingKey: signingKey))
        XCTAssertEqual(installed.version, "2.0.0")

        let reinstalled = try await service.install(manifest: signedWeatherSkillManifest(version: "2.0", signingKey: signingKey))
        XCTAssertEqual(reinstalled.version, "2.0")

        let upgraded = try await service.install(manifest: signedWeatherSkillManifest(version: "2.1.0", signingKey: signingKey))
        XCTAssertEqual(upgraded.version, "2.1.0")

        await XCTAssertThrowsErrorAsync(try await service.install(manifest: signedWeatherSkillManifest(version: "2.0.9", signingKey: signingKey))) { error in
            XCTAssertEqual(error as? AgentSkillInstallError, .versionDowngrade(skillID: "marketplace-weather-briefing", installedVersion: "2.1.0", incomingVersion: "2.0.9"))
        }
    }

    func testAgentSkillManagerBuildsSignedManifestUpdatePreviewWithChangelog() async throws {
        let storeURL = temporaryFileURL(named: "preview-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)
        _ = try await service.install(manifest: signedWeatherSkillManifest(version: "2.0.0", signingKey: signingKey))
        let updateManifest = try signedWeatherSkillManifest(
            version: "2.1.0",
            signingKey: signingKey,
            changelog: [
                "Adds storm alerts.",
                "Improves hourly summary."
            ]
        )

        let preview = try await service.previewInstall(manifest: updateManifest)

        XCTAssertEqual(preview.skillID, "marketplace-weather-briefing")
        XCTAssertEqual(preview.displayName, "Weather Briefing")
        XCTAssertEqual(preview.installedVersion, "2.0.0")
        XCTAssertEqual(preview.incomingVersion, "2.1.0")
        XCTAssertEqual(preview.packageVersion, "2026.6")
        XCTAssertEqual(preview.changelog, [
            "Adds storm alerts.",
            "Improves hourly summary."
        ])
        XCTAssertEqual(preview.installationChange, .update)
        XCTAssertEqual(preview.summary, "Update Weather Briefing from 2.0.0 to 2.1.0.")
    }

    func testAgentSkillManagerBuildsDowngradeBlockedPreviewFromManifestJSONString() async throws {
        let storeURL = temporaryFileURL(named: "preview-downgrade-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)
        _ = try await service.install(manifest: signedWeatherSkillManifest(version: "3.0.0", signingKey: signingKey))
        let downgradeManifestJSON = try AgentSkillManifest.encodeJSONString(signedWeatherSkillManifest(
            version: "2.9.0",
            signingKey: signingKey,
            changelog: ["Attempts to downgrade the installed skill."]
        ))

        let preview = try await service.previewInstall(jsonString: downgradeManifestJSON)

        XCTAssertEqual(preview.installedVersion, "3.0.0")
        XCTAssertEqual(preview.incomingVersion, "2.9.0")
        XCTAssertEqual(preview.installationChange, .downgradeBlocked)
        XCTAssertEqual(preview.summary, "Blocked downgrade for Weather Briefing from 3.0.0 to 2.9.0.")
    }

    func testAgentSkillCompatibilityEvaluatorReportsMissingRuntimeRequirements() {
        let skill = AgentSkill(
            id: "marketplace-local-oauth-homekit",
            displayName: "Local OAuth HomeKit Skill",
            summary: "Requires a newer device context, HomeKit, OAuth, and a downloaded local model.",
            kind: .custom,
            source: .marketplace,
            installationStatus: .available,
            requiredCapabilities: [.homeKit, .externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/local-oauth-homekit.json")!,
            compatibilityRequirements: AgentSkillCompatibilityRequirements(
                minimumIOSVersion: "18.0",
                requiredEntitlements: ["com.apple.developer.homekit"],
                requiredOAuthProviderKeys: ["google"],
                requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
            )
        )
        let context = AgentSkillRuntimeContext(
            iosVersion: "17.0",
            grantedEntitlements: [],
            connectedOAuthProviderKeys: [],
            installedLocalModelIDs: []
        )

        let report = AgentSkillCompatibilityEvaluator(context: context).evaluate(skill)

        XCTAssertFalse(report.isInstallable)
        XCTAssertEqual(report.blockingIssues.map(\.kind), [
            .minimumIOSVersion,
            .missingEntitlement,
            .missingOAuthProvider,
            .missingLocalModel
        ])
        XCTAssertTrue(report.summary.contains("Requires iOS 18.0 or later"))
        XCTAssertTrue(report.summary.contains("Missing entitlement com.apple.developer.homekit"))
        XCTAssertTrue(report.summary.contains("Connect OAuth provider google"))
        XCTAssertTrue(report.summary.contains("Download local model qwen3-5-0-8b-q4-k-m"))
    }

    func testAgentSkillManagerBlocksInstallWhenCompatibilityRequirementsAreMissing() async throws {
        let storeURL = temporaryFileURL(named: "compatibility-blocked-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires Google OAuth and a downloaded Qwen model before install.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/qwen-oauth-workflow.json")!
        )
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.0",
                grantedEntitlements: [],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: []
            )
        )

        let preview = try await service.previewInstall(manifest: manifest)
        XCTAssertEqual(preview.compatibilityReport.blockingIssues.map(\.kind), [
            .missingOAuthProvider,
            .missingLocalModel
        ])
        XCTAssertTrue(preview.summary.contains("Blocked"))

        await XCTAssertThrowsErrorAsync(try await service.install(manifest: manifest)) { error in
            guard case AgentSkillInstallError.compatibilityBlocked(let skillID, let issues) = error else {
                return XCTFail("Expected compatibilityBlocked, got \(error)")
            }
            XCTAssertEqual(skillID, "marketplace-qwen-oauth-workflow")
            XCTAssertEqual(issues.map(\.kind), [.missingOAuthProvider, .missingLocalModel])
        }
    }

    func testAgentSkillManagerInstallsWhenCompatibilityRequirementsAreSatisfied() async throws {
        let storeURL = temporaryFileURL(named: "compatibility-allowed-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-homekit-qwen",
            displayName: "HomeKit Qwen Skill",
            summary: "Requires HomeKit entitlement and a downloaded Qwen model.",
            requiredCapabilities: [.homeKit],
            downloadURL: URL(string: "https://skills.kairo.app/homekit-qwen.json")!,
            kind: .homeKitControl
        )
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            minimumIOSVersion: "17.0",
            requiredEntitlements: ["com.apple.developer.homekit"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.2",
                grantedEntitlements: ["com.apple.developer.homekit"],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
            )
        )

        let preview = try await service.previewInstall(manifest: manifest)
        XCTAssertTrue(preview.compatibilityReport.isInstallable)
        XCTAssertTrue(preview.compatibilityReport.blockingIssues.isEmpty)

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.id, "marketplace-homekit-qwen")
        XCTAssertEqual(installed.installationStatus, .installed)
    }

    func testAgentSkillManagerCreatesDisabledUserSkillDraftsWithStableIDs() async throws {
        let storeURL = temporaryFileURL(named: "user-created-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        let draft = try await service.createUserSkillDraft(AgentSkillDraftRequest(
            displayName: "Kairo Inbox Triage",
            summary: "Drafts a visible inbox triage plan from approved OAuth connector data.",
            kind: .custom,
            requiredCapabilities: [.externalConnectors],
            compatibilityRequirements: AgentSkillCompatibilityRequirements(
                requiredOAuthProviderKeys: ["google"]
            )
        ))

        XCTAssertEqual(draft.id, "user-kairo-inbox-triage")
        XCTAssertEqual(draft.source, .userCreated)
        XCTAssertEqual(draft.installationStatus, .disabled)
        XCTAssertEqual(draft.requiredCapabilities, [.externalConnectors])
        XCTAssertEqual(draft.compatibilityRequirements.requiredOAuthProviderKeys, ["google"])

        let catalog = try await service.catalog()
        XCTAssertEqual(catalog.skill(id: "user-kairo-inbox-triage"), draft)

        let reloadedStore = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let reloadedService = AgentSkillManagerService(store: reloadedStore, builtInCatalog: .default)
        let reloadedCatalog = try await reloadedService.catalog()

        XCTAssertEqual(reloadedCatalog.skill(id: "user-kairo-inbox-triage")?.source, .userCreated)
        XCTAssertEqual(reloadedCatalog.skill(id: "user-kairo-inbox-triage")?.installationStatus, .disabled)
    }

    func testAgentSkillManagerCreatesUniqueUserSkillDraftIDsForDuplicateNames() async throws {
        let storeURL = temporaryFileURL(named: "duplicate-user-created-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)
        let request = AgentSkillDraftRequest(
            displayName: "Daily Skill",
            summary: "A user-created local skill draft.",
            kind: .custom,
            requiredCapabilities: [.appIntents]
        )

        let first = try await service.createUserSkillDraft(request)
        let second = try await service.createUserSkillDraft(request)

        XCTAssertEqual(first.id, "user-daily-skill")
        XCTAssertEqual(second.id, "user-daily-skill-2")
        let catalog = try await service.catalog()
        XCTAssertEqual(catalog.disabledSkills.filter { $0.source == .userCreated }.map(\.id), [
            "user-daily-skill",
            "user-daily-skill-2"
        ])
    }

    func testFileBackedAgentSkillManagerPersistsInstallDisableEnableAndRemoveLifecycle() async throws {
        let storeURL = temporaryFileURL(named: "agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.installationStatus, .installed)
        XCTAssertEqual(installed.source, .marketplace)

        var catalog = try await service.catalog()
        XCTAssertTrue(catalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        let disabled = try await service.disableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(disabled?.installationStatus, .disabled)
        catalog = try await service.catalog()
        XCTAssertFalse(catalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))
        XCTAssertEqual(catalog.skill(id: "marketplace-weather-briefing")?.installationStatus, .disabled)

        let enabled = try await service.enableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(enabled?.installationStatus, .installed)

        let reloadedStore = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let reloadedService = AgentSkillManagerService(store: reloadedStore, builtInCatalog: .default)
        let reloadedCatalog = try await reloadedService.catalog()
        XCTAssertEqual(reloadedCatalog.skill(id: "marketplace-weather-briefing")?.installationStatus, .installed)

        try await reloadedService.removeSkill(id: "marketplace-weather-briefing")
        let removedCatalog = try await reloadedService.catalog()
        XCTAssertNil(removedCatalog.skill(id: "marketplace-weather-briefing"))
    }

    func testFileBackedAgentSkillManagerPersistsBuiltInShortcutSkillStatus() async throws {
        let storeURL = temporaryFileURL(named: "built-in-shortcut-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        let disabled = try await service.disableSkill(id: "shortcut-save-shared-text")
        XCTAssertEqual(disabled?.source, .builtIn)
        XCTAssertEqual(disabled?.shortcutRecipeID, "save-shared-text")
        XCTAssertEqual(disabled?.installationStatus, .disabled)

        let reloadedStore = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let reloadedService = AgentSkillManagerService(store: reloadedStore, builtInCatalog: .default)
        let reloadedCatalog = try await reloadedService.catalog()

        XCTAssertEqual(reloadedCatalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .disabled)
        XCTAssertFalse(reloadedCatalog.installedSkills.map(\.id).contains("shortcut-save-shared-text"))
        XCTAssertTrue(reloadedCatalog.installedSkills.map(\.id).contains("shortcut-screenshot-to-reminders"))
    }

    func testSkillMarketplaceWebsitePublishesSearchableStaticSite() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let html = try String(
            contentsOf: root.appendingPathComponent("Website/skills/index.html"),
            encoding: .utf8
        )

        XCTAssertTrue(html.contains("Kairo Skill Marketplace"))
        XCTAssertTrue(html.contains(#"id="skill-search""#))
        XCTAssertTrue(html.contains(#"data-skill-grid"#))
        XCTAssertTrue(html.contains("skills.json"))
        XCTAssertTrue(html.contains("Permissions"))
        XCTAssertTrue(html.contains("Risk"))
        XCTAssertTrue(html.contains("Changelog"))
        XCTAssertTrue(html.contains("manifestURL"))
        XCTAssertTrue(html.contains("Skill card artwork"))
    }

    func testModelCatalogWebsitePublishesDownloadableModelIndex() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let catalogURL = root.appendingPathComponent("Website/models/models.json")
        let catalog = try LocalModelCatalog.decode(Data(contentsOf: catalogURL))
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)
        let builtInIDs = LocalModelCatalog.kairoDefault
            .availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)
            .map(\.id)

        XCTAssertEqual(catalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(availableModels.map(\.id), builtInIDs)
        XCTAssertTrue(availableModels.allSatisfy { $0.runtime == .gguf })
        XCTAssertTrue(availableModels.allSatisfy { $0.downloadURL.scheme == "https" })
        XCTAssertTrue(availableModels.allSatisfy { $0.sha256.count == 64 })
        XCTAssertEqual(availableModels.count, 2)

        let qwenTiny = try XCTUnwrap(availableModels.first { $0.id == "qwen3-5-0-8b-q4-k-m" })
        let mlxBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .mlx })
        XCTAssertEqual(mlxBenchmark.artifactReference, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertFalse(mlxBenchmark.supportsInAppDownload)
        XCTAssertTrue(mlxBenchmark.isReferenceOnlyForIOS)
    }

    func testModelCatalogWebsiteDocumentsNoWeightsPolicy() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let indexHTML = try String(contentsOf: root.appendingPathComponent("Website/models/index.html"), encoding: .utf8)
        let readme = try String(contentsOf: root.appendingPathComponent("Website/models/README.md"), encoding: .utf8)
        let rootReadme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)

        XCTAssertTrue(indexHTML.contains("Kairo Model Catalog"))
        XCTAssertTrue(indexHTML.contains("models.json"))
        XCTAssertTrue(indexHTML.contains("compact starter pair: Qwen3.5 0.8B and Llama 3.2 1B"))
        XCTAssertTrue(indexHTML.contains("Llama 3.2 1B"))
        XCTAssertFalse(indexHTML.contains("Gemma 3 1B"))
        XCTAssertFalse(indexHTML.contains("SmolLM2 1.7B"))
        XCTAssertTrue(indexHTML.contains("font-size: 9px"))
        XCTAssertTrue(indexHTML.contains("benchmark profiles"))
        XCTAssertTrue(readme.contains("Do not commit model weights"))
        XCTAssertTrue(readme.contains("kairo-models"))
        XCTAssertTrue(readme.contains("runtime benchmark profiles"))
        XCTAssertTrue(rootReadme.contains("currently Qwen3.5 0.8B and Llama 3.2 1B"))
        XCTAssertFalse(rootReadme.contains("DeepSeek R1 Distill Qwen"))
    }

    func testSandboxActionExecutorRequiresConfirmationBeforeHomeKitControl() async throws {
        let service = MockHomeControlService(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), homeControlService: service)
        let action = AgentAction(
            kind: .controlHome,
            title: "Turn on office scene",
            rationale: "User asked Kairo to run a HomeKit scene.",
            payload: .homeControl(HomeControlRequest(
                homeName: "Home",
                targetName: "Office Focus",
                command: .runScene,
                value: nil
            )),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: false)
        let requests = await service.requests

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, "Action requires user confirmation.")
        XCTAssertTrue(requests.isEmpty)
    }

    func testSandboxActionExecutorRunsConfirmedHomeKitControlThroughInjectedService() async throws {
        let service = MockHomeControlService(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), homeControlService: service)
        let request = HomeControlRequest(
            homeName: "Home",
            roomName: "Office",
            targetName: "Desk Lamp",
            command: .setPower,
            value: .bool(true)
        )
        let action = AgentAction(
            kind: .controlHome,
            title: "Turn on desk lamp",
            rationale: "User confirmed a HomeKit accessory action.",
            payload: .homeControl(request),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: true)
        let requests = await service.requests

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.createdIdentifier, "home-control-id")
        XCTAssertEqual(requests, [request])
    }

    func testOpenAISettingsServiceSavesAndDeletesAPIKey() async throws {
        let credentials = InMemoryCredentialStore()
        let service = OpenAISettingsService(credentialStore: credentials)

        let initialStatus = try await service.status()
        XCTAssertFalse(initialStatus.hasAPIKey)

        try await service.saveAPIKey("  test-key  ")
        let savedStatus = try await service.status()
        let savedSecret = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertTrue(savedStatus.hasAPIKey)
        XCTAssertEqual(savedSecret, "test-key")

        try await service.deleteAPIKey()
        let deletedStatus = try await service.status()
        XCTAssertFalse(deletedStatus.hasAPIKey)
    }

    func testOAuthConnectorReadinessProvidesSettingsCopyAndActionState() {
        XCTAssertEqual(OAuthConnectorLoginReadiness.connected.settingsStatusText, "已連線")
        XCTAssertEqual(OAuthConnectorLoginReadiness.readyToAuthorize.settingsStatusText, "可授權")
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsClientConfiguration.settingsStatusText, "需要 Client 設定")
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsReauthorization.settingsStatusText, "需要重新授權")

        let readyOption = OAuthConnectorLoginOption(
            integrationKey: "gmail-google-workspace",
            displayName: "Gmail / Google Workspace",
            providerKey: "google",
            readiness: .readyToAuthorize,
            defaultScopes: ["openid"],
            requiresBackendTokenExchange: true,
            accountDataBoundary: "Google scopes only."
        )
        let connectedOption = OAuthConnectorLoginOption(
            integrationKey: "github",
            displayName: "GitHub",
            providerKey: "github",
            readiness: .connected,
            defaultScopes: ["repo"],
            grantedScopes: ["repo"],
            requiresBackendTokenExchange: true,
            accountDataBoundary: "GitHub scopes only."
        )

        XCTAssertTrue(readyOption.canStartAuthorization)
        XCTAssertFalse(connectedOption.canStartAuthorization)
        XCTAssertEqual(connectedOption.settingsDetailText, "已授權 scopes: repo")
    }

    func testSettingsViewDefinesOAuthConnectorSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains("OAuth Connectors"))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.connectors""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).row""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).name""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).status""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).detail""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).backend-exchange""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).authorize""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.callback-url""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.preview-callback""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.callback-message""#))
        XCTAssertTrue(settingsView.contains("previewOAuthCallback"))
    }

    func testSettingsViewDefinesShortcutDemoSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)
        let shortcutDemosSection = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/SettingsShortcutDemosSection.swift"),
            encoding: .utf8
        )

        XCTAssertLessThan(settingsView.split(separator: "\n").count, 900)
        XCTAssertTrue(settingsView.contains("SettingsShortcutDemosSection("))
        XCTAssertFalse(settingsView.contains("private func shortcutDemoRow"))
        XCTAssertTrue(shortcutDemosSection.contains("struct SettingsShortcutDemosSection"))
        XCTAssertTrue(shortcutDemosSection.contains("ShortcutDemoCatalog.default.recipes"))
        XCTAssertTrue(shortcutDemosSection.contains("Shortcut Demos"))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demos""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id)""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id).input""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id).output""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id).sample""#))
    }

    func testSettingsViewDefinesLocalModelSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains("Local Models"))
        XCTAssertTrue(settingsView.contains(#""settings.models.local""#))
        XCTAssertTrue(settingsView.contains("Route Preference"))
        XCTAssertTrue(settingsView.contains(#""settings.models.preference""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.preference.\(preference.rawValue)""#))
        XCTAssertTrue(settingsView.contains(".accessibilityElement(children: .contain)"))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).row""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).status""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).download""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).select""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).delete""#))
        XCTAssertTrue(settingsView.contains("row.benchmarkSummaryText"))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).benchmark""#))
        XCTAssertTrue(settingsView.contains("private let localModelBenchmarkService: LocalModelBenchmarkService?"))
        XCTAssertTrue(settingsView.contains("runLocalModelBenchmark(row)"))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).benchmark-run""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).reply-check""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.benchmark-message""#))
        XCTAssertTrue(settingsView.contains("runLocalModelReplyCheck(row)"))
        XCTAssertTrue(settingsView.contains("請先下載"))
        XCTAssertTrue(settingsView.contains("refreshLocalModelCatalog"))
        XCTAssertTrue(settingsView.contains(#""settings.models.refresh-catalog""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.catalog-source""#))
    }

    func testSettingsViewDelegatesCompactModelsOnlyLayout() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsViewURL = root.appendingPathComponent("Kairo/Views/SettingsView.swift")
        let compactViewURL = root.appendingPathComponent("Kairo/Views/LocalModelsCompactView.swift")
        let settingsView = try String(contentsOf: settingsViewURL, encoding: .utf8)
        let compactView = try String(contentsOf: compactViewURL, encoding: .utf8)

        XCTAssertTrue(settingsView.contains("case .modelsOnly"))
        XCTAssertTrue(settingsView.contains("case .shortcutDemosOnly"))
        XCTAssertTrue(settingsView.contains("LocalModelsCompactView("))
        XCTAssertTrue(settingsView.contains("SettingsShortcutDemosSection()"))
        XCTAssertLessThan(settingsView.split(separator: "\n").count, 1_050)
        XCTAssertTrue(compactView.contains("struct LocalModelsCompactView"))
        XCTAssertTrue(compactView.contains(#""settings.models.screen""#))
        XCTAssertFalse(compactView.contains(#""settings.models.compact-list""#))
        XCTAssertTrue(compactView.contains(#""settings.models.selected-summary""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).manifest""#))
        XCTAssertTrue(compactView.contains("row.runtimeFitText"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).runtime-fit""#))
        XCTAssertTrue(compactView.contains("runtimePills(for: row)"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).runtime-pill.\(index)""#))
        XCTAssertTrue(compactView.contains("private let starterModelIDs = LocalModelCatalog.kairoStarterModelIDs"))
        XCTAssertFalse(compactView.contains("@State private var showsAllModelRows"))
        XCTAssertTrue(compactView.contains("@State private var pendingDownloadModelID: String?"))
        XCTAssertTrue(compactView.contains("downloadPreview(for: row)"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).download-preview""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).download-confirm""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).download-cancel""#))
        XCTAssertTrue(compactView.contains("Download requires explicit approval."))
        XCTAssertTrue(compactView.contains("ForEach(visibleModelRows)"))
        XCTAssertFalse(compactView.contains("ForEach(localModelStatus.settingsRows)"))
        XCTAssertTrue(compactView.contains("let starterIDs = Set(starterModelIDs)"))
        XCTAssertTrue(compactView.contains("localModelStatus.settingsRows.filter { starterIDs.contains($0.modelID) }"))
        XCTAssertTrue(compactView.contains("if trimmedModelRowCount > 0"))
        XCTAssertTrue(compactView.contains(#""settings.models.trimmed-note""#))
        XCTAssertFalse(compactView.contains(#""settings.models.show-more""#))
        XCTAssertFalse(compactView.contains("modelListToggleTitle"))
        XCTAssertTrue(compactView.contains("row.manifestTransparencyText"))
        XCTAssertTrue(compactView.contains("selectedModelSummaryText"))
        XCTAssertTrue(compactView.contains("downloadedModel"))
        XCTAssertTrue(compactView.contains("is downloaded. Select it to use local routing."))
        XCTAssertTrue(compactView.contains("Starter list: Qwen-first, then a few popular small models from kairo-models."))
        XCTAssertTrue(compactView.contains("compactRoutePreferenceMenu"))
        XCTAssertFalse(compactView.contains("Picker(\"Route Preference\""))
        XCTAssertTrue(compactView.contains("private var compactSectionTitleFont: Font { .system(size: 10, weight: .semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactSectionHeadingFont: Font { .system(size: 7, weight: .semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactModelNameFont: Font { .system(size: 7, weight: .semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactModelMetadataFont: Font { .system(size: 6) }"))
        XCTAssertTrue(compactView.contains("private var compactModelStatusFont: Font { .system(size: 6, weight: .semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactButtonLabelFont: Font { .system(size: 6, weight: .semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactControlValueFont: Font { .system(size: 8, weight: .semibold) }"))
        XCTAssertTrue(compactView.contains(#""Reply""#))
        XCTAssertFalse(compactView.contains(#""Reply Check""#))
        XCTAssertTrue(compactView.contains("GridItem(.adaptive(minimum: 52)"))
        XCTAssertTrue(compactView.contains(".lineLimit(1)"))
        XCTAssertTrue(compactView.contains(".lineLimit(2)"))
        XCTAssertTrue(compactView.contains(".imageScale(.small)"))
        XCTAssertTrue(compactView.contains(".background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))"))
        XCTAssertTrue(compactView.contains(".font(compactModelNameFont)"))
        XCTAssertTrue(compactView.contains(".font(compactModelMetadataFont)"))
        XCTAssertTrue(compactView.contains(".buttonStyle(.plain)"))
    }

    func testRootViewDefinesAutomationsRecipeCenterAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let automationsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/AutomationsView.swift"), encoding: .utf8)

        XCTAssertFalse(rootView.contains("TabView"))
        XCTAssertTrue(rootView.contains("GeometryReader"))
        XCTAssertTrue(rootView.contains("let safeAreaInsets = proxy.safeAreaInsets"))
        XCTAssertTrue(rootView.contains(#""root.shell""#))
        XCTAssertTrue(rootView.contains(#""root.safe-area-header""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.toggle""#))
        XCTAssertTrue(rootView.contains(#""root.drawer""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.close""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.\(section.rawValue)""#))
        XCTAssertTrue(rootView.contains("rootHeader(topInset: safeAreaInsets.top)"))
        XCTAssertTrue(rootView.contains("navigationMenu(safeAreaInsets: safeAreaInsets)"))
        XCTAssertTrue(rootView.contains("BriefingInboxView("))
        XCTAssertTrue(rootView.contains("MemoryCenterView(store: environment.memoryStore)"))
        XCTAssertTrue(rootView.contains(".presentationDetents([.medium, .large])"))
        XCTAssertTrue(rootView.contains(".padding(.top, max(topInset, 0)"))
        XCTAssertTrue(rootView.contains(".ignoresSafeArea(edges: .top)"))
        XCTAssertTrue(rootView.contains(#""root.menu.sheet""#))
        XCTAssertFalse(rootView.contains(".ignoresSafeArea(edges: .vertical)"))
        XCTAssertTrue(rootView.contains("case home"))
        XCTAssertTrue(rootView.contains("case chat"))
        XCTAssertTrue(rootView.contains("case memory"))
        XCTAssertTrue(rootView.contains("case skills"))
        XCTAssertTrue(rootView.contains("case shortcuts"))
        XCTAssertTrue(rootView.contains("case access"))
        XCTAssertTrue(rootView.contains("case models"))
        XCTAssertTrue(rootView.contains("case settings"))
        XCTAssertTrue(rootView.contains("AutomationsView("))
        XCTAssertTrue(rootView.contains("recipeStore: environment.kairoRecipeStore"))
        XCTAssertTrue(automationsView.contains("Kairo internal recipe"))
        XCTAssertTrue(automationsView.contains("does not create Apple Shortcuts"))
        XCTAssertTrue(automationsView.contains(#""automations.recipe-center""#))
        XCTAssertTrue(automationsView.contains(#""automations.list""#))
        XCTAssertTrue(automationsView.contains(#""automations.seed-samples""#))
        XCTAssertTrue(automationsView.contains(#""automations.message""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id)""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id).preview""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id).run""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id).toggle""#))
        XCTAssertTrue(automationsView.contains("Shortcut Templates"))
        XCTAssertTrue(automationsView.contains("ShortcutTemplateRegistry.default"))
        XCTAssertTrue(automationsView.contains("shortcutTemplateRegistry.manualInstallDisclaimer"))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-templates""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-template.disclaimer""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-template.\(template.identifier)""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-template.\(template.identifier).instructions""#))
    }

    func testStageOneProductRedesignDefinesMobileNativeShellContract() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let designSystem = try String(contentsOf: root.appendingPathComponent("Kairo/Views/KairoDesignSystem.swift"), encoding: .utf8)
        let actionPreview = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ActionPreviewView.swift"), encoding: .utf8)
        let chatView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatView.swift"), encoding: .utf8)

        XCTAssertTrue(designSystem.contains("enum KairoDesign"))
        XCTAssertTrue(designSystem.contains("struct KairoMark"))
        XCTAssertTrue(designSystem.contains("struct KairoStatusPill"))
        XCTAssertTrue(designSystem.contains("struct KairoActionRow"))
        XCTAssertTrue(rootView.contains("BriefingInboxView("))
        XCTAssertTrue(rootView.contains("KairoMark(size:"))
        XCTAssertTrue(rootView.contains(#""root.menu.sheet""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.toggle""#))
        XCTAssertTrue(rootView.contains("presentationDetents([.medium, .large])"))
        XCTAssertTrue(rootView.contains("case home"))
        XCTAssertTrue(rootView.contains("case memory"))
        XCTAssertFalse(rootView.contains("TabView"))
        XCTAssertTrue(chatView.contains("KairoBriefingStrip"))
        XCTAssertTrue(actionPreview.contains("Review before Kairo acts"))
        XCTAssertTrue(actionPreview.contains("Nothing changes until you confirm."))
    }

    func testBriefingInboxStaysSimpleForMobileUse() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)

        XCTAssertTrue(rootView.contains(#""home.primary-actions""#))
        XCTAssertTrue(rootView.contains(#""home.ask-kairo""#))
        XCTAssertTrue(rootView.contains(#""home.review-drafts""#))
        XCTAssertTrue(rootView.contains(#""home.memory""#))
        XCTAssertTrue(rootView.contains("Ready when you are"))
        XCTAssertTrue(rootView.contains("Start with one request."))
        XCTAssertFalse(rootView.contains(#""home.review-queue""#))
        XCTAssertFalse(rootView.contains(#""home.access""#))
        XCTAssertFalse(rootView.contains(#""home.automations""#))
        XCTAssertFalse(rootView.contains(#""home.models""#))
        XCTAssertFalse(rootView.contains(#""home.safety-pills""#))
        XCTAssertFalse(rootView.contains(".font(.largeTitle.bold())"))
    }

    func testKairoActionRowsUseQuietNativeLineIcons() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let designSystem = try String(contentsOf: root.appendingPathComponent("Kairo/Views/KairoDesignSystem.swift"), encoding: .utf8)

        XCTAssertTrue(designSystem.contains(".symbolRenderingMode(.hierarchical)"))
        XCTAssertTrue(designSystem.contains(".frame(width: 28, height: 28)"))
        XCTAssertFalse(designSystem.contains(".background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))"))
    }

    func testAutomationsViewSurfacesShortcutDemoNodeContracts() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let automationsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/AutomationsView.swift"), encoding: .utf8)

        XCTAssertTrue(automationsView.contains("ShortcutDemoCatalog.default.recipes"))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demos""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).input""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).output""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).preview-sample""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).preview-result""#))
        XCTAssertTrue(automationsView.contains("shortcutDemoPreviewMessages"))
        XCTAssertTrue(automationsView.contains("ShortcutDemoRecipeRunner"))
        XCTAssertTrue(automationsView.contains("previewShortcutDemo"))
        XCTAssertTrue(automationsView.contains("settingsInputSummary"))
        XCTAssertTrue(automationsView.contains("settingsOutputSummary"))
    }

    func testAutomationsViewUsesCompactFullScreenScrollLayout() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let automationsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/AutomationsView.swift"), encoding: .utf8)

        XCTAssertTrue(automationsView.contains("ScrollView"))
        XCTAssertTrue(automationsView.contains("automationSectionHeader"))
        XCTAssertTrue(automationsView.contains("automationSection("))
        XCTAssertTrue(automationsView.contains(".scrollIndicators(.hidden)"))
        XCTAssertTrue(automationsView.contains("Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea()"))
        XCTAssertFalse(automationsView.contains("Form {"))
        XCTAssertFalse(automationsView.contains("automationPanel"))
    }

    func testChatViewDefinesPolishedComposerAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let chatView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatView.swift"), encoding: .utf8)
        let chatActionStripsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatActionStrips.swift"), encoding: .utf8)
        let routeBarView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatProviderRouteBar.swift"), encoding: .utf8)

        XCTAssertTrue(chatView.contains(#""chat.composer.surface""#))
        XCTAssertTrue(chatView.contains("ChatProviderRouteBar("))
        XCTAssertLessThan(chatView.split(separator: "\n").count, 520)
        XCTAssertFalse(chatView.contains("struct ProposedActionsStrip"))
        XCTAssertFalse(chatView.contains("struct ToolCandidatesStrip"))
        XCTAssertTrue(chatActionStripsView.contains("struct ProposedActionsStrip"))
        XCTAssertTrue(chatActionStripsView.contains("struct ToolCandidatesStrip"))
        XCTAssertTrue(routeBarView.contains("struct ChatProviderRouteBar"))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.title""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.detail""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.badge""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.warning""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.preference""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.preference.\(preference.rawValue)""#))
        XCTAssertTrue(routeBarView.contains("preference.chatControlTitle"))
        XCTAssertTrue(chatView.contains(#""chat.composer.input-shell""#))
        XCTAssertTrue(chatView.contains(#""chat.composer.text""#))
        XCTAssertTrue(chatView.contains(#""chat.composer.send""#))
        XCTAssertTrue(chatView.contains("minHeight: 52"))
        XCTAssertTrue(chatView.contains("RoundedRectangle(cornerRadius: 22"))
        XCTAssertTrue(chatView.contains("shadow(color:"))
        XCTAssertTrue(chatView.contains(".textSelection(.enabled)"))
        XCTAssertTrue(chatView.contains(#""chat.message.copy.\(message.id.uuidString)""#))
        XCTAssertTrue(chatView.contains(#""chat.message.reply.\(message.id.uuidString)""#))
        XCTAssertTrue(chatView.contains(#""chat.reply-preview""#))
        XCTAssertTrue(chatView.contains("replyToMessage"))
        XCTAssertTrue(chatActionStripsView.contains("actionRiskSummary(for: action)"))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.proposed-action.\(action.kind.rawValue).risk""#))
        XCTAssertTrue(chatActionStripsView.contains("Needs confirmation"))
        XCTAssertTrue(chatActionStripsView.contains("candidate.handoffSummary"))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).summary""#))
        XCTAssertTrue(chatActionStripsView.contains("toolRiskSummary(for: candidate)"))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).risk""#))
    }

    @MainActor
    func testChatViewModelLoadsProviderRouteStatusFromLocalModelSettings() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            localModelSettingsService: service
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.providerRouteStatus.title, "Route: Prefer Local")
        XCTAssertTrue(viewModel.providerRouteStatus.detail.contains("Qwen Small Test"))
        XCTAssertNil(viewModel.providerRouteStatus.warning)

        await viewModel.setProviderRoutePreference(.preferCloud)

        XCTAssertEqual(viewModel.providerRouteStatus.title, "Route: Prefer Cloud")
        XCTAssertEqual(viewModel.providerRouteStatus.badge, "Cloud")
        XCTAssertEqual(viewModel.providerRouteStatus.preference, .preferCloud)
        let persistedStatus = await service.status()
        XCTAssertEqual(persistedStatus.preference, .preferCloud)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testChatViewModelComposesReplyReferenceWithoutPastingFullMessage() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
        )
        let longMessage = ChatMessage(
            role: .assistant,
            text: String(repeating: "This is a long assistant answer. ", count: 12)
        )

        viewModel.replyToMessage(longMessage)
        viewModel.composerText = "I want to reply briefly."
        await viewModel.sendComposerMessage()

        let userMessage = try XCTUnwrap(viewModel.currentThread.messages.first { $0.role == .user })
        XCTAssertTrue(userMessage.text.contains("Replying to"))
        XCTAssertTrue(userMessage.text.contains("I want to reply briefly."))
        XCTAssertLessThan(userMessage.text.count, longMessage.text.count)
        XCTAssertNil(viewModel.replyTarget)
    }

    func testPermissionHubDefinesHomeKitDemoAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let permissionHubView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/PermissionHubView.swift"), encoding: .utf8)

        XCTAssertTrue(permissionHubView.contains("Skill Manager"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manager""#))
        XCTAssertTrue(permissionHubView.contains("skillSearchText"))
        XCTAssertTrue(permissionHubView.contains("filteredSkills"))
        XCTAssertTrue(permissionHubView.contains("skillMatchesSearch"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.search""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.search.summary""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.name""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.summary""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.button""#))
        XCTAssertTrue(permissionHubView.contains("createUserSkillDraft"))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id)""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).manage""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).install""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).disable""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).enable""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).remove""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-import""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-import.text""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-import.button""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.message""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.compatibility""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.compatibility.\(issue.kind.rawValue)""#))
        XCTAssertTrue(permissionHubView.contains("manifestInstallPreview.compatibilityReport.isInstallable"))
        XCTAssertTrue(permissionHubView.contains("AgentSkillInstallError.compatibilityBlocked"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.confirm""#))
        XCTAssertTrue(permissionHubView.contains("try await skillManagerService.previewInstall(jsonString: manifestImportText)"))
        XCTAssertTrue(permissionHubView.contains("try await skillManagerService.install(manifest: manifestInstallPreview.manifest)"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.marketplace-refresh""#))
        XCTAssertTrue(permissionHubView.contains("try await marketplaceCatalogService.fetchCatalog()"))
        XCTAssertTrue(permissionHubView.contains("skillCatalog.mergingMarketplaceCatalog(remoteCatalog.catalog)"))
        XCTAssertTrue(permissionHubView.contains("try await marketplaceCatalogService.fetchManifest(for: skill)"))
        XCTAssertTrue(permissionHubView.contains("try await skillManagerService.previewInstall(manifest: manifest)"))
        XCTAssertTrue(permissionHubView.contains("HomeKit Control Demos"))
        XCTAssertTrue(permissionHubView.contains(#""access.homekit.demos""#))
        XCTAssertTrue(permissionHubView.contains(#""access.homekit.demo.\(recipe.id)""#))
        XCTAssertTrue(permissionHubView.contains(#""access.homekit.demo.\(recipe.id).confirm""#))
    }

    func testKairoEnvironmentWiresFileBackedSkillManagerIntoAccessSurface() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let environmentSource = try String(contentsOf: root.appendingPathComponent("Kairo/Services/KairoEnvironment.swift"), encoding: .utf8)
        let rootViewSource = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let permissionHubSource = try String(contentsOf: root.appendingPathComponent("Kairo/Views/PermissionHubView.swift"), encoding: .utf8)

        XCTAssertTrue(environmentSource.contains("agentSkillManagerService: AgentSkillManagerService?"))
        XCTAssertTrue(environmentSource.contains("kairoRecipeStore: any KairoRecipeStore"))
        XCTAssertTrue(environmentSource.contains("FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)"))
        XCTAssertTrue(environmentSource.contains("FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)"))
        XCTAssertTrue(environmentSource.contains("AgentSkillManagerService("))
        XCTAssertTrue(environmentSource.contains("store: agentSkillStore"))
        XCTAssertTrue(environmentSource.contains("AgentSkillMarketplaceCatalogService.defaultStandaloneRepository"))
        XCTAssertTrue(rootViewSource.contains("AutomationsView("))
        XCTAssertTrue(rootViewSource.contains("recipeStore: environment.kairoRecipeStore"))
        XCTAssertTrue(rootViewSource.contains("PermissionHubView("))
        XCTAssertTrue(rootViewSource.contains("skillManagerService: environment.agentSkillManagerService"))
        XCTAssertTrue(rootViewSource.contains("marketplaceCatalogService: environment.agentSkillMarketplaceCatalogService"))
        XCTAssertTrue(environmentSource.contains("localModelCatalogService"))
        XCTAssertTrue(environmentSource.contains("LocalModelCatalogService.defaultStandaloneRepository"))
        XCTAssertTrue(rootViewSource.contains("localModelCatalogService: environment.localModelCatalogService"))
        XCTAssertTrue(environmentSource.contains("localModelBenchmarkService"))
        XCTAssertTrue(environmentSource.contains("FileBackedLocalModelBenchmarkStore(fileURL: paths.localModelBenchmarkResultsURL)"))
        XCTAssertTrue(rootViewSource.contains("localModelBenchmarkService: environment.localModelBenchmarkService"))
        XCTAssertTrue(environmentSource.contains("localModelReplyCheckService"))
        XCTAssertTrue(environmentSource.contains("LocalModelReplyCheckService("))
        XCTAssertTrue(rootViewSource.contains("localModelReplyCheckService: environment.localModelReplyCheckService"))
        XCTAssertTrue(environmentSource.contains("LocalModelRoutingAIProvider("))
        XCTAssertTrue(environmentSource.contains("localModelSettingsService: localModelSettingsService"))
        XCTAssertTrue(rootViewSource.contains("mode: .modelsOnly"))
        XCTAssertTrue(rootViewSource.contains("settingsMode: SettingsViewMode = .all"))
        XCTAssertTrue(permissionHubSource.contains("private let skillManagerService: AgentSkillManagerService?"))
        XCTAssertTrue(permissionHubSource.contains("private let marketplaceCatalogService: AgentSkillMarketplaceCatalogService?"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.catalog()"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.disableSkill(id: skill.id)"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.enableSkill(id: skill.id)"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.removeSkill(id: skill.id)"))
    }

    func testKairoEnvironmentProvidesDeterministicUITestingSkillManagerAndMarketplace() async throws {
        let environment = try await KairoEnvironment.uiTesting(resetPersistentState: true)
        let skillManagerService = try XCTUnwrap(environment.agentSkillManagerService)
        let marketplaceCatalogService = try XCTUnwrap(environment.agentSkillMarketplaceCatalogService)
        let modelCatalogService = try XCTUnwrap(environment.localModelCatalogService)

        var catalog = try await skillManagerService.catalog()
        XCTAssertEqual(catalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .installed)

        let disabled = try await skillManagerService.disableSkill(id: "shortcut-save-shared-text")
        XCTAssertEqual(disabled?.installationStatus, .disabled)

        let reloadedEnvironment = try await KairoEnvironment.uiTesting(resetPersistentState: false)
        let reloadedSkillManagerService = try XCTUnwrap(reloadedEnvironment.agentSkillManagerService)
        catalog = try await reloadedSkillManagerService.catalog()
        XCTAssertEqual(catalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .disabled)
        let reloadedRecipes = try await reloadedEnvironment.kairoRecipeStore.listRecipes()
        XCTAssertTrue(reloadedRecipes.isEmpty)

        let remoteCatalog = try await marketplaceCatalogService.fetchCatalog()
        let weatherSkill = try XCTUnwrap(remoteCatalog.catalog.skill(id: "marketplace-weather-briefing"))
        let manifest = try await marketplaceCatalogService.fetchManifest(for: weatherSkill)
        let preview = try await skillManagerService.previewInstall(manifest: manifest)
        let qwenWorkflowSkill = try XCTUnwrap(remoteCatalog.catalog.skill(id: "marketplace-qwen-oauth-workflow"))
        let qwenWorkflowManifest = try await marketplaceCatalogService.fetchManifest(for: qwenWorkflowSkill)
        let qwenWorkflowPreview = try await skillManagerService.previewInstall(manifest: qwenWorkflowManifest)

        XCTAssertEqual(remoteCatalog.sourceRepository.absoluteString, "https://github.com/easonwumac/kairo-skills")
        XCTAssertEqual(weatherSkill.downloadURL?.absoluteString, "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json")
        XCTAssertEqual(preview.summary, "Install Weather Briefing 2.1.0.")
        XCTAssertEqual(qwenWorkflowPreview.compatibilityReport.blockingIssues.map(\.kind), [.missingOAuthProvider, .missingLocalModel])
        XCTAssertTrue(qwenWorkflowPreview.summary.contains("Blocked Qwen OAuth Workflow"))

        let modelCatalog = try await modelCatalogService.fetchCatalog()
        XCTAssertEqual(modelCatalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(
            modelCatalog.availableModels(minimumSafetyPolicyVersion: modelCatalog.minimumSafetyPolicyVersion).count,
            LocalModelCatalog.kairoDefault.availableModels(
                minimumSafetyPolicyVersion: LocalModelCatalog.kairoDefault.minimumSafetyPolicyVersion
            ).count
        )

        let expandedEnvironment = try await KairoEnvironment.uiTesting(
            resetPersistentState: true,
            seedExpandedLocalModelCatalog: true
        )
        XCTAssertEqual(expandedEnvironment.localModelCatalog.availableModels(
            minimumSafetyPolicyVersion: expandedEnvironment.localModelCatalog.minimumSafetyPolicyVersion
        ).map(\.id), [
            "qwen3-5-0-8b-q4-k-m",
            "llama3-2-1b-instruct-q4-k-m",
            "remote-catalog-test-model-q4-k-m"
        ])
    }

    func testKairoPathsBuildsApplicationSupportMemoryURL() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.memoryStoreURL.lastPathComponent, "memory-store.json")
        XCTAssertEqual(paths.memoryStoreURL.deletingLastPathComponent().lastPathComponent, "KairoTests")
        XCTAssertEqual(paths.shareIngestionQueueURL.lastPathComponent, "share-ingestion-queue.json")
        XCTAssertEqual(paths.sharedFilesDirectory.lastPathComponent, "SharedFiles")
        XCTAssertEqual(paths.localModelsDirectory.lastPathComponent, "LocalModels")
        XCTAssertEqual(paths.localModelInstallRegistryURL.lastPathComponent, "install-registry.json")
        XCTAssertEqual(paths.localModelSettingsURL.lastPathComponent, "settings.json")
        XCTAssertEqual(paths.agentSkillStoreURL.lastPathComponent, "agent-skills.json")
        XCTAssertEqual(paths.agentSkillStoreURL.deletingLastPathComponent().lastPathComponent, "Skills")
        XCTAssertEqual(paths.kairoRecipeStoreURL.lastPathComponent, "kairo-recipes.json")
        XCTAssertEqual(paths.kairoRecipeStoreURL.deletingLastPathComponent().lastPathComponent, "Recipes")
        XCTAssertFalse(paths.usesAppGroup)
    }

    func testKairoPathsUsesInjectedAppGroupContainerWhenAvailable() {
        let groupRoot = FileManager.default.temporaryDirectory.appendingPathComponent("KairoGroup", isDirectory: true)
        let paths = KairoPaths(
            appName: "KairoTests",
            appGroupIdentifier: "group.app.kairo.shared",
            appGroupContainerProvider: { identifier in
                identifier == "group.app.kairo.shared" ? groupRoot : nil
            }
        )

        XCTAssertTrue(paths.usesAppGroup)
        XCTAssertEqual(paths.applicationSupportDirectory, groupRoot.appendingPathComponent("KairoTests", isDirectory: true))
        XCTAssertEqual(paths.shareIngestionQueueURL.deletingLastPathComponent(), paths.applicationSupportDirectory)
    }

    func testKairoSharedAppStorageBuildsCanonicalAppGroupPaths() {
        let groupRoot = FileManager.default.temporaryDirectory.appendingPathComponent("KairoSharedGroup", isDirectory: true)
        let paths = KairoSharedAppStorage.paths(appGroupContainerProvider: { identifier in
            identifier == KairoSharedAppStorage.appGroupIdentifier ? groupRoot : nil
        })

        XCTAssertEqual(KairoSharedAppStorage.appGroupIdentifier, "group.app.kairo.shared")
        XCTAssertTrue(paths.usesAppGroup)
        XCTAssertEqual(paths.applicationSupportDirectory, groupRoot.appendingPathComponent("Kairo", isDirectory: true))
        XCTAssertEqual(paths.shareIngestionQueueURL, groupRoot.appendingPathComponent("Kairo", isDirectory: true).appendingPathComponent("share-ingestion-queue.json"))
        XCTAssertEqual(paths.sharedFilesDirectory, groupRoot.appendingPathComponent("Kairo", isDirectory: true).appendingPathComponent("SharedFiles", isDirectory: true))
    }

    func testUITestScenarioCatalogCoversCoreAppSmokeFlows() {
        let catalog = UITestScenarioCatalog.default

        XCTAssertEqual(catalog.scenarios.map(\.id), [
            "launch-drawer",
            "chat-send",
            "chat-message-copy-reply",
            "chat-tool-preview",
            "chat-shortcut-tool-candidate",
            "chat-notification-confirmation",
            "chat-reminder-confirmation",
            "chat-calendar-confirmation",
            "chat-contact-confirmation",
            "chat-email-draft-confirmation",
            "chat-map-directions-confirmation",
            "chat-messages-handoff-confirmation",
            "chat-phone-handoff-confirmation",
            "automations-recipe-center",
            "automations-shortcut-templates",
            "automations-shortcut-demo-io",
            "settings-api-key-status",
            "settings-oauth-connectors",
            "settings-local-model-benchmark",
            "settings-local-model-expanded-catalog",
            "settings-local-model-reply-check",
            "settings-shortcut-demo-io",
            "access-homekit-demos"
        ])
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.safe-area-header") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.toggle") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.chat") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.skills") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.shortcuts") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.access") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.models") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.settings") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.history.thread") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.new") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.provider-route") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.provider-route.title") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.provider-route.detail") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.provider-route.badge") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.provider-route.preference") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.provider-route.preference.preferCloud") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.composer.text") == true)
        let chatCopyReplyScenarioIdentifiers = catalog.scenario(id: "chat-message-copy-reply")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(chatCopyReplyScenarioIdentifiers.contains("chat.message.copy."))
        XCTAssertTrue(chatCopyReplyScenarioIdentifiers.contains("chat.message.reply."))
        XCTAssertTrue(chatCopyReplyScenarioIdentifiers.contains("chat.reply-preview"))
        XCTAssertTrue(catalog.scenario(id: "chat-tool-preview")?.requiredAccessibilityIdentifiers.contains("chat.proposed-actions") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-tool-preview")?.requiredAccessibilityIdentifiers.contains("chat.proposed-action.controlHome") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-tool-preview")?.requiredAccessibilityIdentifiers.contains("chat.proposed-action.controlHome.risk") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidates") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidate.shortcut-save-shared-text") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidate.shortcut-save-shared-text.summary") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidate.shortcut-save-shared-text.risk") == true)
        let notificationScenarioIdentifiers = catalog.scenario(id: "chat-notification-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.proposed-action.sendNotification"))
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.action-result"))
        let reminderScenarioIdentifiers = catalog.scenario(id: "chat-reminder-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.proposed-action.createReminderDraft"))
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.action-result"))
        let calendarScenarioIdentifiers = catalog.scenario(id: "chat-calendar-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.proposed-action.createCalendarDraft"))
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.action-result"))
        let contactScenarioIdentifiers = catalog.scenario(id: "chat-contact-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.proposed-action.createContactDraft"))
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.action-result"))
        let emailScenarioIdentifiers = catalog.scenario(id: "chat-email-draft-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.proposed-action.composeEmailDraft"))
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.action-result"))
        let mapScenarioIdentifiers = catalog.scenario(id: "chat-map-directions-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.proposed-action.openMapDirections"))
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.action-result"))
        let messageScenarioIdentifiers = catalog.scenario(id: "chat-messages-handoff-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.proposed-action.openMessageHandoff"))
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.action-result"))
        let phoneScenarioIdentifiers = catalog.scenario(id: "chat-phone-handoff-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.proposed-action.openPhoneCallHandoff"))
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.action-result"))
        let automationsScenarioIdentifiers = catalog.scenario(id: "automations-recipe-center")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(automationsScenarioIdentifiers.contains("root.drawer.shortcuts"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe-center"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.seed-samples"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.list"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing.preview"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing.run"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing.toggle"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.message"))
        let automationsShortcutScenarioIdentifiers = catalog.scenario(id: "automations-shortcut-templates")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("root.drawer.shortcuts"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-templates"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-template.disclaimer"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-template.run-kairo-recipe-shortcut"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-template.run-kairo-recipe-shortcut.instructions"))
        let automationsShortcutDemoScenarioIdentifiers = catalog.scenario(id: "automations-shortcut-demo-io")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("root.drawer.shortcuts"))
        XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demos"))
        for recipe in ShortcutDemoCatalog.default.recipes {
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id)"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).input"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).output"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).sample"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).preview-sample"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).preview-result"), recipe.id)
        }
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.openai.api-key-status") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.oauth.connectors") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.shortcuts.demos") == true)
        let oauthScenarioIdentifiers = catalog.scenario(id: "settings-oauth-connectors")?.requiredAccessibilityIdentifiers ?? []
        for providerKey in ["google", "microsoft", "notion", "slack", "chatgpt", "github"] {
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).row"), providerKey)
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).name"), providerKey)
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).status"), providerKey)
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).detail"), providerKey)
        }
        let benchmarkScenarioIdentifiers = catalog.scenario(id: "settings-local-model-benchmark")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.local"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.benchmark"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.download-preview"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.download-confirm"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.download-cancel"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.benchmark-message"))
        let expandedModelsScenarioIdentifiers = catalog.scenario(id: "settings-local-model-expanded-catalog")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(expandedModelsScenarioIdentifiers.contains("settings.models.llama3-2-1b-instruct-q4-k-m.name"))
        XCTAssertTrue(expandedModelsScenarioIdentifiers.contains("settings.models.trimmed-note"))
        let replyCheckScenarioIdentifiers = catalog.scenario(id: "settings-local-model-reply-check")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(replyCheckScenarioIdentifiers.contains("settings.models.local"))
        XCTAssertTrue(replyCheckScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.reply-check"))
        XCTAssertTrue(replyCheckScenarioIdentifiers.contains("settings.models.benchmark-message"))
        let shortcutDemoScenarioIdentifiers = catalog.scenario(id: "settings-shortcut-demo-io")?.requiredAccessibilityIdentifiers ?? []
        for recipe in ShortcutDemoCatalog.default.recipes {
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id)"), recipe.id)
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id).input"), recipe.id)
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id).output"), recipe.id)
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id).sample"), recipe.id)
        }
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manager") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.local-create.name") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.local-create.summary") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.local-create.button") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.user-ui-created-skill") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.user-ui-created-skill.enable") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.marketplace-refresh") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.search") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.search.summary") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-import") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-import.text") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-import.button") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-screenshot-to-reminders") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-reply-draft-from-shared-text") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-email-triage") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-meeting-prep-brief") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-generic-node-runner") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text.disable") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text.enable") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.marketplace-weather-briefing.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.marketplace-qwen-oauth-workflow.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.message") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview.compatibility") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview.confirm") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.homekit-front-door-lock") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.homekit-front-door-lock.manage") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demos") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.evening-scene") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.front-door-lock") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.front-door-lock.confirm") == true)
    }

    func testXcodeProjectDefinesKairoUITestTargetAndSmokeTestFile() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let projectYAML = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let appInfoPlist = try String(contentsOf: root.appendingPathComponent("Config/KairoApp-Info.plist"), encoding: .utf8)
        let smokeTestURL = root.appendingPathComponent("KairoUITests/KairoAppSmokeUITests.swift")
        let helperTestURL = root.appendingPathComponent("KairoUITests/KairoAppSmokeUITests+Helpers.swift")
        let smokeTest = try String(contentsOf: smokeTestURL, encoding: .utf8)
        let helperTest = try String(contentsOf: helperTestURL, encoding: .utf8)
        let uiTestSources = smokeTest + "\n" + helperTest
        let projectFile = try String(contentsOf: root.appendingPathComponent("Kairo.xcodeproj/project.pbxproj"), encoding: .utf8)
        let actionPreviewView = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/ActionPreviewView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(projectYAML.contains("KairoUITests:"))
        XCTAssertTrue(projectYAML.contains("type: bundle.ui-testing"))
        XCTAssertTrue(projectYAML.contains("GENERATE_INFOPLIST_FILE"))
        XCTAssertTrue(projectYAML.contains("target: KairoApp"))
        XCTAssertTrue(projectFile.contains("KairoAppSmokeUITests+Helpers.swift in Sources"))
        XCTAssertTrue(appInfoPlist.contains("<key>CFBundleURLTypes</key>"))
        XCTAssertTrue(appInfoPlist.contains("<key>UILaunchScreen</key>"))
        XCTAssertTrue(appInfoPlist.contains("<string>kairo</string>"))
        XCTAssertTrue(appInfoPlist.contains("<key>NSCalendarsFullAccessUsageDescription</key>"))
        XCTAssertTrue(appInfoPlist.contains("<key>NSRemindersFullAccessUsageDescription</key>"))
        XCTAssertTrue(appInfoPlist.contains("<key>NSContactsUsageDescription</key>"))
        XCTAssertTrue(uiTestSources.contains("KairoAppSmokeUITests"))
        XCTAssertTrue(helperTest.contains("extension KairoAppSmokeUITests"))
        XCTAssertTrue(uiTestSources.contains("testSettingsLocalModelCatalogListsDownloadableModels"))
        XCTAssertTrue(uiTestSources.contains("testSettingsLocalModelDownloadRequiresConfirmationPreview"))
        XCTAssertTrue(uiTestSources.contains("testSettingsExpandedModelCatalogKeepsPopularStarterRowsVisible"))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsQwenBenchmarkFlowRequiresDownload"))
        XCTAssertTrue(uiTestSources.contains("testSettingsRunsInstalledLocalModelReplyCheck"))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.\(modelID).download-preview""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.\(modelID).download-confirm""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.\(modelID).download-cancel""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.qwen3-5-0-8b-q4-k-m.reply-check""#))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-settings-shortcut-demos-only"))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.models.show-more").exists)"#))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.models.remote-catalog-test-model-q4-k-m.name").exists)"#))
        XCTAssertTrue(uiTestSources.contains("請先下載 Qwen3.5 0.8B Q4_K_M 後再跑 benchmark。"))
        XCTAssertTrue(uiTestSources.contains("Local model reply is alive."))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-installed-local-model"))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-expanded-local-model-catalog"))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsOAuthConnectorReadinessAndBoundaries"))
        XCTAssertTrue(uiTestSources.contains("testSettingsPreviewsOAuthCallbackWithoutLeakingCode"))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmNotificationAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.controlHome.risk""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.tool-candidate.shortcut-save-shared-text.risk""#))
        XCTAssertTrue(uiTestSources.contains("Needs confirmation"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.sendNotification""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.action-preview""#))
        XCTAssertTrue(uiTestSources.contains(#"findButton(labeled: "Confirm""#))
        XCTAssertTrue(actionPreviewView.contains(#""chat.action.confirm""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.action-result""#))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmReminderAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.createReminderDraft""#))
        XCTAssertTrue(uiTestSources.contains("Created reminder."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmCalendarAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.createCalendarDraft""#))
        XCTAssertTrue(uiTestSources.contains("Created calendar event."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmContactAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.createContactDraft""#))
        XCTAssertTrue(uiTestSources.contains("Created contact."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmEmailDraftHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.composeEmailDraft""#))
        XCTAssertTrue(uiTestSources.contains("Prepared email draft handoff."))
        XCTAssertTrue(actionPreviewView.contains("tel: opens Phone visibly; the call still requires user action."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmMapDirectionsHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openMapDirections""#))
        XCTAssertTrue(uiTestSources.contains("Prepared Apple Maps directions handoff."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmMessagesHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openMessageHandoff""#))
        XCTAssertTrue(uiTestSources.contains("Prepared Messages handoff."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmPhoneCallHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openPhoneCallHandoff""#))
        XCTAssertTrue(uiTestSources.contains("Prepared phone call handoff."))
        XCTAssertTrue(actionPreviewView.contains("Safari opens visibly; Kairo does not browse or scrape pages silently."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmWebSearchHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openWebSearchHandoff""#))
        XCTAssertTrue(uiTestSources.contains("Prepared Safari web search handoff."))
        XCTAssertTrue(uiTestSources.contains("testAutomationsRecipeCenterPreviewsRunsAndTogglesInternalRecipe"))
        XCTAssertTrue(uiTestSources.contains("testAutomationsShowsShortcutTemplatesRequireUserApproval"))
        XCTAssertTrue(uiTestSources.contains(#""root.drawer.shortcuts""#))
        XCTAssertTrue(uiTestSources.contains(#""root.drawer.skills""#))
        XCTAssertTrue(uiTestSources.contains(#""root.drawer.models""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.seed-samples""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe.daily-briefing.preview""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe.daily-briefing.run""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe.daily-briefing.toggle""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.shortcut-templates""#))
        XCTAssertTrue(uiTestSources.contains("Apple Shortcuts installation requires user approval"))
        XCTAssertTrue(uiTestSources.contains("Run Kairo Recipe Shortcut"))
        XCTAssertTrue(uiTestSources.contains("Recipe ID"))
        XCTAssertTrue(uiTestSources.contains("Kairo internal recipe"))
        XCTAssertTrue(uiTestSources.contains("does not create Apple Shortcuts"))
        XCTAssertTrue(uiTestSources.contains(#""settings.oauth.callback-url""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.oauth.preview-callback""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.oauth.callback-message""#))
        XCTAssertTrue(uiTestSources.contains("sample-sensitive-code"))
        XCTAssertTrue(uiTestSources.contains("authorization code received"))
        XCTAssertTrue(uiTestSources.contains(#"providerKey: "google""#))
        XCTAssertTrue(uiTestSources.contains("Gmail / Google Workspace"))
        XCTAssertTrue(uiTestSources.contains(#"providerKey: "chatgpt""#))
        XCTAssertTrue(uiTestSources.contains("需要 Client 設定"))
        XCTAssertTrue(uiTestSources.contains("需要後端 token exchange。"))
        XCTAssertTrue(uiTestSources.contains("Only pages/databases selected during Notion authorization may be read or written."))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsShortcutDemoInputOutputContracts"))
        let settingsShortcutDemoStart = try XCTUnwrap(
            smokeTest.range(of: "func testSettingsShowsShortcutDemoInputOutputContracts()")?.lowerBound
        )
        let settingsShortcutDemoEnd = try XCTUnwrap(
            smokeTest.range(
                of: "func testShortcutsSurfaceShowsNodeDemoContracts()",
                range: settingsShortcutDemoStart..<smokeTest.endIndex
            )?.lowerBound
        )
        let settingsShortcutDemoTest = String(smokeTest[settingsShortcutDemoStart..<settingsShortcutDemoEnd])
        XCTAssertTrue(settingsShortcutDemoTest.contains(#"relaunchForUITesting(initialSection: "settings", settingsShortcutDemosOnly: true)"#))
        XCTAssertTrue(settingsShortcutDemoTest.contains(#"id: "phone-call-handoff""#))
        XCTAssertFalse(settingsShortcutDemoTest.contains("assertPrimaryDrawerItemsExist()"))
        XCTAssertFalse(settingsShortcutDemoTest.contains(#"selectDrawerSection(identifier: "root.drawer.settings""#))

        let shortcutsSurfaceStart = try XCTUnwrap(
            smokeTest.range(of: "func testShortcutsSurfaceShowsNodeDemoContracts()")?.lowerBound
        )
        let shortcutsSurfaceEnd = try XCTUnwrap(
            smokeTest.range(
                of: "func testSettingsShowsOAuthConnectorReadinessAndBoundaries()",
                range: shortcutsSurfaceStart..<smokeTest.endIndex
            )?.lowerBound
        )
        let shortcutsSurfaceTest = String(smokeTest[shortcutsSurfaceStart..<shortcutsSurfaceEnd])
        XCTAssertTrue(shortcutsSurfaceTest.contains(#"relaunchForUITesting(initialSection: "shortcuts")"#))
        XCTAssertFalse(shortcutsSurfaceTest.contains("assertPrimaryDrawerItemsExist()"))
        XCTAssertFalse(shortcutsSurfaceTest.contains(#"selectDrawerSection(identifier: "root.drawer.shortcuts""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.shortcut-demo.generic-node-runner.preview-sample""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.shortcut-demo.generic-node-runner.preview-result""#))
        XCTAssertTrue(uiTestSources.contains("Daily Briefing"))
        XCTAssertTrue(uiTestSources.contains("Save Shared Text"))
        XCTAssertTrue(uiTestSources.contains("Phone Call Handoff"))
        XCTAssertTrue(uiTestSources.contains("Generic Node Runner"))
        XCTAssertTrue(uiTestSources.contains("1 step: preparePhoneCallHandoff"))
        XCTAssertTrue(uiTestSources.contains("Output: fields.phoneCallHandoffCount, fields.phoneCallNumber, fields.phoneCallRequiresConfirmation"))
        XCTAssertTrue(uiTestSources.contains("Input: nodeKind, inputJSON"))
        XCTAssertTrue(uiTestSources.contains("Output: outputJSON, displayText, fields.taskCount, fields.chainText"))
        XCTAssertTrue(uiTestSources.contains("Input: text, sourceName, variables"))
        XCTAssertTrue(uiTestSources.contains("Output: memoryID, fields.taskCount, tasks, fields.chainText"))
        XCTAssertTrue(uiTestSources.contains("settings.models.refresh-catalog"))
        XCTAssertTrue(uiTestSources.contains("github.com/easonwumac/kairo-models"))
        XCTAssertTrue(uiTestSources.contains("chat.history.thread"))
        XCTAssertTrue(uiTestSources.contains("chat.new"))
        XCTAssertTrue(uiTestSources.contains("testChatMessageReplyPreviewAndCopyControlsExist"))
        XCTAssertTrue(uiTestSources.contains(#""chat.provider-route""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.provider-route.title""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.provider-route.detail""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.provider-route.badge""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.provider-route.preference""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.provider-route.preference.preferCloud""#))
        XCTAssertTrue(uiTestSources.contains("Route: Automatic"))
        XCTAssertTrue(uiTestSources.contains("Route: Prefer Cloud"))
        XCTAssertTrue(uiTestSources.contains("chat.composer.text"))
        XCTAssertTrue(uiTestSources.contains("chat.reply-preview"))
        XCTAssertTrue(uiTestSources.contains("chat.message.copy."))
        XCTAssertTrue(uiTestSources.contains("chat.message.reply."))
        XCTAssertTrue(uiTestSources.contains("testAccessShowsHomeKitSecurityDevicePreview"))
        XCTAssertTrue(uiTestSources.contains(#""access.homekit.demo.front-door-lock.confirm""#))
        XCTAssertTrue(uiTestSources.contains("Confirm in Kairo before any HomeKit security-device write."))
        XCTAssertTrue(uiTestSources.contains("settings.openai.api-key-status"))
        XCTAssertTrue(uiTestSources.contains("settings.oauth.connectors"))
        XCTAssertTrue(uiTestSources.contains("settings.shortcuts.demos"))
        XCTAssertTrue(uiTestSources.contains("settings.models.local"))
        for displayName in [
            "Qwen3.5 0.8B Q4_K_M",
            "Llama 3.2 1B Instruct Q4_K_M"
        ] {
            XCTAssertTrue(uiTestSources.contains(displayName), displayName)
        }
        XCTAssertTrue(uiTestSources.contains(#"downloadIdentifier: "settings.models.\(localModel.0).download""#))
        XCTAssertTrue(uiTestSources.contains("可下載"))
        XCTAssertTrue(uiTestSources.contains("Download"))
        XCTAssertTrue(uiTestSources.contains("access.skills.marketplace-refresh"))
        XCTAssertTrue(uiTestSources.contains("access.skills.manifest-import"))
        XCTAssertTrue(uiTestSources.contains("access.skills.manifest-import.text"))
        XCTAssertTrue(uiTestSources.contains("access.skills.manifest-import.button"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-save-shared-text"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-screenshot-to-reminders"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-reply-draft-from-shared-text"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-email-triage"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-meeting-prep-brief"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-generic-node-runner"))
        XCTAssertTrue(uiTestSources.contains("verifySkillManagerInteractionFlow()"))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerCreatesLocalUserSkillDraft"))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerSearchFiltersSkills"))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.search""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.search.summary""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.local-create.name""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.local-create.summary""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.local-create.button""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.user-ui-created-skill.enable""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.shortcut-save-shared-text.disable""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.shortcut-save-shared-text.enable""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.marketplace-weather-briefing.install""#))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerBlocksIncompatibleMarketplaceSkillInstall"))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.marketplace-qwen-oauth-workflow.install""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.message""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.manifest-preview.compatibility""#))
        XCTAssertTrue(uiTestSources.contains("Connect OAuth provider google"))
        XCTAssertTrue(uiTestSources.contains("Download local model qwen3-5-0-8b-q4-k-m"))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.manifest-preview.confirm""#))
        XCTAssertTrue(uiTestSources.contains(#""access.homekit.demo.evening-scene.confirm""#))
        XCTAssertTrue(uiTestSources.contains("access.homekit.demos"))
    }

    func testMemoryCenterViewDefinesManualSaveAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let memoryView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/MemoryCenterView.swift"), encoding: .utf8)

        XCTAssertTrue(memoryView.contains(#""memory.add.text""#))
        XCTAssertTrue(memoryView.contains(#""memory.add.save""#))
        XCTAssertTrue(memoryView.contains(#""memory.error""#))
        XCTAssertTrue(memoryView.contains(#""memory.list""#))
        XCTAssertTrue(memoryView.contains(#""memory.record""#))
    }

    func testOpenAIProviderThrowsWhenCredentialIsMissing() async throws {
        let provider = OpenAIProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: MockHTTPClient(statusCode: 200, body: #"{"output_text":"unused"}"#)
        )

        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))
            XCTFail("Expected missingCredential error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingCredential)
        }
    }

    func testOpenAIProviderBuildsAuthorizedResponsesRequestAndParsesOutputText() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let httpClient = MockHTTPClient(statusCode: 200, body: #"{"output_text":"Hello from Kairo"}"#)
        let provider = OpenAIProvider(credentialStore: credentials, httpClient: httpClient)

        let response = try await provider.complete(
            AICompletionRequest(
                systemPrompt: "system",
                userPrompt: "hello",
                memoryContext: [
                    MemoryRecord(title: "Preference", summary: "Likes concise answers", content: "", source: .manual)
                ],
                allowedCapabilities: [.memory, .reminders]
            )
        )

        XCTAssertEqual(response.message, "Hello from Kairo")
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.httpMethod, "POST")

        let body = try XCTUnwrap(request.httpBody)
        let bodyObject = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(bodyObject?["model"] as? String, "gpt-4.1")
        XCTAssertNotNil(bodyObject?["input"])
    }

    func testOpenAIProviderParsesNestedResponsesOutput() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let body = #"{"output":[{"content":[{"text":"Nested"},{"text":"response"}]}]}"#
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(statusCode: 200, body: body)
        )

        let response = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))

        XCTAssertEqual(response.message, "Nested\nresponse")
    }

    func testOpenAIProviderEmbedsText() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(statusCode: 200, body: #"{"data":[{"embedding":[0.1,0.2,0.3]}]}"#)
        )

        let response = try await provider.embed(AIEmbeddingRequest(input: "hello"))

        XCTAssertEqual(response.vector, [0.1, 0.2, 0.3])
    }

    func testOpenAIProviderSanitizesErrorResponses() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(
                statusCode: 429,
                body: #"{"error":{"message":"raw prompt secret should not leak","type":"rate_limit_error"}}"#
            )
        )

        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))
            XCTFail("Expected requestFailed error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .requestFailed("OpenAI request failed with status 429 type=rate_limit_error."))
        }
    }

    func testChatGPTOAuthServiceBuildsPKCEAuthorizationURL() async throws {
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid", "profile"],
                audience: "chatgpt"
            ),
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/callback")
        XCTAssertEqual(query["scope"], "openid profile")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
        XCTAssertEqual(query["audience"], "chatgpt")
    }

    func testOAuthConnectorAuthorizationServiceBuildsPKCEAuthorizationURLFromRegistryMetadata() async throws {
        let google = try XCTUnwrap(IntegrationRegistry().integration(for: "gmail-google-workspace")?.oauth)
        let service = OAuthConnectorAuthorizationService(
            metadata: google,
            clientID: "ios-client-id",
            redirectURI: "kairo://oauth/google/callback",
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(session.providerKey, "google")
        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "ios-client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/google/callback")
        XCTAssertEqual(query["scope"], "openid email profile https://www.googleapis.com/auth/gmail.readonly")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
    }

    func testOAuthConnectorLoginCenterReportsStatusesForRegistryConnectors() async throws {
        let registry = IntegrationRegistry()
        let github = try XCTUnwrap(registry.integration(for: "github")?.oauth)
        let credentials = InMemoryCredentialStore()
        let githubAuth = OAuthConnectorAuthorizationService(
            metadata: github,
            clientID: "github-client",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials
        )
        try await githubAuth.storeTokens(OAuthTokenSet(accessToken: "dummy", scopes: ["repo"]))

        let center = OAuthConnectorLoginCenter(
            registry: registry,
            credentialStore: credentials,
            clientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        )

        let options = try await center.loginOptions()
        let google = try XCTUnwrap(options.first { $0.providerKey == "google" })
        let microsoft = try XCTUnwrap(options.first { $0.providerKey == "microsoft" })
        let connectedGitHub = try XCTUnwrap(options.first { $0.providerKey == "github" })

        XCTAssertEqual(options.map(\.providerKey), ["google", "microsoft", "notion", "slack", "chatgpt", "github"])
        XCTAssertEqual(google.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(google.readiness, .readyToAuthorize)
        XCTAssertEqual(microsoft.readiness, .needsClientConfiguration)
        XCTAssertEqual(connectedGitHub.readiness, .connected)
        XCTAssertEqual(connectedGitHub.grantedScopes, ["repo"])
        XCTAssertTrue(connectedGitHub.requiresBackendTokenExchange)
    }

    func testOAuthConnectorLoginCenterBuildsAuthorizationSessionFromClientConfiguration() async throws {
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: InMemoryCredentialStore(),
            clientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback",
                    scopes: ["openid", "email"]
                )
            ]
        )

        let session = try await center.makeAuthorizationSession(
            for: "gmail-google-workspace",
            state: "state-123",
            codeVerifier: "verifier-123"
        )
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(session.providerKey, "google")
        XCTAssertEqual(query["client_id"], "google-client")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/google/callback")
        XCTAssertEqual(query["scope"], "openid email")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
    }

    func testOAuthConnectorCallbackPreviewRedactsAuthorizationCodeAndPersistsStatus() async throws {
        let fileURL = temporaryFileURL(named: "oauth-callbacks.json")
        let store = try await FileBackedOAuthConnectorCallbackStore(fileURL: fileURL)
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: InMemoryCredentialStore(),
            callbackStore: store
        )

        let preview = try await center.previewCallback(
            URL(string: "kairo://oauth/google/callback?code=sample-sensitive-code&state=state-123")!
        )

        XCTAssertEqual(preview.providerKey, "google")
        XCTAssertEqual(preview.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(preview.state, "state-123")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-sensitive-code".count)
        XCTAssertTrue(preview.requiresBackendTokenExchange)
        XCTAssertTrue(preview.settingsStatusText.contains("google"))
        XCTAssertTrue(preview.settingsStatusText.contains("backend token exchange"))
        XCTAssertFalse(preview.settingsStatusText.contains("sample-sensitive-code"))

        let latest = await store.latestPreview(for: "google")
        XCTAssertEqual(latest, preview)

        let storedJSON = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(storedJSON.contains("sample-sensitive-code"))
        XCTAssertTrue(storedJSON.contains(#""authorizationCodeLength":21"#))
    }

    func testOAuthConnectorAuthorizationServiceHandlesNonPKCEConnectorsAndStoresNamespacedTokens() async throws {
        let github = try XCTUnwrap(IntegrationRegistry().integration(for: "github")?.oauth)
        let credentials = InMemoryCredentialStore()
        let service = OAuthConnectorAuthorizationService(
            metadata: github,
            clientID: "github-client-id",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials
        )

        let session = try await service.makeAuthorizationSession(state: "github-state", codeVerifier: "ignored-verifier")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let queryNames = Set((components.queryItems ?? []).map(\.name))

        XCTAssertEqual(session.providerKey, "github")
        XCTAssertFalse(queryNames.contains("code_challenge"))
        XCTAssertFalse(queryNames.contains("code_challenge_method"))
        let authorizationCode = try await service.validateCallback(
            URL(string: "kairo://oauth/github/callback?code=abc&state=github-state")!,
            expectedState: "github-state"
        )
        XCTAssertEqual(authorizationCode, "abc")

        let tokens = OAuthTokenSet(accessToken: "dummy", refreshToken: "dummy", scopes: ["repo"])
        try await service.storeTokens(tokens)
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "github"))
        let loaded = try await service.loadTokens()

        XCTAssertNotNil(storedRaw)
        XCTAssertEqual(loaded, tokens)

        try await service.signOut()
        let tokensAfterSignOut = try await service.loadTokens()
        XCTAssertNil(tokensAfterSignOut)
    }

    func testJSONFileChatHistoryStorePersistsAndSoftDeletesThreads() async throws {
        let fileURL = temporaryFileURL(named: "chat-history.json")
        let thread = ChatThread(
            title: "Plan UI",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            messages: [
                ChatMessage(role: .user, text: "Improve the chat UI", createdAt: Date(timeIntervalSince1970: 10)),
                ChatMessage(role: .assistant, text: "Let's add history.", createdAt: Date(timeIntervalSince1970: 11))
            ]
        )

        let firstStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        try await firstStore.saveThread(thread)

        let secondStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        let loaded = try await secondStore.thread(id: thread.id)
        let listed = try await secondStore.listThreads(limit: 10)

        XCTAssertEqual(loaded?.messages.map(\.text), ["Improve the chat UI", "Let's add history."])
        XCTAssertEqual(listed.map(\.id), [thread.id])

        try await secondStore.deleteThread(id: thread.id)
        let deletedThread = try await secondStore.thread(id: thread.id)
        let threadsAfterDelete = try await secondStore.listThreads(limit: 10)
        XCTAssertNil(deletedThread)
        XCTAssertTrue(threadsAfterDelete.isEmpty)

        let rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(thread.id.uuidString))
        XCTAssertTrue(rawText.contains("deletedAt"))
    }

    func testChatThreadDerivesTitleFromFirstUserMessage() {
        var thread = ChatThread()
        let message = ChatMessage(role: .user, text: "  Please remember my meeting notes and summarize them later  ")

        thread.append(message, now: message.createdAt)

        XCTAssertEqual(thread.title, "Please remember my meeting notes and summa")
        XCTAssertEqual(thread.lastMessagePreview, "Please remember my meeting notes and summarize them later")
    }

    func testChatAttachmentBuildsPromptSummaryAndSharePrompt() {
        let attachment = ChatAttachment(
            kind: .pdf,
            displayName: "Deck.pdf",
            uniformTypeIdentifier: "com.adobe.pdf",
            byteCount: 4096,
            textPreview: "Quarterly plan",
            source: .shareExtension
        )
        let item = ShareIngestionItem(attachments: [attachment])

        XCTAssertTrue(attachment.promptSummary.contains("Deck.pdf"))
        XCTAssertTrue(attachment.promptSummary.contains("Quarterly plan"))
        XCTAssertEqual(item.suggestedPrompt, "Review this shared content: Deck.pdf")
    }

    func testJSONFileShareIngestionQueuePersistsPendingItems() async throws {
        let fileURL = temporaryFileURL(named: "share-ingestion.json")
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [builder.text("Shared article text", displayName: "Article")],
            sourceApplication: "Safari",
            receivedAt: Date(timeIntervalSince1970: 42)
        )

        let firstQueue = try await JSONFileShareIngestionQueue(fileURL: fileURL)
        try await firstQueue.enqueue(item)

        let secondQueue = try await JSONFileShareIngestionQueue(fileURL: fileURL)
        let pending = try await secondQueue.pendingItems(limit: 10)
        XCTAssertEqual(pending.map(\.id), [item.id])
        XCTAssertEqual(pending.first?.attachments.first?.textPreview, "Shared article text")

        try await secondQueue.markImported(id: item.id)
        let afterImport = try await secondQueue.pendingItems(limit: 10)
        XCTAssertTrue(afterImport.isEmpty)
    }

    func testSharedFileIngestionStoreCopiesFilesIntoDurableSharedDirectory() throws {
        let sourceURL = temporaryFileURL(named: "notes.txt")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "shared notes".write(to: sourceURL, atomically: true, encoding: .utf8)
        let sharedDirectory = temporaryFileURL(named: "SharedFiles")
        let store = SharedFileIngestionStore(
            sharedFilesDirectory: sharedDirectory,
            fileNameGenerator: { _ in "copied-notes.txt" }
        )

        let attachment = try store.copyFile(from: sourceURL, uniformTypeIdentifier: "public.plain-text")

        let copiedURL = try XCTUnwrap(attachment.fileURL)
        XCTAssertEqual(copiedURL, sharedDirectory.appendingPathComponent("copied-notes.txt"))
        XCTAssertNotEqual(copiedURL, sourceURL)
        XCTAssertEqual(try String(contentsOf: copiedURL, encoding: .utf8), "shared notes")
        XCTAssertEqual(attachment.displayName, "notes.txt")
        XCTAssertEqual(attachment.kind, .text)
        XCTAssertEqual(attachment.byteCount, Int64("shared notes".utf8.count))
        XCTAssertEqual(attachment.source, .shareExtension)
    }

    func testKairoPathsBuildsApplicationSupportChatHistoryURL() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.chatHistoryStoreURL.lastPathComponent, "chat-history.json")
        XCTAssertEqual(paths.chatHistoryStoreURL.deletingLastPathComponent().lastPathComponent, "KairoTests")
    }

    func testSandboxActionCatalogDescribesSupportedIOSActions() {
        let catalog = SandboxActionCatalog()

        XCTAssertEqual(catalog.descriptor(for: .saveMemory)?.supportStatus, .implemented)
        XCTAssertEqual(catalog.descriptor(for: .createReminderDraft)?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(catalog.descriptor(for: .externalAPIRequest)?.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(catalog.supportedDescriptors.map(\.kind).contains(.openURL))
    }

    func testSandboxActionExecutorRequiresConfirmationBeforeSavingMemory() async throws {
        let memoryStore = InMemoryMemoryStore()
        let executor = SandboxActionExecutor(memoryStore: memoryStore)
        let action = AgentAction(
            kind: .saveMemory,
            title: "Remember",
            rationale: "User asked Kairo to remember this.",
            payload: .text("Remember that Kairo can operate sandboxed iOS capabilities."),
            riskTier: .tier2LowRiskWrite
        )

        let unconfirmed = try await executor.execute(action, confirmed: false)
        let memoriesBeforeConfirmation = try await memoryStore.list(limit: 10)
        XCTAssertFalse(unconfirmed.completed)
        XCTAssertTrue(memoriesBeforeConfirmation.isEmpty)

        let confirmed = try await executor.execute(action, confirmed: true)
        let memories = try await memoryStore.search(query: "sandboxed", limit: 10)
        XCTAssertTrue(confirmed.completed)
        XCTAssertEqual(memories.count, 1)
    }

    func testSandboxActionExecutorReturnsScaffoldedResultForOpenURL() async throws {
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        let action = AgentAction(
            kind: .openURL,
            title: "Open URL",
            rationale: "User wants to open a URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertTrue(result.message.contains("UI opener"))
    }

    func testChatGPTOAuthServiceValidatesCallbackAndStoresTokens() async throws {
        let credentials = InMemoryCredentialStore()
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid"]
            ),
            credentialStore: credentials
        )

        let code = try await service.validateCallback(URL(string: "kairo://oauth/callback?code=abc&state=expected")!, expectedState: "expected")
        XCTAssertEqual(code, "abc")

        try await service.storeTokens(OAuthTokenSet(accessToken: "access", refreshToken: "refresh", scopes: ["openid"]))
        let tokens = try await service.loadTokens()
        XCTAssertEqual(tokens?.accessToken, "access")
        XCTAssertEqual(tokens?.refreshToken, "refresh")

        try await service.signOut()
        let signedOutTokens = try await service.loadTokens()
        XCTAssertNil(signedOutTokens)
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func makeLocalModelSettingsService(
        preference: ProviderRoutePreference,
        installedAndSelectedModelID: String?
    ) async throws -> LocalModelSettingsService {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.1")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        if let modelID = installedAndSelectedModelID {
            try await registry.upsert(LocalModelInstallRecord(
                modelID: modelID,
                version: "1.0",
                status: .installed,
                fileURL: registryURL.deletingLastPathComponent().appendingPathComponent("\(modelID).gguf"),
                installedSizeBytes: 1024,
                sha256: "abc123"
            ))
            try await service.selectModel(id: modelID)
        }
        try await service.setPreference(preference)
        return service
    }

    private func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ errorHandler: (Error) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected async expression to throw.", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    private func signedWeatherSkillManifest(
        version: String,
        signingKey: P256.Signing.PrivateKey,
        changelog: [String] = []
    ) throws -> AgentSkillManifest {
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        skill.version = version
        return try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey,
            changelog: changelog
        )
    }

    private func makeLocalModelManifest(
        id: String,
        version: String = "1.0",
        safetyPolicyVersion: String = "2026.1",
        deprecated: Bool = false,
        sha256: String = "abc123"
    ) -> LocalModelManifest {
        LocalModelManifest(
            id: id,
            displayName: "Qwen Small Test",
            family: "Qwen",
            version: version,
            parameterCount: "0.8B",
            quantization: "Q4",
            fileSizeBytes: 512,
            installedSizeBytes: 1024,
            contextWindow: 2048,
            tokenizerID: "qwen-test-tokenizer",
            licenseName: "Apache-2.0",
            licenseURL: URL(string: "https://example.com/license")!,
            minOSVersion: "17.0",
            minDeviceClass: "A15",
            minRAMGB: 4,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: URL(string: "https://example.com/model.gguf")!,
            sha256: sha256,
            safetyPolicyVersion: safetyPolicyVersion,
            deprecated: deprecated
        )
    }

}

private actor MockHTTPClient: HTTPClient {
    private let statusCode: Int
    private let body: String
    private var capturedRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }

    func lastRequest() throws -> URLRequest {
        guard let capturedRequest else {
            throw MockHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private enum MockHTTPClientError: Error {
    case missingRequest
}

private actor MockURLOpener: URLOpener {
    private(set) var openedURLs: [URL] = []
    private let result: Bool

    init(result: Bool = true) {
        self.result = result
    }

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return result
    }
}

private actor MockNotificationScheduler: NotificationScheduling {
    private(set) var scheduledDrafts: [NotificationDraft] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAuthorization() async throws -> Bool {
        granted
    }

    func schedule(_ draft: NotificationDraft) async throws -> String {
        scheduledDrafts.append(draft)
        return "notification-id"
    }
}

private actor MockReminderScheduler: ReminderScheduling {
    private(set) var createdDrafts: [ReminderDraft] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAccess() async throws -> Bool {
        granted
    }

    func createReminder(from draft: ReminderDraft) async throws -> String {
        createdDrafts.append(draft)
        return "reminder-id"
    }
}

private actor MockCalendarScheduler: CalendarScheduling {
    private(set) var createdDrafts: [CalendarEventDraft] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAccess() async throws -> Bool {
        granted
    }

    func createCalendarEvent(from draft: CalendarEventDraft) async throws -> String {
        createdDrafts.append(draft)
        return "calendar-event-id"
    }
}

private actor MockContactScheduler: ContactScheduling {
    private(set) var createdDrafts: [ContactDraft] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAccess() async throws -> Bool {
        granted
    }

    func createContact(from draft: ContactDraft) async throws -> String {
        createdDrafts.append(draft)
        return "contact-id"
    }
}

private actor MockActionExecutor: ActionExecutor {
    private(set) var executedActions: [AgentAction] = []
    private(set) var confirmations: [Bool] = []

    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult {
        executedActions.append(action)
        confirmations.append(confirmed)
        switch action.kind.rawValue {
        case "createContactDraft":
            return ActionExecutionResult(completed: true, message: "Created contact.", createdIdentifier: "contact-id")
        case "composeEmailDraft":
            return ActionExecutionResult(completed: true, message: "Prepared email draft handoff.", requiresExternalUI: true)
        case "openMapDirections":
            return ActionExecutionResult(completed: true, message: "Prepared Apple Maps directions handoff.", requiresExternalUI: true)
        case "openMessageHandoff":
            return ActionExecutionResult(completed: true, message: "Prepared Messages handoff.", requiresExternalUI: true)
        case "openPhoneCallHandoff":
            return ActionExecutionResult(completed: true, message: "Prepared phone call handoff.", requiresExternalUI: true)
        case "openWebSearchHandoff":
            return ActionExecutionResult(completed: true, message: "Prepared Safari web search handoff.", requiresExternalUI: true)
        case "createCalendarDraft":
            return ActionExecutionResult(completed: true, message: "Created calendar event.", createdIdentifier: "calendar-event-id")
        case "createReminderDraft":
            return ActionExecutionResult(completed: true, message: "Created reminder.", createdIdentifier: "reminder-id")
        default:
            return ActionExecutionResult(completed: true, message: "Scheduled notification.", createdIdentifier: "notification-id")
        }
    }
}

private actor MockHomeControlService: HomeControlService {
    private(set) var requests: [HomeControlRequest] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAuthorization() async throws -> Bool {
        granted
    }

    func execute(_ request: HomeControlRequest) async throws -> String {
        requests.append(request)
        return "home-control-id"
    }
}
