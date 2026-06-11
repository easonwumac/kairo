import XCTest
@testable import KairoCore

final class KairoChatBackendAPITests: XCTestCase {
    func testChatBackendUsesSavedOpenAIKeyForOpenAIProviderRequest() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("chat-openai-key-1234567890", for: CredentialKey.openAIAPIKey)
        let httpClient = ChatBackendCapturingHTTPClient(body: #"{"output_text":"Live provider response"}"#)
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(title: "Tone", summary: "Prefers concise Traditional Chinese replies", content: "Keep answers short.", source: .manual)
            ]),
            aiProvider: OpenAIProvider(credentialStore: credentials, httpClient: httpClient)
        ))

        let response = try await api.respond(to: "Tone", attachments: [], privacyMode: .standard)

        XCTAssertEqual(response.message, "Live provider response")
        XCTAssertEqual(response.memoryContextCount, 1)
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer chat-openai-key-1234567890")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let body = try XCTUnwrap(request.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(payload["model"] as? String, "gpt-4.1")
        let input = try XCTUnwrap(payload["input"] as? [[String: String]])
        XCTAssertTrue(input.contains { message in
            message["role"] == "user"
                && (message["content"]?.contains("Tone") == true)
                && (message["content"]?.contains("Prefers concise Traditional Chinese replies") == true)
                && (message["content"]?.contains("Keep answers short.") == true)
        })
    }

    @MainActor
    func testChatViewModelSurfacesMissingOpenAIKeyAsActionableSettingsError() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(aiProvider: FailingChatBackendAIProvider(error: AIProviderError.missingCredential))
            )
        )

        await viewModel.send("Hello Kairo")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.status, .failed)
        XCTAssertEqual(assistantMessage.text, KairoL10n.string("chat.error.openAIKeyMissing"))
        XCTAssertEqual(viewModel.errorMessage, assistantMessage.text)
    }

    @MainActor
    func testChatViewModelSurfacesLocalOnlyUnavailableAsFailedMessage() async throws {
        let reason = KairoL10n.string("chat.error.localInference.reason.localOnlyNoModel")
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            chatAPI: KairoChatBackendService(
                agent: AgentCore(aiProvider: FailingChatBackendAIProvider(error: AIProviderError.localInferenceUnavailable(reason)))
            )
        )

        await viewModel.send("Draft a private reply")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.status, .failed)
        XCTAssertEqual(assistantMessage.text, KairoL10n.string("chat.error.localInferenceUnavailable", reason))
        XCTAssertEqual(viewModel.errorMessage, assistantMessage.text)
    }

    func testChatBackendAPIForwardsPrivacyModeThroughAgentCore() async throws {
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Private response"))
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(title: "Private note", summary: "Should not be queried", content: "private content", source: .manual)
            ]),
            aiProvider: provider
        ))

        let response = try await api.respond(to: "summarize private content", attachments: [], privacyMode: .privateChat)
        let request = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(request)

        XCTAssertEqual(response.message, "Private response")
        XCTAssertEqual(capturedRequest.privacyMode, .privateChat)
        XCTAssertTrue(capturedRequest.memoryContext.isEmpty)
    }

    func testChatBackendUsesNaturalLanguageMemoryMatchesInStandardChat() async throws {
        let memoryID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let provider = BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Used saved context"))
        let api = KairoChatBackendService(agent: AgentCore(
            memoryStore: InMemoryMemoryStore(seed: [
                MemoryRecord(
                    id: memoryID,
                    title: "Launch plan",
                    summary: "Send beta invites after the QA pass.",
                    content: "The Kairo beta launch plan depends on QA sign-off.",
                    source: .manual
                )
            ]),
            aiProvider: provider
        ))

        let response = try await api.respond(
            to: "What should I remember about the launch?",
            attachments: [],
            privacyMode: .standard
        )
        let capturedRequestResult = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(capturedRequestResult)

        XCTAssertEqual(response.memoryContextCount, 1)
        XCTAssertEqual(capturedRequest.memoryContext.map(\.id), [memoryID])
    }

    @MainActor
    func testChatViewModelPersistsAssistantMemoryContextCount() async throws {
        let memory = MemoryRecord(
            title: "Launch memory",
            summary: "Use this context in Chat.",
            content: "Kairo should visibly report memory context usage.",
            source: .manual
        )
        let historyStore = InMemoryChatHistoryStore()
        let viewModel = ChatViewModel(
            historyStore: historyStore,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(
                    memoryStore: InMemoryMemoryStore(seed: [memory]),
                    aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Used memory."))
                )
            )
        )

        await viewModel.send("memory context")

        let assistantMessage = try XCTUnwrap(viewModel.currentThread.messages.last)
        XCTAssertEqual(assistantMessage.role, .assistant)
        XCTAssertEqual(assistantMessage.memoryContextCount, 1)

        let savedThreadResult = try await historyStore.thread(id: viewModel.currentThread.id)
        let savedThread = try XCTUnwrap(savedThreadResult)
        XCTAssertEqual(savedThread.messages.last?.memoryContextCount, 1)
    }

    @MainActor
    func testChatViewModelEnrichesLinkedAssetsAfterInfoPageAutoSave() async throws {
        let infoPageStore = InMemoryInfoPageStore()
        let assetStore = InMemoryKnowledgeAssetStore()
        let assetAPI = KairoKnowledgeAssetBackendService(
            assetStore: assetStore,
            shareIngestionQueue: InMemoryShareIngestionQueue()
        )
        let draft = InfoPageDraft(
            createInfoPage: true,
            title: "Camera warranty",
            templateID: .warranty,
            category: .warranty,
            summary: "Camera warranty expires in 2027.",
            facts: [
                InfoPageDraftFact(label: "Serial", value: "KA-42")
            ],
            folderName: "Devices",
            confidence: 0.91,
            assetDescription: "Photo of a warranty card for a camera.",
            ocrSummary: "Warranty card serial KA-42 expires 2027.",
            keywords: ["camera", "warranty", "KA-42"],
            candidateCategories: [
                InfoPageDraftCategoryCandidate(
                    folderName: "Devices",
                    templateID: .warranty,
                    category: .warranty,
                    confidence: 0.91,
                    reason: "The card contains warranty and serial details."
                )
            ]
        )
        let viewModel = ChatViewModel(dependencies: ChatFeatureDependencies(
            historyStore: InMemoryChatHistoryStore(),
            shareImportAPI: KairoShareImportBackendService(shareIngestionQueue: InMemoryShareIngestionQueue()),
            chatAPI: FixedInfoPageDraftChatAPI(draft: draft),
            actionAPI: NoopKairoActionAPI(),
            infoPageStore: infoPageStore,
            knowledgeAssetAPI: assetAPI,
            chatAttachmentRootDirectory: temporaryDirectory(named: "chat-attachments")
        ))
        let sourceURL = temporaryFileURL(named: "warranty-card.jpg")
        try Data("fake image".utf8).write(to: sourceURL)

        await viewModel.send("", attachments: [
            ChatAttachment(
                kind: .image,
                displayName: "warranty-card.jpg",
                fileURL: sourceURL,
                textPreview: "OCR: serial KA-42"
            )
        ])

        let pages = try await infoPageStore.list(limit: 10)
        let page = try XCTUnwrap(pages.first)
        let assets = try await assetStore.list(limit: 10)
        let asset = try XCTUnwrap(assets.first)
        XCTAssertEqual(page.assetIDs, [asset.id])
        XCTAssertEqual(asset.linkedInfoPageIDs, [page.id])
        XCTAssertEqual(asset.generatedDescription, "Photo of a warranty card for a camera.")
        XCTAssertEqual(asset.summary, "Warranty card serial KA-42 expires 2027.")
        XCTAssertTrue(asset.tags.contains("camera"))
        XCTAssertTrue(asset.tags.contains("warranty"))
        XCTAssertTrue(asset.tags.contains("KA-42"))
        XCTAssertTrue(asset.collections.contains("Devices"))
    }

    @MainActor
    func testPrivateThreadStartsNewChatAndDoesNotPersistHistory() async throws {
        let historyStore = InMemoryChatHistoryStore()
        let viewModel = ChatViewModel(
            historyStore: historyStore,
            chatAPI: KairoChatBackendService(
                agent: AgentCore(
                    aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Private reply"))
                )
            )
        )

        await viewModel.send("standard message")
        let savedStandardThread = try await historyStore.thread(id: viewModel.currentThread.id)
        XCTAssertNotNil(savedStandardThread)

        viewModel.startPrivateThread()
        let privateThreadID = viewModel.currentThread.id
        await viewModel.send("private message")

        XCTAssertTrue(viewModel.isPrivateChatEnabled)
        let savedPrivateThread = try await historyStore.thread(id: privateThreadID)
        XCTAssertNil(savedPrivateThread)
        XCTAssertNotEqual(privateThreadID, savedStandardThread?.id)
    }

    private func temporaryDirectory(named name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairo-chat-tests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func temporaryFileURL(named name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kairo-chat-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}

private actor FixedInfoPageDraftChatAPI: KairoChatAPI {
    private let draft: InfoPageDraft

    init(draft: InfoPageDraft) {
        self.draft = draft
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
        return AICompletionResponse(
            message: "Created page.",
            infoPageDraft: draft
        )
    }
}

private struct NoopKairoActionAPI: KairoActionAPI {
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
