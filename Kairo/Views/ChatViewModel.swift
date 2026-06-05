#if canImport(SwiftUI)
import Foundation
import SwiftUI

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

    private let historyStore: ChatHistoryStore
    private let shareImportAPI: any KairoShareImportAPI
    private let chatAPI: any KairoChatAPI
    private let actionAPI: any KairoActionAPI
    private let localModelSettingsService: LocalModelSettingsService?
    private let openAISettingsService: OpenAISettingsService?
    private let localModelChatRuntimeAvailable: Bool
    private var pendingActionSource: PendingActionSource?
    private var importedShareItemIDs: [UUID] = []

    public init(
        dependencies: ChatFeatureDependencies
    ) {
        self.historyStore = dependencies.historyStore
        self.shareImportAPI = dependencies.shareImportAPI
        self.chatAPI = dependencies.chatAPI
        self.actionAPI = dependencies.actionAPI
        self.localModelSettingsService = dependencies.localModelSettingsService
        self.openAISettingsService = dependencies.openAISettingsService
        self.localModelChatRuntimeAvailable = dependencies.localModelChatRuntimeAvailable
        self.currentThread = ChatThread(messages: [Self.welcomeMessage])
        self.providerRouteStatus = ChatProviderRouteStatusBuilder.build(from: nil)
    }

    public convenience init(
        historyStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        shareImportAPI: (any KairoShareImportAPI)? = nil,
        chatAPI: (any KairoChatAPI)? = nil,
        actionAPI: (any KairoActionAPI)? = nil,
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
        do {
            threads = try await historyStore.listThreads(limit: 50)
            if let first = threads.first {
                currentThread = first
            } else {
                currentThread = ChatThread(messages: [Self.welcomeMessage])
            }
            errorMessage = nil
            await refreshProviderRouteStatus()
        } catch {
            errorMessage = KairoL10n.string("chat.error.loadHistory", error.localizedDescription)
        }
    }

    public func startNewThread() {
        currentThread = ChatThread(messages: [Self.welcomeMessage])
        composerText = ""
        replyTarget = nil
        clearShareImportState()
        errorMessage = nil
        clearTransientActionState()
    }

    public func selectThread(_ thread: ChatThread) {
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
                    memoryContextCount: message.memoryContextCount
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

    public func importPendingShares() async {
        guard !canSendImportedShareToChat else { return }
        do {
            let imported = try await shareImportAPI.importPendingShares(limit: 10)
            guard !imported.isEmpty else { return }
            pendingAttachments.append(contentsOf: imported.attachments)
            importedShareItemIDs = imported.importedItemIDs
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                composerText = imported.suggestedPrompt ?? KairoL10n.string("chat.share.prompt.summarizeDefault")
            }
            shareImportNotice = Self.shareImportNotice(importedCount: imported.importedItemIDs.count)
            shareImportPreview = Self.shareImportPreview(for: imported.attachments)
            shareImportReviewAction = nil
            errorMessage = nil
        } catch {
            errorMessage = KairoL10n.string("chat.error.importShare", error.localizedDescription)
        }
    }

    public func sendImportedShareToChat() async {
        guard canSendImportedShareToChat else { return }
        let importedItemIDs = importedShareItemIDs
        let importedAttachments = pendingAttachments
        await sendComposerMessage()
        do {
            try await shareImportAPI.clearImportedShares(ids: importedItemIDs, attachments: importedAttachments)
            importedShareItemIDs = []
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
        let userMessage = ChatMessage(role: .user, text: text, attachments: attachments)
        currentThread.append(userMessage, now: userMessage.createdAt)
        await persistCurrentThread()

        isLoading = true
        errorMessage = nil
        do {
            let response = try await chatAPI.respond(to: text, attachments: attachments, privacyMode: privacyMode)
            let assistantMessage = ChatMessage(
                role: .assistant,
                text: response.message,
                proposedActions: response.proposedActions,
                toolCandidates: response.toolCandidates,
                memoryContextCount: response.memoryContextCount
            )
            currentThread.append(assistantMessage, now: assistantMessage.createdAt)
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
        previewAction(action)
        pendingActionSource = .importedShare
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
        let openAIStatus = try? await openAISettingsService?.status()
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

    public func setPrivateChatEnabled(_ enabled: Bool) {
        privacyMode = enabled ? .privateChat : .standard
        errorMessage = nil
        clearTransientActionState()
    }

    public func cancelPendingAction() {
        if let action = pendingAction {
            switch pendingActionSource {
            case .importedShare:
                shareImportReviewAction = action
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
            errorMessage = nil
        } catch {
            actionResultMessage = KairoL10n.string("chat.action.error.failed", error.localizedDescription)
            actionResultSucceeded = false
            errorMessage = KairoL10n.string("chat.error.actionUnavailable")
        }
        pendingAction = nil
        pendingActionSource = nil
    }

    private func clearTransientActionState() {
        pendingAction = nil
        pendingActionSource = nil
        shareImportReviewAction = nil
        calendarReviewAction = nil
        handoffReviewAction = nil
        actionResultMessage = nil
        actionResultSucceeded = nil
    }

    private func clearShareImportState() {
        pendingAttachments = []
        importedShareItemIDs = []
        shareImportNotice = nil
        shareImportPreview = nil
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
        let fallback = hasAttachments
            ? KairoL10n.string("chat.composer.fallback.reviewAttachments")
            : KairoL10n.string("chat.composer.fallback.replySelected")
        let body = text.isEmpty ? fallback : text
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
        return !localizedPrefix.isEmpty && prompt.hasPrefix(localizedPrefix)
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
