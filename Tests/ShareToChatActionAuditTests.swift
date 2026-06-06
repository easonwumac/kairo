import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ShareToChatActionAuditTests: XCTestCase {
    @MainActor
    func testShareTextToChatReminderConfirmationRecordsAuditEvent() async throws {
        let reminderScheduler = CapturingReminderScheduler(identifier: "shared-text-reminder-id")
        let flow = makeShareReminderFlow(reminderScheduler: reminderScheduler)

        await flow.viewModel.importPendingShares()
        XCTAssertEqual(flow.viewModel.pendingAttachments.map(\.kind), [.text])
        XCTAssertEqual(flow.viewModel.pendingAttachments.map(\.source), [.shareExtension])
        XCTAssertEqual(flow.viewModel.canSendImportedShareToChat, true)

        await flow.viewModel.sendImportedShareToChat()
        XCTAssertNil(flow.viewModel.shareImportNotice)
        XCTAssertNil(flow.viewModel.shareImportPreview)
        XCTAssertFalse(flow.viewModel.canSendImportedShareToChat)
        let assistantMessage = try XCTUnwrap(flow.viewModel.currentThread.messages.last)
        let toolCandidate = try XCTUnwrap(assistantMessage.toolCandidates.first { $0.skillID == "shortcut-save-shared-text" })
        XCTAssertEqual(toolCandidate.source, .installedSkill)
        XCTAssertEqual(toolCandidate.skillKind, .shortcutWorkflow)
        XCTAssertEqual(toolCandidate.shortcutRecipeID, "save-shared-text")
        XCTAssertTrue(toolCandidate.requiresConfirmation)
        XCTAssertFalse(
            assistantMessage.toolCandidates.contains { $0.source == .integrationRegistry },
            "\(assistantMessage.toolCandidates.map { "\($0.id)|\($0.source.rawValue)|\($0.integrationKey ?? "-")|\($0.skillID ?? "-")" })"
        )
        let action = try XCTUnwrap(assistantMessage.proposedActions.first { $0.kind == .createReminderDraft })
        let reminderTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(for: action.kind))
        XCTAssertEqual(reminderTool.id, .reminderWrite)
        XCTAssertEqual(reminderTool.confirmationPolicy, .previewAndExplicitConfirmation)
        XCTAssertEqual(reminderTool.audit.capabilityKeys, [.reminders])
        guard case let .reminder(draft) = action.payload else {
            return XCTFail("Expected reminder payload.")
        }
        XCTAssertEqual(draft.title, "Send prototype link")
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertNil(flow.viewModel.pendingAction)
        let draftsBeforeReview = await reminderScheduler.createdDraftsSnapshot()
        XCTAssertEqual(draftsBeforeReview.count, 0)
        let preConfirmationAuditEvents = try await flow.auditLogger.list(limit: 10)
        XCTAssertTrue(preConfirmationAuditEvents.isEmpty)

        flow.viewModel.reviewImportedShareAction()
        XCTAssertEqual(flow.viewModel.pendingAction?.id, action.id)
        let draftsBeforeConfirmation = await reminderScheduler.createdDraftsSnapshot()
        XCTAssertEqual(draftsBeforeConfirmation.count, 0)
        await flow.viewModel.confirmPendingAction()

        XCTAssertNil(flow.viewModel.pendingAction)
        XCTAssertEqual(flow.viewModel.actionResultSucceeded, true)
        let createdDrafts = await reminderScheduler.createdDraftsSnapshot()
        XCTAssertEqual(createdDrafts.map(\.title), ["Send prototype link"])
        let auditEvents = try await flow.auditLogger.list(limit: 10)
        XCTAssertEqual(auditEvents.count, 1)
        XCTAssertEqual(auditEvents.first?.actionKind, .createReminderDraft)
        XCTAssertEqual(auditEvents.first?.capabilityKeys, [.reminders])
        XCTAssertEqual(auditEvents.first?.userConfirmed, true)
        XCTAssertEqual(auditEvents.first?.result, .completed)
        XCTAssertTrue(auditEvents.first?.memoryIDs.isEmpty ?? false)
        let encodedAuditEvent = try JSONEncoder().encode(try XCTUnwrap(auditEvents.first))
        let encodedAuditText = try XCTUnwrap(String(data: encodedAuditEvent, encoding: .utf8))
        XCTAssertFalse(encodedAuditText.contains("TODO: Send prototype link"))
        XCTAssertFalse(encodedAuditText.contains("Book beta review meeting"))
        let remainingShares = try await flow.shareQueue.pendingItems(limit: 10)
        XCTAssertTrue(remainingShares.isEmpty)
    }

    @MainActor
    func testShareTextReminderPermissionFailureSaysReminderWasNotCreated() async throws {
        let flow = makeShareReminderFlow(reminderScheduler: UnavailableReminderScheduler())

        await flow.viewModel.importPendingShares()
        await flow.viewModel.sendImportedShareToChat()
        flow.viewModel.reviewImportedShareAction()
        await flow.viewModel.confirmPendingAction()

        XCTAssertNil(flow.viewModel.pendingAction)
        XCTAssertEqual(flow.viewModel.actionResultSucceeded, false)
        XCTAssertNil(flow.viewModel.errorMessage)
        let auditEvents = try await flow.auditLogger.list(limit: 10)
        let remainingShares = try await flow.shareQueue.pendingItems(limit: 10)
        XCTAssertEqual(auditEvents.first?.result, .failed)
        XCTAssertTrue(remainingShares.isEmpty)
    }

    @MainActor
    private func makeShareReminderFlow(reminderScheduler: any ReminderScheduling) -> (
        viewModel: ChatViewModel,
        shareQueue: InMemoryShareIngestionQueue,
        auditLogger: InMemoryAuditLogger
    ) {
        let builder = ShareAttachmentBuilder()
        let text = """
        TODO: Send prototype link
        Reminder: Book beta review meeting
        """
        let sharedItem = ShareIngestionItem(attachments: [builder.text(text, displayName: "Launch Notes")], sourceApplication: "ShareSheet", receivedAt: Date(timeIntervalSince1970: 10))
        let shareQueue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let auditLogger = InMemoryAuditLogger()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: shareQueue,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(
                    memoryStore: InMemoryMemoryStore(),
                    aiProvider: MockAIProvider(),
                    skillCatalog: installedShortcutSkillCatalog()
                )
            ),
            actionExecutor: SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), reminderScheduler: reminderScheduler, auditLogger: auditLogger)
        )
        return (viewModel, shareQueue, auditLogger)
    }
}

private func installedShortcutSkillCatalog() -> AgentSkillCatalog {
    AgentSkillCatalog(skills: AgentSkillCatalog.default.skills.map { skill in
        guard skill.kind == .shortcutWorkflow else { return skill }
        var installed = skill
        installed.installationStatus = .installed
        return installed
    })
}

private actor CapturingReminderScheduler: ReminderScheduling {
    private let identifier: String
    private(set) var createdDrafts: [ReminderDraft] = []

    init(identifier: String) {
        self.identifier = identifier
    }

    func requestAccess() async throws -> Bool {
        true
    }

    func createReminder(from draft: ReminderDraft) async throws -> String {
        createdDrafts.append(draft)
        return identifier
    }

    func createdDraftsSnapshot() -> [ReminderDraft] {
        createdDrafts
    }
}
#endif
