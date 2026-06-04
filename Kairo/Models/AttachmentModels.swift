import Foundation

public struct ChatAttachment: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: AttachmentKind
    public var displayName: String
    public var uniformTypeIdentifier: String?
    public var fileURL: URL?
    public var byteCount: Int64?
    public var textPreview: String?
    public var source: AttachmentSource
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        kind: AttachmentKind,
        displayName: String,
        uniformTypeIdentifier: String? = nil,
        fileURL: URL? = nil,
        byteCount: Int64? = nil,
        textPreview: String? = nil,
        source: AttachmentSource = .chatComposer,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.uniformTypeIdentifier = uniformTypeIdentifier
        self.fileURL = fileURL
        self.byteCount = byteCount
        self.textPreview = textPreview
        self.source = source
        self.createdAt = createdAt
    }

    public var promptSummary: String {
        var parts = ["- \(displayName) [\(kind.rawValue)]"]
        if let uniformTypeIdentifier {
            parts.append("UTI: \(uniformTypeIdentifier)")
        }
        if let byteCount {
            parts.append("bytes: \(byteCount)")
        }
        if let textPreview, !textPreview.isEmpty {
            parts.append("preview: \(textPreview)")
        }
        return parts.joined(separator: "; ")
    }
}

public enum AttachmentKind: String, Codable, Equatable, Sendable {
    case text
    case url
    case image
    case pdf
    case file
    case unknown
}

public enum AttachmentSource: String, Codable, Equatable, Sendable {
    case chatComposer
    case shareExtension
    case documentPicker
    case photoPicker
    case shortcut
}

public struct ShareIngestionItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var attachments: [ChatAttachment]
    public var sourceApplication: String?
    public var receivedAt: Date
    public var status: ShareIngestionStatus
    public var suggestedPrompt: String

    public init(
        id: UUID = UUID(),
        attachments: [ChatAttachment],
        sourceApplication: String? = nil,
        receivedAt: Date = Date(),
        status: ShareIngestionStatus = .pending,
        suggestedPrompt: String? = nil
    ) {
        self.id = id
        self.attachments = attachments
        self.sourceApplication = sourceApplication
        self.receivedAt = receivedAt
        self.status = status
        self.suggestedPrompt = suggestedPrompt ?? Self.defaultSuggestedPrompt(for: attachments)
    }

    public static func defaultSuggestedPrompt(for attachments: [ChatAttachment]) -> String {
        if attachments.isEmpty {
            return "Summarize the shared content."
        }
        let names = attachments.map(\.displayName).joined(separator: ", ")
        return "Summarize this shared content: \(names)"
    }
}

public enum ShareIngestionStatus: String, Codable, Equatable, Sendable {
    case pending
    case imported
    case failed
}
