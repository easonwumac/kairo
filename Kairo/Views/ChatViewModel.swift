#if canImport(SwiftUI)
import Foundation
import SwiftUI

extension Notification.Name {
    static let infoPageSaved = Notification.Name("KairoInfoPageSaved")
}

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var threads: [ChatThread] = []
    @Published public private(set) var currentThread: ChatThread
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var pendingAttachments: [ChatAttachment] = []
    @Published public private(set) var shareImportNotice: String?
    @Published public private(set) var shareImportPreview: String?
    @Published public private(set) var shareImportReviewAction: AgentAction?
    @Published public private(set) var calendarReviewAction: AgentAction?
    @Published public private(set) var handoffReviewAction: AgentAction?
    @Published public var composerText: String = ""
    @Published public var errorMessage: String?
    @Published public var pendingAction: AgentAction?
    @Published public private(set) var actionResultMessage: String?
    @Published public private(set) var actionResultSucceeded: Bool?
    @Published public private(set) var replyTarget: ChatMessage?
    @Published public private(set) var providerRouteStatus: ChatProviderRouteStatus
    @Published public private(set) var briefingSnapshot: KairoBriefingSnapshot = .empty
    @Published public private(set) var latestInferenceMetrics: AIInferenceMetrics?
    @Published public private(set) var privacyMode: ChatPrivacyMode = .standard
    public var canEditProviderRoute: Bool { localModelSettingsService != nil }
    public var isPrivateChatEnabled: Bool { privacyMode == .privateChat }
    public var canSendImportedShareToChat: Bool {
        shareImportNotice != nil && (!composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !pendingAttachments.isEmpty)
    }
    public var shareImportPrimaryActionTitle: String {
        let prompt = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if prompt.hasPrefix(KairoL10n.string("chat.share.prompt.extractReminderPrefix")) {
            return KairoL10n.string("chat.share.action.extractReminders")
        }
        return Self.isSummarizeSharePrompt(prompt)
            ? KairoL10n.string("chat.share.action.summarize")
            : KairoL10n.string("chat.share.action.sendToChat")
    }
    public var inferenceStatusText: String {
        Self.inferenceStatusText(isLoading: isLoading, metrics: latestInferenceMetrics)
    }
    public var promptPipelineHealthSummary: ChatPromptPipelineHealthSummary? {
        Self.promptPipelineHealthSummary(for: currentThread.messages)
    }

    private let historyStore: ChatHistoryStore
    private let shareImportAPI: any KairoShareImportAPI
    private let actionInboxAPI: any KairoActionInboxAPI
    private let chatAPI: any KairoChatAPI
    private let actionAPI: any KairoActionAPI
    private let infoPageStore: InfoPageStore?
    private let localModelSettingsService: LocalModelSettingsService?
    private let openAISettingsService: OpenAISettingsService?
    private let localModelChatRuntimeAvailable: Bool
    private let threadCompactor: (any ChatThreadCompacting)?
    private let knowledgeAssetAPI: (any KairoKnowledgeAssetAPI)?
    private let chatAttachmentRootDirectory: URL?
    private var pendingActionSource: PendingActionSource?
    private var importedShareItemIDs: [UUID] = []
    private var importedShareReviewQueue: [AgentAction] = []
    private var inferenceProgressTask: Task<Void, Never>?
    private var lastTurnAssetIDs: [UUID] = []

    public init(
        dependencies: ChatFeatureDependencies
    ) {
        self.historyStore = dependencies.historyStore
        self.shareImportAPI = dependencies.shareImportAPI
        self.actionInboxAPI = dependencies.actionInboxAPI
        self.chatAPI = dependencies.chatAPI
        self.actionAPI = dependencies.actionAPI
        self.infoPageStore = dependencies.infoPageStore
        self.localModelSettingsService = dependencies.localModelSettingsService
        self.openAISettingsService = dependencies.openAISettingsService
        self.localModelChatRuntimeAvailable = dependencies.localModelChatRuntimeAvailable
        self.threadCompactor = dependencies.threadCompactor
        self.knowledgeAssetAPI = dependencies.knowledgeAssetAPI
        self.chatAttachmentRootDirectory = dependencies.chatAttachmentRootDirectory
        self.currentThread = ChatThread(messages: [Self.welcomeMessage])
        self.providerRouteStatus = ChatProviderRouteStatusBuilder.build(from: nil)
    }

    deinit {
        inferenceProgressTask?.cancel()
    }

    public convenience init(
        historyStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        shareImportAPI: (any KairoShareImportAPI)? = nil,
        chatAPI: (any KairoChatAPI)? = nil,
        actionAPI: (any KairoActionAPI)? = nil,
        actionInboxAPI: (any KairoActionInboxAPI)? = nil,
        actionExecutor: (any ActionExecutor)? = nil,
        dependencyComposer: any ChatFeatureDependencyComposing = DefaultChatFeatureDependencyComposer(),
        localModelSettingsService: LocalModelSettingsService? = nil,
        openAISettingsService: OpenAISettingsService? = nil,
        localModelChatRuntimeAvailable: Bool = false,
        actionDescriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider()
    ) {
        self.init(
            dependencies: dependencyComposer.makeDependencies(
                historyStore: historyStore,
                shareIngestionQueue: shareIngestionQueue,
                chatAPI: chatAPI,
                shareImportAPI: shareImportAPI,
                actionInboxAPI: actionInboxAPI,
                actionAPI: actionAPI,
                actionExecutor: actionExecutor,
                localModelSettingsService: localModelSettingsService,
                openAISettingsService: openAISettingsService,
                localModelChatRuntimeAvailable: localModelChatRuntimeAvailable,
                actionDescriptorProvider: actionDescriptorProvider
            )
        )
    }

    public convenience init(environment: KairoEnvironment) {
        self.init(dependencies: environment.chatFeatureDependencies)
    }

    public func load() async {
        startInferenceProgressListenerIfNeeded()
        do {
            threads = try await historyStore.listThreads(limit: 50)
            if let first = threads.first {
                currentThread = first
            } else {
                currentThread = ChatThread(messages: [Self.welcomeMessage])
            }
            errorMessage = nil
            await refreshProviderRouteStatus()
            await refreshBriefingSnapshot()
        } catch {
            errorMessage = KairoL10n.string("chat.error.loadHistory", error.localizedDescription)
        }
    }

    public func startNewThread() {
        privacyMode = .standard
        currentThread = ChatThread(messages: [Self.welcomeMessage])
        composerText = ""
        replyTarget = nil
        clearShareImportState()
        errorMessage = nil
        clearTransientActionState()
    }

    public func startPrivateThread() {
        privacyMode = .privateChat
        currentThread = ChatThread(messages: [Self.welcomeMessage])
        composerText = ""
        pendingAttachments = []
        replyTarget = nil
        clearShareImportState()
        errorMessage = nil
        clearTransientActionState()
    }

    public func selectThread(_ thread: ChatThread) {
        privacyMode = .standard
        currentThread = thread
        composerText = ""
        replyTarget = nil
        clearShareImportState()
        errorMessage = nil
        clearTransientActionState()
    }

    public func deleteThread(_ thread: ChatThread) async {
        do {
            try await historyStore.deleteThread(id: thread.id)
            try await historyStore.purgeDeletedThreads()
            threads = try await historyStore.listThreads(limit: 50)
            if currentThread.id == thread.id {
                currentThread = threads.first ?? ChatThread(messages: [Self.welcomeMessage])
                clearShareImportState()
                clearTransientActionState()
            }
            errorMessage = nil
        } catch {
            errorMessage = KairoL10n.string("chat.error.deleteHistory", error.localizedDescription)
        }
    }

    public func selectThread(id: UUID) async {
        do {
            guard let thread = try await historyStore.thread(id: id) else { return }
            selectThread(thread)
        } catch {
            errorMessage = KairoL10n.string("chat.error.loadHistory", error.localizedDescription)
        }
    }

    public func clearCurrentThread() async {
        await deleteThread(currentThread)
        actionResultMessage = KairoL10n.string("chat.thread.action.cleared")
        actionResultSucceeded = true
    }

    public func deleteCurrentThread() async {
        await deleteThread(currentThread)
        actionResultMessage = KairoL10n.string("chat.thread.action.deleted")
        actionResultSucceeded = true
    }

    public func forkCurrentThread() async {
        let sourceMessages = currentThread.messages.filter { $0.id != Self.welcomeMessage.id }
        guard !sourceMessages.isEmpty else {
            startNewThread()
            return
        }
        let now = Date()
        var fork = ChatThread(
            title: KairoL10n.string("chat.thread.fork.title", currentThread.title),
            createdAt: now,
            updatedAt: now,
            messages: sourceMessages.map { message in
                ChatMessage(
                    role: message.role,
                    text: message.text,
                    createdAt: message.createdAt,
                    proposedActions: message.proposedActions,
                    toolCandidates: message.toolCandidates,
                    attachments: message.attachments,
                    status: message.status,
                    memoryContextCount: message.memoryContextCount,
                    reasoningText: message.reasoningText,
                    rawModelResponse: message.rawModelResponse,
                    promptPipelineTrace: message.promptPipelineTrace,
                    pipelineDiagnosticResult: message.pipelineDiagnosticResult
                )
            }
        )
        if fork.messages.isEmpty {
            fork.messages = [Self.welcomeMessage]
        }
        do {
            try await historyStore.saveThread(fork)
            threads = try await historyStore.listThreads(limit: 50)
            currentThread = fork
            clearShareImportState()
            clearTransientActionState()
            actionResultMessage = KairoL10n.string("chat.thread.action.forked")
            actionResultSucceeded = true
        } catch {
            errorMessage = KairoL10n.string("chat.error.saveHistory", error.localizedDescription)
        }
    }

    public func prepareCompactPrompt() {
        let transcript = currentThread.messages
            .filter { $0.id != Self.welcomeMessage.id }
            .prefix(12)
            .map { message in
                "\(message.role.rawValue): \(Self.singleLinePreview(message.text).prefix(220))"
            }
            .joined(separator: "\n")
        guard !transcript.isEmpty else { return }
        composerText = KairoL10n.string("chat.thread.compact.prompt", transcript)
        pendingAttachments = []
        replyTarget = nil
        clearTransientActionState()
    }

    public func preparePipelineDiagnosticPrompt(from summary: ChatPromptPipelineHealthSummary) {
        composerText = Self.pipelineDiagnosticPrompt(for: summary)
        pendingAttachments = []
        replyTarget = nil
        clearTransientActionState()
    }

    public func importPendingShares() async {
        guard !canSendImportedShareToChat else { return }
        do {
            await refreshBriefingSnapshot()
            let imported = try await shareImportAPI.importPendingShares(limit: 10)
            guard !imported.isEmpty else { return }
            pendingAttachments.append(contentsOf: imported.attachments)
            importedShareItemIDs = imported.importedItemIDs
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                composerText = imported.suggestedPrompt ?? KairoL10n.string("chat.share.prompt.summarizeDefault")
            }
            shareImportNotice = Self.shareImportNotice(importedCount: imported.importedItemIDs.count)
            shareImportPreview = Self.shareImportPreview(for: imported.attachments)
            importedShareReviewQueue = imported.suggestedActions
            shareImportReviewAction = importedShareReviewQueue.first
            await refreshBriefingSnapshot()
            errorMessage = nil
        } catch {
            errorMessage = KairoL10n.string("chat.error.importShare", error.localizedDescription)
        }
    }

    public func refreshBriefingSnapshot() async {
        do {
            let items = try await actionInboxAPI.pendingItems(limit: 20)
            briefingSnapshot = KairoBriefingSnapshotBuilder().snapshot(from: items)
        } catch {
            briefingSnapshot = .empty
        }
    }

    public func openCaptureBriefing() async {
        await importPendingShares()
    }

    public func reviewCaptureBriefing() async {
        if shareImportReviewAction == nil {
            await importPendingShares()
        }
        reviewImportedShareAction()
    }

    public func sendImportedShareToChat() async {
        guard canSendImportedShareToChat else { return }
        let importedItemIDs = importedShareItemIDs
        let importedAttachments = pendingAttachments
        await sendComposerMessage()
        do {
            try await shareImportAPI.clearImportedShares(ids: importedItemIDs, attachments: importedAttachments)
            importedShareItemIDs = []
            await refreshBriefingSnapshot()
        } catch {
            errorMessage = KairoL10n.string("chat.error.importShare", error.localizedDescription)
        }
        shareImportReviewAction = firstReminderActionFromLatestAssistantMessage()
    }

    public func addAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.append(attachment)
    }

    public func removeAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    public func sendComposerMessage() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || !pendingAttachments.isEmpty || replyTarget != nil), !isLoading else { return }
        await refreshProviderRouteStatus()
        let attachments = pendingAttachments
        let replyTarget = replyTarget
        composerText = ""
        pendingAttachments = []
        shareImportNotice = nil
        shareImportPreview = nil
        self.replyTarget = nil
        await send(composedMessageText(text: text, replyTarget: replyTarget, hasAttachments: !attachments.isEmpty), attachments: attachments)
    }

    public func send(_ text: String, attachments: [ChatAttachment] = []) async {
        clearTransientActionState()
        await compactCurrentThreadIfNeeded(forPendingUserText: text)
        let persistedAttachments = await persistAttachmentsAsKnowledgeAssets(attachments, userText: text)
        let userMessage = ChatMessage(role: .user, text: text, attachments: persistedAttachments.attachments)
        currentThread.append(userMessage, now: userMessage.createdAt)
        await persistCurrentThread()
        lastTurnAssetIDs = persistedAttachments.assetIDs

        isLoading = true
        latestInferenceMetrics = AIInferenceMetrics(stage: .preparingInput)
        errorMessage = nil
        do {
            let response = try await chatAPI.respond(
                to: text,
                attachments: persistedAttachments.attachments,
                conversationID: runtimeConversationID(),
                conversationHistory: localConversationHistory(),
                privacyMode: privacyMode
            )
            let assistantMessage = ChatMessage(
                role: .assistant,
                text: response.message,
                proposedActions: response.proposedActions,
                toolCandidates: response.toolCandidates,
                memoryContextCount: response.memoryContextCount,
                reasoningText: response.reasoningText,
                rawModelResponse: response.rawModelResponse,
                promptPipelineTrace: response.promptPipelineTrace,
                pipelineDiagnosticResult: response.pipelineDiagnosticResult
            )
            currentThread.append(assistantMessage, now: assistantMessage.createdAt)
            latestInferenceMetrics = response.inferenceMetrics
            if let promptTokens = response.inferenceMetrics?.promptTokens, promptTokens > 0 {
                currentThread.lastPromptTokens = promptTokens
            }

            if let draft = response.infoPageDraft, draft.createInfoPage {
                await saveInfoPageDraft(draft, after: assistantMessage.id)
            }
            await persistCurrentThread()
            calendarReviewAction = firstCalendarActionFromLatestAssistantMessage()
            handoffReviewAction = firstHandoffActionFromLatestAssistantMessage()
        } catch {
            let userFacingMessage = Self.userFacingChatErrorMessage(for: error)
            let failedMessage = ChatMessage(
                role: .assistant,
                text: userFacingMessage,
                status: .failed
            )
            currentThread.append(failedMessage, now: failedMessage.createdAt)
            errorMessage = userFacingMessage
            await persistCurrentThread()
        }
        isLoading = false
        lastTurnAssetIDs = []
    }

    private func saveInfoPageDraft(_ draft: InfoPageDraft, after messageID: UUID) async {
        guard let store = infoPageStore else { return }
        var page = draft.makeInfoPage()
        if page.assetIDs.isEmpty {
            page.assetIDs = lastTurnAssetIDs
        }
        do {
            try await store.save(page)
            await enrichLinkedAssets(from: draft, page: page)
            let subcategoryNote = draft.candidateCategories?.first?.folderName ?? draft.folderName
            let savedText: String
            if let sub = subcategoryNote, !sub.isEmpty {
                savedText = KairoL10n.string("chat.infoPage.savedWithSubcategory", page.title, page.category.rawValue, sub)
            } else {
                savedText = KairoL10n.string("chat.infoPage.saved", page.title, page.category.rawValue)
            }
            let infoMessage = ChatMessage(
                role: .system,
                text: savedText
            )
            currentThread.append(infoMessage, now: infoMessage.createdAt)
            await persistCurrentThread()
            NotificationCenter.default.post(name: .infoPageSaved, object: nil)
        } catch {
            errorMessage = KairoL10n.string("chat.infoPage.saveFailed", error.localizedDescription)
        }
    }

    private func enrichLinkedAssets(from draft: InfoPageDraft, page: InfoPage) async {
        guard let api = knowledgeAssetAPI, !page.assetIDs.isEmpty else { return }
        do {
            let allAssets = try await api.list(limit: 200)
            let wanted = Set(page.assetIDs)
            for asset in allAssets where wanted.contains(asset.id) {
                let enriched = Self.enrichedAsset(asset, draft: draft, page: page)
                if enriched != asset {
                    try await api.save(enriched)
                }
            }
        } catch {
            // Non-fatal: detail view can still render via existing assetIDs.
        }
    }

    static func enrichedAsset(_ asset: KnowledgeAsset, draft: InfoPageDraft, page: InfoPage) -> KnowledgeAsset {
        var enriched = asset
        if !enriched.linkedInfoPageIDs.contains(page.id) {
            enriched.linkedInfoPageIDs.append(page.id)
        }

        if let description = draft.assetDescription?.trimmingCharacters(in: .whitespacesAndNewlines),
           !description.isEmpty,
           enriched.generatedDescription?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
            enriched.generatedDescription = description
        }

        let summaryCandidates = [
            draft.ocrSummary,
            draft.summary,
            page.summary
        ]
        if enriched.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let summary = summaryCandidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            enriched.summary = summary
        }

        let keywordTags = draft.keywords ?? []
        enriched.tags = mergedUniqueStrings(
            existing: enriched.tags,
            additions: keywordTags + [page.category.rawValue, page.templateID.rawValue]
        )

        let collections = [draft.folderName, draft.candidateCategories?.first?.folderName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        enriched.collections = mergedUniqueStrings(existing: enriched.collections, additions: collections)

        if enriched != asset {
            enriched.updatedAt = Date()
        }
        return enriched
    }

    private static func mergedUniqueStrings(existing: [String], additions: [String]) -> [String] {
        var result = existing
        for value in additions {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !result.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame })
            else { continue }
            result.append(trimmed)
        }
        return result
    }

    private struct PersistedAttachmentResult {
        var attachments: [ChatAttachment]
        var assetIDs: [UUID]
    }

    private func persistAttachmentsAsKnowledgeAssets(
        _ attachments: [ChatAttachment],
        userText: String
    ) async -> PersistedAttachmentResult {
        guard let api = knowledgeAssetAPI, !attachments.isEmpty else {
            return PersistedAttachmentResult(attachments: attachments, assetIDs: [])
        }
        var resultAttachments: [ChatAttachment] = []
        var assetIDs: [UUID] = []
        for original in attachments {
            guard original.kind == .image else {
                resultAttachments.append(original)
                continue
            }
            guard let stableURL = copyToPersistentLocation(original.fileURL) else {
                resultAttachments.append(original)
                continue
            }
            var stableAttachment = original
            stableAttachment.fileURL = stableURL
            resultAttachments.append(stableAttachment)
            let title = trimmedTitle(from: userText) ?? defaultImageTitle()
            let asset = KnowledgeAsset(
                title: title,
                kind: .image,
                source: .chat,
                attachments: [stableAttachment],
                extractedText: original.textPreview ?? "",
                summary: trimmedTitle(from: userText) ?? ""
            )
            do {
                try await api.save(asset)
                assetIDs.append(asset.id)
            } catch {
                // Best effort: keep going if a single save fails.
            }
        }
        return PersistedAttachmentResult(attachments: resultAttachments, assetIDs: assetIDs)
    }

    private func copyToPersistentLocation(_ source: URL?) -> URL? {
        guard let source else { return nil }
        guard let rootDirectory = chatAttachmentRootDirectory else { return source }
        let destinationDirectory = rootDirectory
        let destination = destinationDirectory.appendingPathComponent(
            "\(UUID().uuidString)-\(source.lastPathComponent)"
        )
        do {
            try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            if source.path == destination.path { return source }
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: source, to: destination)
            return destination
        } catch {
            return source
        }
    }

    private func trimmedTitle(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return String(trimmed.prefix(80))
    }

    private func defaultImageTitle() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return KairoL10n.string("chat.attachment.image.defaultTitle", formatter.string(from: Date()))
    }

    public func previewAction(_ action: AgentAction) {
        pendingAction = action
        if shareImportReviewAction?.id == action.id {
            shareImportReviewAction = nil
        }
        if calendarReviewAction?.id == action.id {
            calendarReviewAction = nil
        }
        if handoffReviewAction?.id == action.id {
            handoffReviewAction = nil
        }
        actionResultMessage = nil
        actionResultSucceeded = nil
    }

    public func reviewImportedShareAction() {
        guard let action = shareImportReviewAction else { return }
        presentImportedShareReview(action)
    }

    public func reviewCalendarAction() {
        guard let action = calendarReviewAction else { return }
        previewAction(action)
        pendingActionSource = .calendarReview
    }

    public func reviewHandoffAction() {
        guard let action = handoffReviewAction else { return }
        previewAction(action)
        pendingActionSource = .handoffReview
    }

    public func replyToMessage(_ message: ChatMessage) {
        replyTarget = message
        errorMessage = nil
    }

    public func cancelReplyTarget() {
        replyTarget = nil
    }

    public func refreshProviderRouteStatus() async {
        var openAIStatus = try? await openAISettingsService?.status()
        if openAIStatus?.hasAPIKey != true {
            let omlxEndpoint = UserDefaults.standard.string(forKey: "omlx_endpoint") ?? ""
            let omlxAPIKey = UserDefaults.standard.string(forKey: "omlx_api_key") ?? ""
            if !omlxEndpoint.isEmpty && !omlxAPIKey.isEmpty {
                let omlxDisplayName = UserDefaults.standard.string(forKey: "omlx_display_name") ?? ""
                openAIStatus = OpenAISettingsStatus(hasAPIKey: true, providerName: omlxDisplayName.isEmpty ? "OpenAI Compatible" : omlxDisplayName)
            }
        }
        guard let localModelSettingsService else {
            providerRouteStatus = ChatProviderRouteStatusBuilder.build(from: nil, openAIStatus: openAIStatus)
            return
        }
        providerRouteStatus = ChatProviderRouteStatusBuilder.build(
            from: await localModelSettingsService.status(),
            openAIStatus: openAIStatus,
            localRuntimeAvailable: localModelChatRuntimeAvailable
        )
    }

    public func setProviderRoutePreference(_ preference: ProviderRoutePreference) async {
        guard let localModelSettingsService else {
            errorMessage = KairoL10n.string("chat.error.routeUnavailable")
            return
        }
        do {
            try await localModelSettingsService.setPreference(preference)
            await refreshProviderRouteStatus()
            errorMessage = nil
        } catch {
            errorMessage = KairoL10n.string("chat.error.updateRoute", error.localizedDescription)
        }
    }

    public func selectProviderRouteOption(_ option: ChatProviderRouteOption) async {
        guard option.isEnabled else { return }
        guard let localModelSettingsService else {
            errorMessage = KairoL10n.string("chat.error.routeUnavailable")
            return
        }
        do {
            if let modelID = option.modelID {
                try await localModelSettingsService.selectModel(id: modelID)
            }
            try await localModelSettingsService.setPreference(option.preference)
            await refreshProviderRouteStatus()
            errorMessage = nil
        } catch {
            errorMessage = KairoL10n.string("chat.error.updateRoute", error.localizedDescription)
        }
    }

    public func setPrivateChatEnabled(_ enabled: Bool) {
        privacyMode = enabled ? .privateChat : .standard
        errorMessage = nil
        clearTransientActionState()
    }

    public func cancelPendingAction() {
        if let action = pendingAction {
            switch pendingActionSource {
            case .importedShare:
                _ = presentNextImportedShareReviewIfAvailable()
                return
            case .calendarReview:
                calendarReviewAction = action
            case .handoffReview:
                handoffReviewAction = action
            case nil:
                break
            }
        }
        pendingAction = nil
        pendingActionSource = nil
    }

    public func confirmPendingAction() async {
        guard let action = pendingAction else { return }
        let actionSource = pendingActionSource
        do {
            let result = try await actionAPI.confirm(action)
            actionResultMessage = Self.actionResultMessage(for: result, action: action, source: actionSource)
            actionResultSucceeded = result.completed
            if actionSource == .importedShare, result.completed {
                if presentNextImportedShareReviewIfAvailable() {
                    errorMessage = nil
                    return
                } else {
                    let importedItemIDs = importedShareItemIDs
                    let importedAttachments = pendingAttachments
                    try await shareImportAPI.clearImportedShares(ids: importedItemIDs, attachments: importedAttachments)
                    clearShareImportState()
                    await refreshBriefingSnapshot()
                }
            }
            errorMessage = nil
        } catch {
            actionResultMessage = KairoL10n.string("chat.action.error.failed", error.localizedDescription)
            actionResultSucceeded = false
            errorMessage = KairoL10n.string("chat.error.actionUnavailable")
        }
        pendingAction = nil
        pendingActionSource = nil
    }

    private func presentImportedShareReview(_ action: AgentAction) {
        importedShareReviewQueue.removeAll { $0.id == action.id }
        previewAction(action)
        pendingActionSource = .importedShare
        shareImportReviewAction = importedShareReviewQueue.first
    }

    private func presentNextImportedShareReviewIfAvailable() -> Bool {
        pendingAction = nil
        pendingActionSource = nil
        guard let nextAction = importedShareReviewQueue.first else {
            shareImportReviewAction = nil
            return false
        }
        presentImportedShareReview(nextAction)
        return true
    }

    private func clearTransientActionState() {
        pendingAction = nil
        pendingActionSource = nil
        shareImportReviewAction = nil
        importedShareReviewQueue = []
        calendarReviewAction = nil
        handoffReviewAction = nil
        actionResultMessage = nil
        actionResultSucceeded = nil
    }

    private func startInferenceProgressListenerIfNeeded() {
        guard inferenceProgressTask == nil else { return }
        inferenceProgressTask = Task { [weak self] in
            let stream = await AIInferenceProgressCenter.shared.stream()
            for await snapshot in stream {
                self?.applyInferenceProgress(snapshot)
            }
        }
    }

    private func applyInferenceProgress(_ snapshot: AIInferenceProgressSnapshot) {
        guard snapshot.conversationID == currentThread.id.uuidString, isLoading else { return }
        latestInferenceMetrics = snapshot.metrics
    }

    private func clearShareImportState() {
        pendingAttachments = []
        importedShareItemIDs = []
        importedShareReviewQueue = []
        shareImportNotice = nil
        shareImportPreview = nil
    }

    private func localConversationHistory() -> [AIConversationTurn] {
        var messages = currentThread.messages
        if let last = messages.last, last.role == .user {
            messages.removeLast()
        }
        var turns: [AIConversationTurn] = []
        if let summary = currentThread.rollingSummary?.trimmingCharacters(in: .whitespacesAndNewlines), !summary.isEmpty {
            turns.append(AIConversationTurn(
                role: .assistant,
                text: "[Earlier conversation summary]\n\(summary)"
            ))
        }
        let priorTurns: [AIConversationTurn] = messages
            .filter { $0.id != Self.welcomeMessage.id }
            .compactMap { message in
                let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let hasAttachment = !message.attachments.isEmpty
                guard !text.isEmpty || hasAttachment else { return nil }
                let turnText = text.isEmpty ? KairoL10n.string("chat.history.imagePlaceholder") : text
                switch message.role {
                case .user:
                    return AIConversationTurn(role: .user, text: turnText)
                case .assistant:
                    return AIConversationTurn(role: .assistant, text: turnText)
                case .system:
                    return nil
                }
            }
        turns.append(contentsOf: priorTurns)
        return turns
    }

    private func runtimeConversationID() -> String {
        let generation = currentThread.compactionGeneration
        guard generation > 0 else { return currentThread.id.uuidString }
        return "\(currentThread.id.uuidString)#g\(generation)"
    }

    private func compactCurrentThreadIfNeeded(forPendingUserText text: String) async {
        guard let compactor = threadCompactor else { return }
        let budget = await activeContextBudget()
        let pressure = compactor.pressure(
            for: currentThread,
            additionalUserTextChars: text.count,
            budget: budget
        )
        guard pressure == .hard else { return }
        do {
            let result = try await compactor.compact(currentThread, budget: budget)
            guard result.summarizedMessageCount > 0 else { return }
            currentThread = result.thread
            await persistCurrentThread()
        } catch {
            // Compaction is best-effort. Log via inference channel; do not block the send.
            errorMessage = nil
        }
    }

    private func activeContextBudget() async -> ChatContextBudget {
        if let localStatus = await localModelSettingsService?.status(),
           let manifest = localStatus.selectedModel {
            let runtimeContext = localStatus.runtimeParametersByModelID[manifest.id]?.contextSize
            let effective = min(manifest.contextWindow, runtimeContext ?? manifest.contextWindow)
            return ChatContextBudget(contextWindow: effective)
        }
        if providerRouteStatus.options.contains(where: { $0.id.hasPrefix("cloud.") && $0.isEnabled }) {
            return ChatContextBudget(contextWindow: 128_000, reservedOutputTokens: 4096)
        }
        return ChatContextBudget(contextWindow: 8192)
    }

    private static func actionResultMessage(for result: ActionExecutionResult, action: AgentAction, source: PendingActionSource?) -> String {
        guard result.completed else {
            switch action.payload {
            case .reminder:
                return KairoL10n.string("chat.action.result.reminder.failure", localizedExecutionDetail(for: result.message))
            case .calendarEvent:
                return KairoL10n.string("chat.action.result.calendar.failure", localizedExecutionDetail(for: result.message))
            default:
                return localizedActionResultPrefix(for: action, completed: false)
            }
        }
        let suffix = source == .importedShare ? KairoL10n.string("chat.action.result.shareClearedSuffix") : ""
        switch action.payload {
        case .reminder(let draft):
            return KairoL10n.string("chat.action.result.reminder.success", draft.title, suffix)
        case .calendarEvent(let draft):
            return KairoL10n.string("chat.action.result.calendar.success", draft.title, suffix)
        default:
            return "\(localizedActionResultPrefix(for: action, completed: true))\(suffix)"
        }
    }

    private static func localizedActionResultPrefix(for action: AgentAction, completed: Bool) -> String {
        switch action.kind {
        case .composeEmailDraft:
            return KairoL10n.string(completed ? "chat.action.result.email.success" : "chat.action.result.email.failure")
        case .openMapDirections:
            return KairoL10n.string(completed ? "chat.action.result.maps.success" : "chat.action.result.maps.failure")
        case .openMessageHandoff:
            return KairoL10n.string(completed ? "chat.action.result.message.success" : "chat.action.result.message.failure")
        case .openPhoneCallHandoff:
            return KairoL10n.string(completed ? "chat.action.result.phone.success" : "chat.action.result.phone.failure")
        case .openWebSearchHandoff:
            return KairoL10n.string(completed ? "chat.action.result.web.success" : "chat.action.result.web.failure")
        case .createContactDraft:
            return KairoL10n.string(completed ? "chat.action.result.contact.success" : "chat.action.result.contact.failure")
        case .sendNotification:
            return KairoL10n.string(completed ? "chat.action.result.notification.success" : "chat.action.result.notification.failure")
        case .saveMemory:
            return KairoL10n.string(completed ? "chat.action.result.memory.success" : "chat.action.result.memory.failure")
        case .openURL:
            return KairoL10n.string(completed ? "chat.action.result.url.success" : "chat.action.result.url.failure")
        default:
            return KairoL10n.string(completed ? "chat.action.result.generic.success" : "chat.action.result.generic.failure")
        }
    }

    private static func localizedExecutionDetail(for message: String) -> String {
        switch message {
        case KairoL10n.string("chat.action.permission.reminders.off"):
            return KairoL10n.string("chat.action.permission.reminders.off")
        case KairoL10n.string("chat.action.permission.calendar.off"):
            return KairoL10n.string("chat.action.permission.calendar.off")
        default:
            return message
        }
    }

    private func persistCurrentThread() async {
        guard privacyMode != .privateChat else { return }
        do {
            try await historyStore.saveThread(currentThread)
            threads = try await historyStore.listThreads(limit: 50)
        } catch {
            errorMessage = KairoL10n.string("chat.error.saveHistory", error.localizedDescription)
        }
    }

    private func firstReminderActionFromLatestAssistantMessage() -> AgentAction? {
        let latestActions = currentThread.messages
            .reversed()
            .first { $0.role == .assistant && !$0.proposedActions.isEmpty }?
            .proposedActions ?? []
        return latestActions.first { $0.kind == .createReminderDraft }
    }

    private func firstCalendarActionFromLatestAssistantMessage() -> AgentAction? {
        let latestActions = currentThread.messages
            .reversed()
            .first { $0.role == .assistant && !$0.proposedActions.isEmpty }?
            .proposedActions ?? []
        return latestActions.first { $0.kind == .createCalendarDraft }
    }

    private func firstHandoffActionFromLatestAssistantMessage() -> AgentAction? {
        let latestActions = currentThread.messages
            .reversed()
            .first { $0.role == .assistant && !$0.proposedActions.isEmpty }?
            .proposedActions ?? []
        return latestActions.first { action in
            switch action.kind {
            case .composeEmailDraft, .openMapDirections, .openMessageHandoff, .openPhoneCallHandoff, .openWebSearchHandoff:
                return true
            default:
                return false
            }
        }
    }

    private func composedMessageText(text: String, replyTarget: ChatMessage?, hasAttachments: Bool) -> String {
        let body = text
        guard let replyTarget else {
            return body
        }
        return KairoL10n.string("chat.reply.composedPrefix", Self.replyReferenceText(for: replyTarget), body)
    }

    public static func replyReferenceText(for message: ChatMessage) -> String {
        let singleLine = message.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleLine.isEmpty else {
            return KairoL10n.string("chat.reply.selectedMessage")
        }
        return String(singleLine.prefix(140))
    }

    private static func shareImportNotice(importedCount: Int) -> String {
        if importedCount == 1 {
            return KairoL10n.string("chat.share.import.notice.one")
        }
        return KairoL10n.string("chat.share.import.notice.many", Int64(importedCount))
    }

    private static func shareImportPreview(for attachments: [ChatAttachment]) -> String? {
        let previews = attachments.prefix(3).map { attachment in
            let detail = attachment.textPreview.map(Self.singleLinePreview)
            guard let detail, !detail.isEmpty else {
                return attachment.displayName
            }
            return "\(attachment.displayName): \(String(detail.prefix(120)))"
        }
        guard !previews.isEmpty else { return nil }
        return previews.joined(separator: " • ")
    }

    private static func singleLinePreview(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func isSummarizeSharePrompt(_ prompt: String) -> Bool {
        if prompt.localizedCaseInsensitiveContains("summarize") {
            return true
        }
        if prompt == KairoL10n.string("chat.share.prompt.summarizeDefault") {
            return true
        }
        let localizedNamedFormat = KairoL10n.string("chat.share.prompt.summarizeNamed", "")
        let localizedPrefix = localizedNamedFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        if !localizedPrefix.isEmpty && prompt.hasPrefix(localizedPrefix) {
            return true
        }
        let urlPromptFormat = KairoL10n.string("chat.share.prompt.readURLs", "")
        let urlPromptPrefix = urlPromptFormat.trimmingCharacters(in: .whitespacesAndNewlines)
        return !urlPromptPrefix.isEmpty && prompt.hasPrefix(urlPromptPrefix)
    }

    private static func userFacingChatErrorMessage(for error: Error) -> String {
        if let providerError = error as? AIProviderError {
            switch providerError {
            case .missingCredential:
                return KairoL10n.string("chat.error.openAIKeyMissing")
            case .unsupported:
                return KairoL10n.string("chat.error.localOnlyUnsupported")
            case .localInferenceUnavailable(let message):
                return KairoL10n.string("chat.error.localInferenceUnavailable", message)
            case .requestFailed(let message):
                return KairoL10n.string("chat.error.requestFailed", message)
            }
        }
        return KairoL10n.string("chat.error.genericReplyFailed", error.localizedDescription)
    }

    private static func inferenceStatusText(isLoading: Bool, metrics: AIInferenceMetrics?) -> String {
        let prefix = isLoading
            ? KairoL10n.string("chat.loading")
            : KairoL10n.string("chat.inference.latest")
        guard let metrics else {
            return isLoading
                ? KairoL10n.string("chat.inference.waitingStatus")
                : KairoL10n.string("chat.inference.status", prefix, "--", "--")
        }
        if isLoading {
            switch metrics.stage {
            case .preparingInput:
                return KairoL10n.string("chat.inference.preparingInputStatus")
            case .loadingModel:
                return KairoL10n.string("chat.inference.loadingModelStatus")
            case .prefill:
                break
            case .generation, .complete:
                if let generatedTokens = metrics.generatedTokens, generatedTokens > 0 {
                    return KairoL10n.string(
                        "chat.inference.generationStatus",
                        formattedRate(metrics.generationTokensPerSecond)
                    )
                }
            case .none:
                break
            }
        }
        if isLoading,
           let generatedTokens = metrics.generatedTokens,
           generatedTokens > 0 {
            return KairoL10n.string(
                "chat.inference.generationStatus",
                formattedRate(metrics.generationTokensPerSecond)
            )
        }
        if let processed = metrics.promptTokensProcessed,
           let total = metrics.promptTokens,
           total > 0,
           processed < total {
            if isLoading {
                return KairoL10n.string(
                    "chat.inference.prefillStatus",
                    formattedPercent(processed: processed, total: total),
                    formattedRate(metrics.promptTokensPerSecond)
                )
            }
            return KairoL10n.string(
                "chat.inference.statusWithPromptProgress",
                prefix,
                formattedRate(metrics.promptTokensPerSecond),
                formattedTokenCount(processed),
                formattedTokenCount(total),
                formattedETA(metrics.promptSecondsRemaining),
                formattedRate(metrics.generationTokensPerSecond)
            )
        }
        return KairoL10n.string(
            "chat.inference.status",
            prefix,
            formattedRate(metrics.promptTokensPerSecond),
            formattedRate(metrics.generationTokensPerSecond)
        )
    }

    private static func formattedRate(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "--" }
        if value >= 10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    private static func formattedTokenCount(_ value: Int) -> String {
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000.0)
        }
        return "\(value)"
    }

    private static func formattedPercent(processed: Int, total: Int) -> String {
        guard total > 0 else { return "--" }
        let percent = min(100, max(0, Int((Double(processed) / Double(total) * 100).rounded())))
        return "\(percent)"
    }

    private static func formattedETA(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "--" }
        let seconds = max(1, Int(ceil(value)))
        return KairoL10n.string("chat.inference.eta", "\(seconds)")
    }

    public static func promptPipelineHealthSummary(for messages: [ChatMessage]) -> ChatPromptPipelineHealthSummary? {
        let traces = messages
            .compactMap(\.promptPipelineTrace)
            .suffix(8)
        guard let latest = traces.last else { return nil }

        let providerCounts = Dictionary(grouping: traces, by: \.providerID)
            .mapValues(\.count)
        let providerID = providerCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .first?.key ?? latest.providerID

        return ChatPromptPipelineHealthSummary(
            providerID: providerID,
            traceCount: traces.count,
            validatedCount: traces.filter { $0.status == .validated }.count,
            repairCount: traces.reduce(0) { $0 + $1.repairedStageCount },
            failedCount: traces.reduce(0) { $0 + $1.failedStageCount },
            latestStatus: latest.status
        )
    }

    public static func pipelineDiagnosticPrompt(for summary: ChatPromptPipelineHealthSummary) -> String {
        KairoL10n.string(
            "chat.pipeline.diagnostic.prompt",
            summary.providerID,
            Int64(summary.traceCount),
            Int64(summary.validatedCount),
            Int64(summary.repairCount),
            Int64(summary.failedCount)
        )
    }

    public static let welcomeMessage = ChatMessage(
        role: .assistant,
        text: KairoL10n.string("chat.welcome.default")
    )

    private enum PendingActionSource {
        case importedShare
        case calendarReview
        case handoffReview
    }
}
#endif
