import XCTest
@testable import KairoCore

final class ShareExtensionLifecycleTests: XCTestCase {
    func testShareExtensionIngestionPolicyCapsAttachmentCountForLightweightExtension() {
        let attachments = (0..<12).map { index in
            ChatAttachment(kind: .file, displayName: "File \(index)", source: .shareExtension)
        }

        let limited = ShareExtensionIngestionPolicy.limitedAttachments(attachments)

        XCTAssertEqual(ShareExtensionIngestionPolicy.maxAttachmentsPerRequest, 8)
        XCTAssertEqual(limited.count, 8)
        XCTAssertEqual(limited.map(\.displayName), (0..<8).map { "File \($0)" })
    }

    #if canImport(SwiftUI)
    @MainActor
    func testChatImportPendingSharesSurfacesTextURLImageAndFileMetadata() async throws {
        let builder = ShareAttachmentBuilder()
        let attachments = [
            builder.text("Shared article text", displayName: "Article"),
            builder.url(URL(string: "https://example.com/story")!),
            builder.file(
                url: URL(fileURLWithPath: "/tmp/photo.png"),
                displayName: "photo.png",
                uniformTypeIdentifier: "public.png",
                byteCount: 123
            ),
            builder.file(
                url: URL(fileURLWithPath: "/tmp/brief.pdf"),
                displayName: "brief.pdf",
                uniformTypeIdentifier: "com.adobe.pdf",
                byteCount: 456
            )
        ]
        let item = ShareIngestionItem(attachments: attachments, sourceApplication: "ShareSheet")
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: queue,
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
        )

        await viewModel.importPendingShares()

        XCTAssertEqual(viewModel.pendingAttachments.map(\.kind), [.text, .url, .image, .pdf])
        XCTAssertEqual(viewModel.pendingAttachments.map(\.source), Array(repeating: .shareExtension, count: 4))
        XCTAssertEqual(
            viewModel.composerText,
            "Review this shared content: Article, example.com, photo.png, brief.pdf"
        )
        let remaining = try await queue.pendingItems(limit: 10)
        XCTAssertTrue(remaining.isEmpty)
    }
    #endif

    func testShareExtensionControllerStaysQueueOnlyAndActionFree() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let source = try String(
            contentsOf: root.appendingPathComponent("Kairo/Extensions/ShareExtension/ShareViewController.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(source.contains("JSONFileShareIngestionQueue"))
        XCTAssertTrue(source.contains("loadFileRepresentation"))
        XCTAssertTrue(source.contains("completeRequest"))
        XCTAssertFalse(source.contains("AgentCore"))
        XCTAssertFalse(source.contains("AIProvider"))
        XCTAssertFalse(source.contains("OpenAIProvider"))
        XCTAssertFalse(source.contains("ActionExecutor"))
        XCTAssertFalse(source.contains("SandboxActionExecutor"))
        XCTAssertFalse(source.contains("LocalModel"))
    }
}
