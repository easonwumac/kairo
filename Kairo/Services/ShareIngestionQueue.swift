import Foundation

public protocol ShareIngestionQueue: Sendable {
    func enqueue(_ item: ShareIngestionItem) async throws
    func pendingItems(limit: Int) async throws -> [ShareIngestionItem]
    func markImported(id: UUID) async throws
    func markFailed(id: UUID) async throws
    func delete(id: UUID) async throws
}

public enum ShareExtensionIngestionPolicy {
    public static let maxAttachmentsPerRequest = 8

    public static func limitedAttachments(_ attachments: [ChatAttachment]) -> [ChatAttachment] {
        Array(attachments.prefix(maxAttachmentsPerRequest))
    }
}

public actor InMemoryShareIngestionQueue: ShareIngestionQueue {
    private var items: [UUID: ShareIngestionItem]

    public init(seed: [ShareIngestionItem] = []) {
        self.items = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func enqueue(_ item: ShareIngestionItem) async throws {
        items[item.id] = item
    }

    public func pendingItems(limit: Int = 20) async throws -> [ShareIngestionItem] {
        items.values
            .filter { $0.status == .pending }
            .sorted { $0.receivedAt < $1.receivedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func markImported(id: UUID) async throws {
        guard var item = items[id] else { return }
        item.status = .imported
        items[id] = item
    }

    public func markFailed(id: UUID) async throws {
        guard var item = items[id] else { return }
        item.status = .failed
        items[id] = item
    }

    public func delete(id: UUID) async throws {
        items[id] = nil
    }
}

public actor JSONFileShareIngestionQueue: ShareIngestionQueue {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var items: [UUID: ShareIngestionItem] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func enqueue(_ item: ShareIngestionItem) async throws {
        items[item.id] = item
        try persist()
    }

    public func pendingItems(limit: Int = 20) async throws -> [ShareIngestionItem] {
        items.values
            .filter { $0.status == .pending }
            .sorted { $0.receivedAt < $1.receivedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func markImported(id: UUID) async throws {
        guard var item = items[id] else { return }
        item.status = .imported
        items[id] = item
        try persist()
    }

    public func markFailed(id: UUID) async throws {
        guard var item = items[id] else { return }
        item.status = .failed
        items[id] = item
        try persist()
    }

    public func delete(id: UUID) async throws {
        items[id] = nil
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            items = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            items = [:]
            return
        }

        let decoded = try decoder.decode([ShareIngestionItem].self, from: data)
        items = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(items.values.sorted { $0.receivedAt < $1.receivedAt })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public struct ShareAttachmentBuilder: Sendable {
    public init() {}

    public func text(_ text: String, displayName: String = "Shared Text") -> ChatAttachment {
        ChatAttachment(
            kind: .text,
            displayName: displayName,
            uniformTypeIdentifier: "public.plain-text",
            byteCount: Int64(text.utf8.count),
            textPreview: String(text.prefix(500)),
            source: .shareExtension
        )
    }

    public func url(_ url: URL) -> ChatAttachment {
        ChatAttachment(
            kind: .url,
            displayName: url.host(percentEncoded: false) ?? url.absoluteString,
            uniformTypeIdentifier: "public.url",
            fileURL: url,
            textPreview: url.absoluteString,
            source: .shareExtension
        )
    }

    public func file(
        url: URL,
        displayName: String? = nil,
        uniformTypeIdentifier: String? = nil,
        byteCount: Int64? = nil
    ) -> ChatAttachment {
        ChatAttachment(
            kind: kind(for: uniformTypeIdentifier, url: url),
            displayName: displayName ?? (url.lastPathComponent.isEmpty ? "Shared File" : url.lastPathComponent),
            uniformTypeIdentifier: uniformTypeIdentifier,
            fileURL: url,
            byteCount: byteCount,
            source: .shareExtension
        )
    }

    private func kind(for uniformTypeIdentifier: String?, url: URL) -> AttachmentKind {
        let identifier = uniformTypeIdentifier?.lowercased() ?? ""
        let extensionName = url.pathExtension.lowercased()
        if identifier.contains("image") || ["png", "jpg", "jpeg", "heic", "gif", "webp"].contains(extensionName) {
            return .image
        }
        if identifier.contains("pdf") || extensionName == "pdf" {
            return .pdf
        }
        if identifier.contains("url") {
            return .url
        }
        if identifier.contains("text") || ["txt", "md", "rtf"].contains(extensionName) {
            return .text
        }
        return .file
    }
}

public struct SharedFileIngestionStore: Sendable {
    public let sharedFilesDirectory: URL
    private let fileNameGenerator: @Sendable (URL) -> String

    public init(
        sharedFilesDirectory: URL,
        fileNameGenerator: @escaping @Sendable (URL) -> String = { sourceURL in
            SharedFileIngestionStore.defaultStoredFileName(for: sourceURL)
        }
    ) {
        self.sharedFilesDirectory = sharedFilesDirectory
        self.fileNameGenerator = fileNameGenerator
    }

    public func copyFile(from sourceURL: URL, uniformTypeIdentifier: String? = nil) throws -> ChatAttachment {
        try FileManager.default.createDirectory(at: sharedFilesDirectory, withIntermediateDirectories: true)
        let destinationURL = sharedFilesDirectory.appendingPathComponent(fileNameGenerator(sourceURL))
        let accessedSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessedSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        let byteCount = try Self.byteCount(for: destinationURL)

        return ShareAttachmentBuilder().file(
            url: destinationURL,
            displayName: sourceURL.lastPathComponent.isEmpty ? "Shared File" : sourceURL.lastPathComponent,
            uniformTypeIdentifier: uniformTypeIdentifier,
            byteCount: byteCount
        )
    }

    public static func defaultStoredFileName(for sourceURL: URL) -> String {
        "\(UUID().uuidString)-\(sanitizedFileName(sourceURL.lastPathComponent))"
    }

    public static func sanitizedFileName(_ fileName: String) -> String {
        let fallback = "Shared File"
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = trimmed.isEmpty ? fallback : trimmed
        let disallowed = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let scalars = candidate.unicodeScalars.map { scalar in
            disallowed.contains(scalar) || CharacterSet.controlCharacters.contains(scalar) ? "-" : Character(scalar)
        }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        return sanitized.isEmpty ? fallback : sanitized
    }

    private static func byteCount(for url: URL) throws -> Int64? {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value
    }
}
