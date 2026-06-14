import XCTest
@testable import KairoCore

#if canImport(SwiftUI)
final class ShareImportReviewStateTests: XCTestCase {
    @MainActor
    func testShareReminderReviewClearsWhenUserSendsAnotherChatMessage() async throws {
        let viewModel = makeShareImportViewModel()

        await viewModel.importPendingShares()
        await viewModel.sendImportedShareToChat()
        XCTAssertNotNil(viewModel.shareImportReviewAction)

        await viewModel.send("Summarize today's launch plan")

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertNil(viewModel.actionResultMessage)
    }

    @MainActor
    func testShareImportStateClearsWhenUserSwitchesThread() async throws {
        let viewModel = makeShareImportViewModel()

        await viewModel.importPendingShares()
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        XCTAssertNotNil(viewModel.shareImportNotice)
        XCTAssertNotNil(viewModel.shareImportPreview)

        let otherThread = ChatThread(messages: [
            ChatMessage(role: .user, text: "Different conversation")
        ])
        viewModel.selectThread(otherThread)

        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertNil(viewModel.shareImportPreview)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertNil(viewModel.captureReviewSummary)
        XCTAssertEqual(viewModel.captureReviewItems, [])
        XCTAssertFalse(viewModel.canSendImportedShareToChat)
    }

    @MainActor
    func testImportedShareSuggestedActionCanBeReviewedAndConfirmedWithoutChatSend() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("記住：AFM 適合短上下文分類。", displayName: "Memory")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let executor = ShareImportReviewMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: queue,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.importPendingShares()

