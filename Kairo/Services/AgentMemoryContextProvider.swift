import Foundation

public struct AgentMemoryContext: Sendable, Equatable {
    public var relevantMemories: [MemoryRecord]
    public var deduplicationContext: [MemoryRecord]

    public init(
        relevantMemories: [MemoryRecord] = [],
        deduplicationContext: [MemoryRecord] = []
    ) {
        self.relevantMemories = relevantMemories
        self.deduplicationContext = deduplicationContext
    }
}

public protocol AgentMemoryContextProviding: Sendable {
    func context(
        for message: String,
        privacyMode: ChatPrivacyMode
    ) async throws -> AgentMemoryContext
}

public actor DefaultAgentMemoryContextProvider: AgentMemoryContextProviding {
    private let memoryStore: any MemoryStore

    public init(memoryStore: any MemoryStore) {
        self.memoryStore = memoryStore
    }

    public func context(
        for message: String,
        privacyMode: ChatPrivacyMode
    ) async throws -> AgentMemoryContext {
        guard privacyMode != .privateChat else {
            return AgentMemoryContext()
        }

        let relevantMemories = try await memoryStore.search(query: message, limit: 8)
        let recentMemories = try await memoryStore.list(limit: 50)
        return AgentMemoryContext(
            relevantMemories: relevantMemories,
            deduplicationContext: Self.mergedMemoryContext(
                relevantMemories: relevantMemories,
                recentMemories: recentMemories
            )
        )
    }

    private static func mergedMemoryContext(
        relevantMemories: [MemoryRecord],
        recentMemories: [MemoryRecord]
    ) -> [MemoryRecord] {
        var merged: [MemoryRecord] = []
        var seenIDs: Set<UUID> = []
        for memory in relevantMemories + recentMemories where !seenIDs.contains(memory.id) {
            merged.append(memory)
            seenIDs.insert(memory.id)
        }
        return merged
    }
}
