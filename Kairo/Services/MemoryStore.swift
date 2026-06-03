import Foundation

public struct MemoryExport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var records: [MemoryRecord]

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        records: [MemoryRecord]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.records = records
    }
}

public protocol MemoryStore: Sendable {
    func save(_ memory: MemoryRecord) async throws
    func search(query: String, limit: Int) async throws -> [MemoryRecord]
    func list(limit: Int) async throws -> [MemoryRecord]
    func delete(id: UUID) async throws
    func erase(id: UUID) async throws
    func purgeDeleted() async throws
    func export(limit: Int) async throws -> MemoryExport
}

public actor InMemoryMemoryStore: MemoryStore {
    private var records: [UUID: MemoryRecord] = [:]

    public init(seed: [MemoryRecord] = []) {
        for record in seed {
            records[record.id] = record
        }
    }

    public func save(_ memory: MemoryRecord) async throws {
        records[memory.id] = memory
    }

    public func search(query: String, limit: Int = 20) async throws -> [MemoryRecord] {
        let normalized = query.lowercased()
        return records.values
            .filter { $0.deletedAt == nil }
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
        records.values
            .filter { $0.deletedAt == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func delete(id: UUID) async throws {
        guard var record = records[id] else { return }
        record.deletedAt = Date()
        record.updatedAt = Date()
        records[id] = record
    }

    public func erase(id: UUID) async throws {
        records[id] = nil
    }

    public func purgeDeleted() async throws {
        records = records.filter { _, record in record.deletedAt == nil }
    }

    public func export(limit: Int = 50) async throws -> MemoryExport {
        MemoryExport(records: try await list(limit: limit))
    }
}
