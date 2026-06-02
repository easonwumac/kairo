#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

public final class ShareViewController: UIViewController {
    private let builder = ShareAttachmentBuilder()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        processExtensionItems()
    }

    private func processExtensionItems() {
        let providers = extensionContext?.inputItems
            .compactMap { $0 as? NSExtensionItem }
            .flatMap { $0.attachments ?? [] } ?? []

        guard !providers.isEmpty else {
            completeRequest()
            return
        }

        Task {
            let attachments = await loadAttachments(from: providers)
            await enqueue(attachments)
            await MainActor.run { completeRequest() }
        }
    }

    private func loadAttachments(from providers: [NSItemProvider]) async -> [ChatAttachment] {
        var attachments: [ChatAttachment] = []
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
               let url = await loadURL(from: provider) {
                attachments.append(builder.url(url))
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier),
                      let text = await loadText(from: provider) {
                attachments.append(builder.text(text))
            } else if let fileAttachment = await loadFileAttachment(from: provider) {
                attachments.append(fileAttachment)
            }
        }
        return attachments
    }

    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                continuation.resume(returning: item as? URL)
            }
        }
    }

    private func loadText(from provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                if let text = item as? String {
                    continuation.resume(returning: text)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadFileAttachment(from provider: NSItemProvider) async -> ChatAttachment? {
        let identifier = provider.registeredTypeIdentifiers.first
        guard let identifier else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { url, _ in
                guard let url else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: self.builder.file(url: url, uniformTypeIdentifier: identifier))
            }
        }
    }

    private func enqueue(_ attachments: [ChatAttachment]) async {
        guard !attachments.isEmpty else { return }
        let item = ShareIngestionItem(attachments: attachments)
        guard let fileURL = sharedQueueURL() else { return }
        do {
            let queue = try await JSONFileShareIngestionQueue(fileURL: fileURL)
            try await queue.enqueue(item)
        } catch {
            // Extension must fail closed and return control to the user quickly.
        }
    }

    private func sharedQueueURL() -> URL? {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.app.kairo.shared")
        return container?.appendingPathComponent("share-ingestion-queue.json")
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
#endif
