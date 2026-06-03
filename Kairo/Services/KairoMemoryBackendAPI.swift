import Foundation

public protocol KairoMemoryAPI: Sendable {
    func list(limit: Int) async throws -> [MemoryRecord]
    func search(query: String, limit: Int) async throws -> [MemoryRecord]
    func save(_ memory: MemoryRecord) async throws
    func delete(id: UUID) async throws
    func erase(id: UUID) async throws
    func purgeDeleted() async throws
    func export(limit: Int) async throws -> MemoryExport
}

public struct KairoMemoryBackendService: KairoMemoryAPI {
    private let memoryStore: any MemoryStore

    public init(memoryStore: any MemoryStore) {
        self.memoryStore = memoryStore
    }

    public func list(limit: Int = 50) async throws -> [MemoryRecord] {
        try await memoryStore.list(limit: limit)
    }

    public func search(query: String, limit: Int = 20) async throws -> [MemoryRecord] {
        try await memoryStore.search(query: query, limit: limit)
    }

    public func save(_ memory: MemoryRecord) async throws {
        try await memoryStore.save(memory)
    }

    public func delete(id: UUID) async throws {
        try await memoryStore.delete(id: id)
    }

    public func erase(id: UUID) async throws {
        try await memoryStore.erase(id: id)
    }

    public func purgeDeleted() async throws {
        try await memoryStore.purgeDeleted()
    }

    public func export(limit: Int = 50) async throws -> MemoryExport {
        try await memoryStore.export(limit: limit)
    }
}
