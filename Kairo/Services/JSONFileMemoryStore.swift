import Foundation

public actor JSONFileMemoryStore: MemoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var records: [UUID: MemoryRecord] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func save(_ memory: MemoryRecord) async throws {
        var updated = memory
        updated.updatedAt = Date()
        records[updated.id] = updated
        try persist()
    }

    public func search(query: String, limit: Int = 20) async throws -> [MemoryRecord] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            return try await list(limit: limit)
        }

        return activeRecords()
            .filter { record in
                record.title.lowercased().contains(normalized)
                || record.summary.lowercased().contains(normalized)
                || record.content.lowercased().contains(normalized)
                || record.tags.contains { $0.lowercased().contains(normalized) }
            }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func list(limit: Int = 50) async throws -> [MemoryRecord] {
        activeRecords()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func delete(id: UUID) async throws {
        guard var record = records[id] else { return }
        record.deletedAt = Date()
        record.updatedAt = Date()
        records[id] = record
        try persist()
    }

    public func erase(id: UUID) async throws {
        records[id] = nil
        try persist()
    }

    public func purgeDeleted() async throws {
        records = records.filter { _, record in record.deletedAt == nil }
        try persist()
    }

    public func export(limit: Int = 50) async throws -> MemoryExport {
        MemoryExport(records: try await list(limit: limit))
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            records = [:]
            return
        }

        let decoded = try decoder.decode([MemoryRecord].self, from: data)
        records = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(records.values.sorted { $0.createdAt < $1.createdAt })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    private func activeRecords() -> [MemoryRecord] {
        records.values.filter { record in
            guard record.deletedAt == nil else { return false }
            if let expiresAt = record.expiresAt, expiresAt < Date() {
                return false
            }
            return true
        }
    }
}