        XCTAssertEqual(viewModel.briefingSnapshot.pendingCaptureCount, 1)
        XCTAssertEqual(viewModel.briefingSnapshot.memoryDraftCount, 1)
        XCTAssertEqual(viewModel.briefingSnapshot.confirmationCount, 1)
        XCTAssertEqual(viewModel.shareImportReviewAction?.kind, .saveMemory)
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        viewModel.reviewImportedShareAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .saveMemory)
        XCTAssertNil(viewModel.shareImportReviewAction)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertTrue(viewModel.pendingAttachments.isEmpty)
        XCTAssertEqual(viewModel.briefingSnapshot, .empty)
        let pendingItems = try await queue.pendingItems(limit: 10)
        let executedKinds = await executor.executedKinds()
        let confirmations = await executor.confirmations()
        XCTAssertEqual(pendingItems, [])
        XCTAssertEqual(executedKinds, [.saveMemory])
        XCTAssertEqual(confirmations, [true])
    }

    @MainActor
    func testCaptureBriefingReviewImportsShareAndOpensPreview() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("TODO: Send AFM test notes", displayName: "Task")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [sharedItem]),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            )
        )

        await viewModel.refreshBriefingSnapshot()
        XCTAssertEqual(viewModel.briefingSnapshot.pendingCaptureCount, 1)
        XCTAssertEqual(viewModel.briefingSnapshot.confirmationCount, 1)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportReviewAction)

        await viewModel.reviewCaptureBriefing()

        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertEqual(viewModel.captureReviewSummary?.captureCount, 1)
        XCTAssertEqual(viewModel.captureReviewSummary?.reviewCount, 1)
        XCTAssertEqual(viewModel.captureReviewSummary?.reminderDraftCount, 1)
        XCTAssertEqual(viewModel.captureReviewItems.map(\.triage), [.createReminder])
        XCTAssertEqual(viewModel.captureReviewItems.map(\.actionCount), [1])
        XCTAssertFalse(viewModel.pendingAttachments.isEmpty)
        XCTAssertNotNil(viewModel.shareImportNotice)
    }

    @MainActor
    func testCaptureBriefingReviewSendsInfoPageOnlyCaptureToChatAndClearsShare() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [
                builder.text("研究筆記：AFM prompt pipeline 先分類，再抽取事實，最後產生 JSON。", displayName: "AFM note")
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let infoPageStore = InMemoryInfoPageStore()
        let draft = InfoPageDraft(
            createInfoPage: true,
            title: "AFM Prompt Pipeline",
            templateID: .generalNote,
            category: .generalNote,
            summary: "AFM prompt pipelines are more stable when classification, fact extraction, and JSON composition are staged.",
            facts: [
                InfoPageDraftFact(label: "topic", value: "AFM prompt pipeline")
            ],
            confidence: 0.9,
            keywords: ["afm", "prompt", "pipeline"]
        )
        let viewModel = ChatViewModel(dependencies: ChatFeatureDependencies(
            historyStore: InMemoryChatHistoryStore(),
            shareImportAPI: KairoShareImportBackendService(
                shareIngestionQueue: queue,
                urlMetadataProvider: EmptyURLMetadataProvider(),
                urlReadableContentProvider: EmptyURLReadableContentProvider()
            ),
            actionInboxAPI: KairoActionInboxBackendService(shareIngestionQueue: queue),
            chatAPI: ShareReviewFixedInfoPageChatAPI(draft: draft),
            actionAPI: ShareReviewNoopActionAPI(),
            infoPageStore: infoPageStore
        ))

        await viewModel.refreshBriefingSnapshot()
        XCTAssertEqual(viewModel.briefingSnapshot.pendingCaptureCount, 1)

        await viewModel.reviewCaptureBriefing()

        let pages = try await infoPageStore.list(limit: 10)
        let remaining = try await queue.pendingItems(limit: 10)
        XCTAssertEqual(pages.map(\.title), ["AFM Prompt Pipeline"])
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertNil(viewModel.captureReviewSummary)
        XCTAssertEqual(viewModel.captureReviewItems, [])
        XCTAssertNil(viewModel.shareImportReviewAction)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertEqual(viewModel.briefingSnapshot, .empty)
    }

    @MainActor
    func testCaptureBriefingContinuesMixedInfoPageCaptureAfterActionConfirmation() async throws {
        let builder = ShareAttachmentBuilder()
        let executor = ShareImportReviewMockExecutor()
        let queue = InMemoryShareIngestionQueue(seed: [
            ShareIngestionItem(
                attachments: [builder.text("TODO: Send AFM test notes", displayName: "Task")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 10)
            ),
            ShareIngestionItem(
                attachments: [builder.text("研究筆記：AFM prompt pipeline 先分類，再抽取事實，最後產生 JSON。", displayName: "AFM note")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 20)
            )
        ])
        let infoPageStore = InMemoryInfoPageStore()
        let draft = InfoPageDraft(
            createInfoPage: true,
            title: "AFM Prompt Pipeline",
            templateID: .generalNote,
            category: .generalNote,
            summary: "AFM prompt pipelines are more stable when model work is staged.",
            facts: [
                InfoPageDraftFact(label: "topic", value: "AFM prompt pipeline")
            ],
            confidence: 0.9,
            keywords: ["afm", "prompt"]
        )
        let chatAPI = ShareReviewFixedInfoPageChatAPI(draft: draft)
        let viewModel = ChatViewModel(dependencies: ChatFeatureDependencies(
            historyStore: InMemoryChatHistoryStore(),
            shareImportAPI: KairoShareImportBackendService(
                shareIngestionQueue: queue,
                urlMetadataProvider: EmptyURLMetadataProvider(),
                urlReadableContentProvider: EmptyURLReadableContentProvider()
            ),
            actionInboxAPI: KairoActionInboxBackendService(shareIngestionQueue: queue),
            chatAPI: chatAPI,
            actionAPI: KairoActionBackendService(actionExecutor: executor),
            infoPageStore: infoPageStore
        ))

        await viewModel.reviewCaptureBriefing()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        XCTAssertEqual(viewModel.captureReviewSummary?.infoPageCount, 1)

        await viewModel.confirmPendingAction()

        let pages = try await infoPageStore.list(limit: 10)
        let remaining = try await queue.pendingItems(limit: 10)
        let executedKinds = await executor.executedKinds()
        let prompts = await chatAPI.receivedMessages()
        XCTAssertEqual(executedKinds, [.createReminderDraft])
        XCTAssertEqual(pages.map(\.title), ["AFM Prompt Pipeline"])
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(prompts.count, 1)
        XCTAssertTrue(prompts.first?.contains("InfoPage") == true)
        XCTAssertTrue(prompts.first?.contains("AFM prompt pipeline") == true)
        let traces = viewModel.currentThread.messages.compactMap(\.promptPipelineTrace)
        XCTAssertEqual(traces.map(\.providerID), ["kairo-response-pipeline", "kairo-response-pipeline"])
        XCTAssertEqual(traces.map(\.status), [.validated, .validated])
        XCTAssertTrue(traces.flatMap(\.stages).contains { $0.name == .parseStructuredOutput && $0.detail == "InfoPage draft" })
        XCTAssertTrue(traces.flatMap(\.stages).contains { $0.name == .validateDraft && $0.status == .passed })
        XCTAssertTrue(traces.flatMap(\.stages).contains { $0.name == .finalize && $0.status == .passed })
        XCTAssertEqual(viewModel.promptPipelineHealthSummary?.traceCount, 2)
        XCTAssertEqual(viewModel.promptPipelineHealthSummary?.validatedCount, 2)
        XCTAssertEqual(viewModel.promptPipelineHealthSummary?.level, .stable)
        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertNil(viewModel.captureReviewSummary)
        XCTAssertEqual(viewModel.captureReviewItems, [])
        XCTAssertEqual(viewModel.briefingSnapshot, .empty)
    }

    @MainActor
    func testCaptureBriefingSummaryTracksMixedPendingCaptureSuggestions() async throws {
        let builder = ShareAttachmentBuilder()
        let executor = ShareImportReviewMockExecutor()
        let queue = InMemoryShareIngestionQueue(seed: [
            ShareIngestionItem(
                attachments: [builder.text("週五前整理 Kairo demo", displayName: "Task")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 10)
            ),
            ShareIngestionItem(
                attachments: [builder.text("記住：AFM 適合短上下文分類。", displayName: "Memory")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 20)
            ),
            ShareIngestionItem(
                attachments: [builder.url(URL(string: "https://example.com/research/afm-pipeline")!)],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 30)
            )
        ])
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: queue,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.importPendingShares()

        let summary = try XCTUnwrap(viewModel.captureReviewSummary)
        XCTAssertEqual(summary.captureCount, 3)
        XCTAssertEqual(summary.reviewCount, 3)
        XCTAssertEqual(summary.reminderDraftCount, 1)
        XCTAssertEqual(summary.memoryDraftCount, 1)
        XCTAssertEqual(summary.infoPageCount, 1)
        XCTAssertEqual(summary.captureOnlyCount, 0)
        XCTAssertEqual(viewModel.captureReviewItems.map(\.triage), [.createReminder, .saveMemory, .createInfoPage])
        XCTAssertEqual(viewModel.captureReviewItems.map(\.actionCount), [1, 1, 0])
        XCTAssertTrue(viewModel.captureReviewItems.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(viewModel.captureReviewItems.allSatisfy { !$0.detail.isEmpty })
        XCTAssertEqual(viewModel.captureReviewItems.map(\.isActive), [false, false, false])
        XCTAssertEqual(viewModel.shareImportReviewAction?.kind, .createReminderDraft)

        viewModel.reviewImportedShareAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        XCTAssertEqual(viewModel.captureReviewItems.map(\.isActive), [true, false, false])

        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .saveMemory)
        XCTAssertEqual(viewModel.captureReviewItems.map(\.isActive), [false, true, false])

        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.captureReviewItems, [])
    }

    @MainActor
    func testCaptureBriefingReviewAdvancesThroughQueuedActionsBeforeClearingShare() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("週五前整理 Kairo demo，補 Google Maps 和 Todoist 測試。", displayName: "Tasks")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [sharedItem])
        let executor = ShareImportReviewMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: queue,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.reviewCaptureBriefing()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)

        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        let pendingAfterFirstConfirmation = try await queue.pendingItems(limit: 10)
        XCTAssertFalse(pendingAfterFirstConfirmation.isEmpty)

        await viewModel.confirmPendingAction()
        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        let pendingAfterSecondConfirmation = try await queue.pendingItems(limit: 10)
        XCTAssertFalse(pendingAfterSecondConfirmation.isEmpty)

        await viewModel.confirmPendingAction()

        XCTAssertNil(viewModel.pendingAction)
        XCTAssertNil(viewModel.shareImportNotice)
        XCTAssertNil(viewModel.captureReviewSummary)
        XCTAssertEqual(viewModel.captureReviewItems, [])
        let pendingAfterFinalConfirmation = try await queue.pendingItems(limit: 10)
        XCTAssertEqual(pendingAfterFinalConfirmation, [])
        let executedKinds = await executor.executedKinds()
        XCTAssertEqual(executedKinds, [.createReminderDraft, .createReminderDraft, .createReminderDraft])
    }

    @MainActor
    func testCaptureBriefingCancelSkipsCurrentQueuedActionWithoutExecuting() async throws {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("週五前整理 Kairo demo，補 Google Maps 和 Todoist 測試。", displayName: "Tasks")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let executor = ShareImportReviewMockExecutor()
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [sharedItem]),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            ),
            actionExecutor: executor
        )

        await viewModel.reviewCaptureBriefing()
        let firstActionID = viewModel.pendingAction?.id

        viewModel.cancelPendingAction()

        XCTAssertEqual(viewModel.pendingAction?.kind, .createReminderDraft)
        XCTAssertNotEqual(viewModel.pendingAction?.id, firstActionID)
        let executedKinds = await executor.executedKinds()
        XCTAssertTrue(executedKinds.isEmpty)
    }

    @MainActor
    private func makeShareImportViewModel() -> ChatViewModel {
        let builder = ShareAttachmentBuilder()
        let sharedItem = ShareIngestionItem(
            attachments: [builder.text("TODO: Send prototype link", displayName: "Launch Notes")],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        return ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [sharedItem]),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
            )
        )
    }
}

