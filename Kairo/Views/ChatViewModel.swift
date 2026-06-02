#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class ChatViewModel: ObservableObject {
    @Published public private(set) var threads: [ChatThread] = []
    @Published public private(set) var currentThread: ChatThread
    @Published public private(set) var isLoading: Bool = false
    @Published public var composerText: String = ""
    @Published public var errorMessage: String?

    private let historyStore: ChatHistoryStore
    private let agent: AgentCore

    public init(
        historyStore: ChatHistoryStore = InMemoryChatHistoryStore(),
        agent: AgentCore = AgentCore()
    ) {
        self.historyStore = historyStore
        self.agent = agent
        self.currentThread = ChatThread(messages: [Self.welcomeMessage])
    }

    public convenience init(environment: KairoEnvironment) {
        self.init(
            historyStore: environment.chatHistoryStore,
            agent: AgentCore(memoryStore: environment.memoryStore, aiProvider: environment.aiProvider)
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
        errorMessage = nil
    }

    public func selectThread(_ thread: ChatThread) {
        currentThread = thread
        composerText = ""
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

    public func sendComposerMessage() async {
        let text = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        composerText = ""
        await send(text)
    }

    public func send(_ text: String) async {
        let userMessage = ChatMessage(role: .user, text: text)
        currentThread.append(userMessage, now: userMessage.createdAt)
        await persistCurrentThread()

        isLoading = true
        errorMessage = nil
        do {
            let response = try await agent.respond(to: text)
            let assistantMessage = ChatMessage(
                role: .assistant,
                text: response.message,
                proposedActions: response.proposedActions
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

    private func persistCurrentThread() async {
        do {
            try await historyStore.saveThread(currentThread)
            threads = try await historyStore.listThreads(limit: 50)
        } catch {
            errorMessage = "無法儲存聊天紀錄：\(error.localizedDescription)"
        }
    }

    public static let welcomeMessage = ChatMessage(
        role: .assistant,
        text: "我是 Kairo。你可以直接聊天，我會保留這裡的對話紀錄，並只使用你授權與 iOS sandbox 允許的能力。"
    )
}
#endif
