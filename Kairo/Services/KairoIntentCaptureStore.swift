import Foundation

public struct KairoIntentCapture: Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String
    public var sourceName: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        text: String,
        sourceName: String = "Shortcut Capture",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.sourceName = sourceName
        self.createdAt = createdAt
    }
}

public struct KairoIntentCaptureStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        defaults: UserDefaults = .standard,
        key: String = "kairo_intent_pending_captures"
    ) {
        self.defaults = defaults
        self.key = key
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func saveText(_ text: String, sourceName: String = "Shortcut Capture") {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var captures = load()
        captures.append(KairoIntentCapture(text: trimmed, sourceName: sourceName))
        persist(captures)
    }

    public func consume() -> [KairoIntentCapture] {
        let captures = load()
        defaults.removeObject(forKey: key)
        return captures
    }

    private func load() -> [KairoIntentCapture] {
        guard let data = defaults.data(forKey: key),
              let captures = try? decoder.decode([KairoIntentCapture].self, from: data) else {
            return []
        }
        return captures
    }

    private func persist(_ captures: [KairoIntentCapture]) {
        guard let data = try? encoder.encode(captures) else { return }
        defaults.set(data, forKey: key)
    }
}

public struct KairoIntentCaptureIngestor: Sendable {
    private let attachmentBuilder: ShareAttachmentBuilder

    public init(attachmentBuilder: ShareAttachmentBuilder = ShareAttachmentBuilder()) {
        self.attachmentBuilder = attachmentBuilder
    }

    public func enqueue(_ captures: [KairoIntentCapture], into queue: any ShareIngestionQueue) async throws {
        for capture in captures {
            let item = ShareIngestionItem(
                attachments: [attachmentBuilder.text(capture.text, displayName: capture.sourceName)],
                sourceApplication: "AppIntent",
                receivedAt: capture.createdAt
            )
            try await queue.enqueue(item)
        }
    }
}
