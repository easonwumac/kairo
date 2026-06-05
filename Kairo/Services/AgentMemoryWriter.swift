import Foundation

public protocol AgentMemoryWriting: Sendable {
    func remember(
        _ content: String,
        title: String?,
        source: MemorySource
    ) async throws -> MemoryRecord
}

public actor DefaultAgentMemoryWriter: AgentMemoryWriting {
    private let memoryStore: any MemoryStore

    public init(memoryStore: any MemoryStore) {
        self.memoryStore = memoryStore
    }

    public func remember(
        _ content: String,
        title: String?,
        source: MemorySource
    ) async throws -> MemoryRecord {
        let memory = MemoryRecord(
            title: title ?? String(content.prefix(40)),
            summary: String(content.prefix(160)),
            content: content,
            source: source
        )
        try await memoryStore.save(memory)
        return memory
    }
}
