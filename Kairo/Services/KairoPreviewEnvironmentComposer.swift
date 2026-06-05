import Foundation

public struct KairoPreviewEnvironmentComposer: Sendable {
    public init() {}

    public func makeEnvironment() -> KairoEnvironment {
        let credentialStore = InMemoryCredentialStore()
        return KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            chatHistoryStore: InMemoryChatHistoryStore(seed: [Self.welcomeThread()]),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            kairoRecipeStore: InMemoryKairoRecipeStore(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }

    private static func welcomeThread() -> ChatThread {
        ChatThread(messages: [
            ChatMessage(role: .assistant, text: KairoL10n.string("chat.welcome.preview"))
        ])
    }
}