private actor ShareImportReviewMockExecutor: ActionExecutor {
    private var actions: [AgentAction] = []
    private var confirmedValues: [Bool] = []

    func execute(_ action: AgentAction, confirmed: Bool) async throws -> ActionExecutionResult {
        actions.append(action)
        confirmedValues.append(confirmed)
        return ActionExecutionResult(completed: true, message: "ok")
    }

    func executedKinds() -> [AgentActionKind] {
        actions.map(\.kind)
    }

    func confirmations() -> [Bool] {
        confirmedValues
    }
}

private actor ShareReviewFixedInfoPageChatAPI: KairoChatAPI {
    private let draft: InfoPageDraft
    private var messages: [String] = []

    init(draft: InfoPageDraft) {
        self.draft = draft
    }

    func receivedMessages() -> [String] {
        messages
    }

    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        try await respond(
            to: message,
            attachments: attachments,
            conversationID: nil,
            conversationHistory: [],
            privacyMode: privacyMode
        )
    }

    func respond(
        to message: String,
        attachments: [ChatAttachment],
        conversationID: String?,
        conversationHistory: [AIConversationTurn],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        _ = message
        _ = attachments
        _ = conversationID
        _ = conversationHistory
        _ = privacyMode
        messages.append(message)
        return AICompletionResponse(message: "Created page.", infoPageDraft: draft)
    }
}

private struct ShareReviewNoopActionAPI: KairoActionAPI {
    func preview(_ action: AgentAction) async -> KairoActionPreview {
        KairoActionPreview(
            action: action,
            decision: SafetyPolicyDecision(allowed: true, requiresConfirmation: false, reason: "test")
        )
    }

    func confirm(_ action: AgentAction) async throws -> ActionExecutionResult {
        _ = action
        return ActionExecutionResult(completed: true, message: "")
    }
}
#endif
