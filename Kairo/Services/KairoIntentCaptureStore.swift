import Foundation

public struct KairoIntentCapture: Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: KairoIntentCaptureKind
    public var text: String
    public var url: URL?
    public var sourceName: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: KairoIntentCaptureKind = .text,
        text: String,
        url: URL? = nil,
        sourceName: String = "Shortcut Capture",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.url = url
        self.sourceName = sourceName
        self.createdAt = createdAt
    }
}

public enum KairoIntentCaptureKind: String, Codable, Equatable, Sendable {
    case text
    case url
}

public struct KairoIntentCaptureStore: @unchecked Sendable {
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

    @discardableResult
    public func saveText(_ text: String, sourceName: String = "Shortcut Capture") -> KairoIntentCapture? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var captures = load()
        let capture = KairoIntentCapture(text: trimmed, sourceName: sourceName)
        captures.append(capture)
        persist(captures)
        return capture
    }

    @discardableResult
    public func saveURL(_ url: URL, note: String? = nil, sourceName: String = "Shortcut URL") -> KairoIntentCapture? {
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme) else {
            return nil
        }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = trimmedNote.isEmpty ? url.absoluteString : "\(trimmedNote)\n\(url.absoluteString)"
        var captures = load()
        let capture = KairoIntentCapture(kind: .url, text: text, url: url, sourceName: sourceName)
        captures.append(capture)
        persist(captures)
        return capture
    }

    public func consume() -> [KairoIntentCapture] {
        let captures = load()
        defaults.removeObject(forKey: key)
        return captures
    }

    public func clear() -> [KairoIntentCapture] {
        consume()
    }

    public func remove(id: UUID) -> KairoIntentCapture? {
        var captures = load()
        guard let index = captures.firstIndex(where: { $0.id == id }) else { return nil }
        let removed = captures.remove(at: index)
        persist(captures)
        return removed
    }

    public func pending() -> [KairoIntentCapture] {
        load()
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
            let attachment: ChatAttachment
            switch capture.kind {
            case .text:
                attachment = attachmentBuilder.text(capture.text, displayName: capture.sourceName)
            case .url:
                if let url = capture.url {
                    attachment = attachmentBuilder.url(url)
                } else {
                    attachment = attachmentBuilder.text(capture.text, displayName: capture.sourceName)
                }
            }
            let item = ShareIngestionItem(
                attachments: [attachment],
                sourceApplication: "AppIntent",
                receivedAt: capture.createdAt
            )
            try await queue.enqueue(item)
        }
    }
}
