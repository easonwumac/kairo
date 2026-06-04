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
        if prompt.hasPrefix("建立提醒事項：") {
            return "Extract Tasks"
        }
        return prompt.localizedCaseInsensitiveContains("summarize") ? "Summarize" : "Send to Chat"
    }

    private let historyStore: ChatHistoryStore
    private let shareImportAPI: any KairoShareImportAPI
    private let chatAPI: any KairoChatAPI
    private let actionExecutor: any ActionExecutor
    private let localModelSettingsService: LocalModelSettingsService?
    private var pendingActionSource: PendingActionSource?

    public init(
        historyStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        agent: AgentCore = AgentCore(),
        shareImportAPI: (any KairoShareImportAPI)? = nil,
        chatAPI: (any KairoChatAPI)? = nil,
        actionExecutor: any ActionExecutor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore()),
        localModelSettingsService: LocalModelSettingsService? = nil
    ) {
        self.historyStore = historyStore
        self.shareImportAPI = shareImportAPI ?? KairoShareImportBackendService(shareIngestionQueue: shareIngestionQueue)
        self.chatAPI = chatAPI ?? KairoChatBackendService(agent: agent)
        self.actionExecutor = actionExecutor
        self.localModelSettingsService = localModelSettingsService
        self.currentThread = ChatThread(messages: [Self.welcomeMessage])
        self.providerRouteStatus = ChatProviderRouteStatusBuilder.build(from: nil)
    }

    public convenience init(environment: KairoEnvironment) {
        self.init(
            historyStore: environment.chatHistoryStore,
            shareImportAPI: environment.backendAPI.shareImports,
            chatAPI: environment.backendAPI.chat,
            actionExecutor: environment.actionExecutor,
            localModelSettingsService: environment.localModelSettingsService
        )
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
            errorMessage = "無法載入聊天紀錄：\(error.localizedDescription)"
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
            errorMessage = "無法刪除聊天紀錄：\(error.localizedDescription)"
        }
    }

    public func importPendingShares() async {
        do {
            let imported = try await shareImportAPI.importPendingShares(limit: 10)
            guard !imported.isEmpty else { return }
            pendingAttachments.append(contentsOf: imported.attachments)
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                composerText = imported.suggestedPrompt ?? "Summarize the shared content."
            }
            shareImportNotice = Self.shareImportNotice(importedCount: imported.importedItemIDs.count)
            shareImportPreview = Self.shareImportPreview(for: imported.attachments)
            shareImportReviewAction = nil
            errorMessage = nil
        } catch {
            errorMessage = "無法匯入分享內容：\(error.localizedDescription)"
        }
    }

    public func sendImportedShareToChat() async {
        guard canSendImportedShareToChat else { return }
        await sendComposerMessage()
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
    }

    public func reviewHandoffAction() {
        guard let action = handoffReviewAction else { return }
        previewAction(action)
    }

    public func replyToMessage(_ message: ChatMessage) {
        replyTarget = message
        errorMessage = nil
    }

    public func cancelReplyTarget() {
        replyTarget = nil
    }

    public func refreshProviderRouteStatus() async {
        guard let localModelSettingsService else {
            providerRouteStatus = ChatProviderRouteStatusBuilder.build(from: nil)
            return
        }
        providerRouteStatus = ChatProviderRouteStatusBuilder.build(from: await localModelSettingsService.status())
    }

    public func setProviderRoutePreference(_ preference: ProviderRoutePreference) async {
        guard let localModelSettingsService else {
            errorMessage = "目前聊天環境無法更新模型路由。"
            return
        }
        do {
            try await localModelSettingsService.setPreference(preference)
            await refreshProviderRouteStatus()
            errorMessage = nil
        } catch {
            errorMessage = "無法更新模型路由：\(error.localizedDescription)"
        }
    }

    public func setPrivateChatEnabled(_ enabled: Bool) {
        privacyMode = enabled ? .privateChat : .standard
        errorMessage = nil
    }

    public func cancelPendingAction() {
        pendingAction = nil
        pendingActionSource = nil
    }

    public func confirmPendingAction() async {
        guard let action = pendingAction else { return }
        let actionSource = pendingActionSource
        do {
            let result = try await actionExecutor.execute(action, confirmed: true)
            actionResultMessage = Self.actionResultMessage(for: result, action: action, source: actionSource)
            actionResultSucceeded = result.completed
            errorMessage = nil
        } catch {
            actionResultMessage = "Action failed: \(error.localizedDescription)"
            actionResultSucceeded = false
            errorMessage = "Kairo 無法執行此動作。"
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
        shareImportNotice = nil
        shareImportPreview = nil
    }

    private static func actionResultMessage(for result: ActionExecutionResult, action: AgentAction, source: PendingActionSource?) -> String {
        guard result.completed else {
            switch action.payload {
            case .reminder:
                return "Reminder was not created. \(result.message)"
            case .calendarEvent:
                return "Calendar event was not created. \(result.message)"
            default:
                return result.message
            }
        }
        let suffix = source == .importedShare ? " Shared content was cleared from the import queue." : ""
        switch action.payload {
        case .reminder(let draft):
            return "\(result.message) \(draft.title)\(suffix)"
        case .calendarEvent(let draft):
            return "\(result.message) \(draft.title)\(suffix)"
        default:
            return "\(result.message)\(suffix)"
        }
    }

    private func persistCurrentThread() async {
        do {
            try await historyStore.saveThread(currentThread)
            threads = try await historyStore.listThreads(limit: 50)
        } catch {
            errorMessage = "無法儲存聊天紀錄：\(error.localizedDescription)"
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
        let fallback = hasAttachments ? "Review the attached content." : "Reply to the selected message."
        let body = text.isEmpty ? fallback : text
        guard let replyTarget else {
            return body
        }
        return "Replying to \"\(Self.replyReferenceText(for: replyTarget))\":\n\(body)"
    }

    public static func replyReferenceText(for message: ChatMessage) -> String {
        let singleLine = message.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !singleLine.isEmpty else {
            return "selected message"
        }
        return String(singleLine.prefix(140))
    }

    private static func shareImportNotice(importedCount: Int) -> String {
        if importedCount == 1 {
            return "已匯入 1 個分享項目，可送進 Chat 摘要或抽任務。"
        }
        return "已匯入 \(importedCount) 個分享項目，可送進 Chat 摘要或抽任務。"
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

    private static func userFacingChatErrorMessage(for error: Error) -> String {
        if let providerError = error as? AIProviderError {
            switch providerError {
            case .missingCredential:
                return "OpenAI API key 尚未設定。請到 Settings 儲存 API key，或切換到可用的 local-only fallback 後再試。"
            case .unsupported:
                return "目前選用的 local-only fallback 無法完成這類請求。請切回 cloud provider 或選擇支援的本機模型。"
            case .requestFailed(let message):
                return "OpenAI 回覆失敗：\(message)"
            }
        }
        return "Kairo 暫時無法回覆：\(error.localizedDescription)"
    }

    public static let welcomeMessage = ChatMessage(
        role: .assistant,
        text: "我是 Kairo。直接說你想在手機上完成什麼；我會在聊天裡提出可用工具、草稿與確認卡片，不會靜默改動任何東西。"
    )

    private enum PendingActionSource {
        case importedShare
    }
}
#endif
