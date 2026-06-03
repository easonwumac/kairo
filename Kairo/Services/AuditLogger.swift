import Foundation

public protocol AuditLogger: Sendable {
    func record(_ event: AuditEvent) async throws
    func list(limit: Int) async throws -> [AuditEvent]
    func clear() async throws
}

public actor InMemoryAuditLogger: AuditLogger {
    private var events: [AuditEvent] = []

    public init() {}

    public func record(_ event: AuditEvent) async throws {
        events.append(event)
    }

    public func list(limit: Int = 100) async throws -> [AuditEvent] {
        events
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    public func clear() async throws {
        events = []
    }
}

public actor FileBackedAuditLogger: AuditLogger {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var events: [AuditEvent] = []

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func record(_ event: AuditEvent) async throws {
        events.append(event)
        try persist()
    }

    public func list(limit: Int = 100) async throws -> [AuditEvent] {
        events
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    public func clear() async throws {
        events = []
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            events = []
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            events = []
            return
        }

        events = try decoder.decode([AuditEvent].self, from: data)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(events.sorted { $0.createdAt < $1.createdAt })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}
