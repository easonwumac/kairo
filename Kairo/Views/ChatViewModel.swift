#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var threads: [ChatThread] = []
    @Published public private(set) var currentThread: ChatThread
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var pendingAttachments: [ChatAttachment] = []
    @Published public var composerText: String = ""
    @Published public var errorMessage: String?
    @Published public var pendingAction: AgentAction?
    @Published public private(set) var actionResultMessage: String?
    @Published public private(set) var replyTarget: ChatMessage?

    private let historyStore: ChatHistoryStore
    private let shareIngestionQueue: ShareIngestionQueue
    private let agent: AgentCore
    private let actionExecutor: any ActionExecutor

    public init(
        historyStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        shareIngestionQueue: ShareIngestionQueue = InMemoryShareIngestionQueue(),
        agent: AgentCore = AgentCore(),
        actionExecutor: any ActionExecutor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
    ) {
        self.historyStore = historyStore
        self.shareIngestionQueue = shareIngestionQueue
        self.agent = agent
        self.actionExecutor = actionExecutor
        self.currentThread = ChatThread(messages: [Self.welcomeMessage])
    }

    public convenience init(environment: KairoEnvironment) {
        self.init(
            historyStore: environment.chatHistoryStore,
            shareIngestionQueue: environment.shareIngestionQueue,
            agent: AgentCore(memoryStore: environment.memoryStore, aiProvider: environment.aiProvider),
            actionExecutor: environment.actionExecutor
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
        } catch {
            errorMessage = "無法載入聊天紀錄：\(error.localizedDescription)"
        }
    }

    public func startNewThread() {
        currentThread = ChatThread(messages: [Self.welcomeMessage])
        composerText = ""
        replyTarget = nil
        pendingAttachments = []
        errorMessage = nil
    }

    public func selectThread(_ thread: ChatThread) {
        currentThread = thread
        composerText = ""
        replyTarget = nil
        errorMessage = nil
    }

    public func deleteThread(_ thread: ChatThread) async {
        do {
            try await historyStore.deleteThread(id: thread.id)
            threads = try await historyStore.listThreads(limit: 50)
            if currentThread.id == thread.id {
                currentThread = threads.first ?? ChatThread(messages: [Self.welcomeMessage])
            }
            errorMessage = nil
        } catch {
            errorMessage = "無法刪除聊天紀錄：\(error.localizedDescription)"
        }
    }

    public func importPendingShares() async {
        do {
            let items = try await shareIngestionQueue.pendingItems(limit: 10)
            guard !items.isEmpty else { return }
            let importedAttachments = items.flatMap(\.attachments)
            pendingAttachments.append(contentsOf: importedAttachments)
            if composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                composerText = items.first?.suggestedPrompt ?? "Review the shared content."
            }
            for item in items {
                try await shareIngestionQueue.markImported(id: item.id)
            }
            errorMessage = nil
        } catch {
            errorMessage = "無法匯入分享內容：\(error.localizedDescription)"
        }
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
        let attachments = pendingAttachments
        let replyTarget = replyTarget
        composerText = ""
        pendingAttachments = []
        self.replyTarget = nil
        await send(composedMessageText(text: text, replyTarget: replyTarget, hasAttachments: !attachments.isEmpty), attachments: attachments)
    }

    public func send(_ text: String, attachments: [ChatAttachment] = []) async {
        let userMessage = ChatMessage(role: .user, text: text, attachments: attachments)
        currentThread.append(userMessage, now: userMessage.createdAt)
        await persistCurrentThread()

        isLoading = true
        errorMessage = nil
        do {
            let response = try await agent.respond(to: text, attachments: attachments)
            let assistantMessage = ChatMessage(
                role: .assistant,
                text: response.message,
                proposedActions: response.proposedActions,
                toolCandidates: response.toolCandidates
            )
            currentThread.append(assistantMessage, now: assistantMessage.createdAt)
            await persistCurrentThread()
        } catch {
            let failedMessage = ChatMessage(
                role: .assistant,
                text: "發生錯誤：\(error.localizedDescription)",
                status: .failed
            )
            currentThread.append(failedMessage, now: failedMessage.createdAt)
            errorMessage = "Kairo 暫時無法回覆，請稍後再試。"
            await persistCurrentThread()
        }
        isLoading = false
    }

    public func previewAction(_ action: AgentAction) {
        pendingAction = action
        actionResultMessage = nil
    }

    public func replyToMessage(_ message: ChatMessage) {
        replyTarget = message
        errorMessage = nil
    }

    public func cancelReplyTarget() {
        replyTarget = nil
    }

    public func cancelPendingAction() {
        pendingAction = nil
    }

    public func confirmPendingAction() async {
        guard let action = pendingAction else { return }
        do {
            let result = try await actionExecutor.execute(action, confirmed: true)
            actionResultMessage = result.message
            errorMessage = nil
        } catch {
            actionResultMessage = "Action failed: \(error.localizedDescription)"
            errorMessage = "Kairo 無法執行此動作。"
        }
        pendingAction = nil
    }

    private func persistCurrentThread() async {
        do {
            try await historyStore.saveThread(currentThread)
            threads = try await historyStore.listThreads(limit: 50)
        } catch {
            errorMessage = "無法儲存聊天紀錄：\(error.localizedDescription)"
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

    public static let welcomeMessage = ChatMessage(
        role: .assistant,
        text: "我是 Kairo。你可以直接聊天，我會保留這裡的對話紀錄，並只使用你授權與 iOS sandbox 允許的能力。"
    )
}
#endif
