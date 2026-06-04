import Foundation

public protocol ChatHistoryStore: Sendable {
    func listThreads(limit: Int) async throws -> [ChatThread]
    func thread(id: UUID) async throws -> ChatThread?
    func saveThread(_ thread: ChatThread) async throws
    func append(_ message: ChatMessage, to threadID: UUID) async throws -> ChatThread
    func deleteThread(id: UUID) async throws
    func purgeDeletedThreads() async throws
}

public actor InMemoryChatHistoryStore: ChatHistoryStore {
    private var threads: [UUID: ChatThread]

    public init(seed: [ChatThread] = []) {
        self.threads = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func listThreads(limit: Int = 50) async throws -> [ChatThread] {
        activeThreads()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func thread(id: UUID) async throws -> ChatThread? {
        guard let thread = threads[id], thread.deletedAt == nil else { return nil }
        return thread
    }

    public func saveThread(_ thread: ChatThread) async throws {
        var updated = thread
        updated.updatedAt = Date()
        threads[updated.id] = updated
    }

    public func append(_ message: ChatMessage, to threadID: UUID) async throws -> ChatThread {
        var thread = threads[threadID] ?? ChatThread(id: threadID)
        thread.append(message, now: message.createdAt)
        threads[threadID] = thread
        return thread
    }

    public func deleteThread(id: UUID) async throws {
        guard var thread = threads[id] else { return }
        thread.deletedAt = Date()
        thread.updatedAt = Date()
        threads[id] = thread
    }

    public func purgeDeletedThreads() async throws {
        threads = threads.filter { _, thread in thread.deletedAt == nil }
    }

    private func activeThreads() -> [ChatThread] {
        threads.values.filter { $0.deletedAt == nil }
    }
}

public actor JSONFileChatHistoryStore: ChatHistoryStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var threads: [UUID: ChatThread] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func listThreads(limit: Int = 50) async throws -> [ChatThread] {
        activeThreads()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func thread(id: UUID) async throws -> ChatThread? {
        guard let thread = threads[id], thread.deletedAt == nil else { return nil }
        return thread
    }

    public func saveThread(_ thread: ChatThread) async throws {
        var updated = thread
        updated.updatedAt = Date()
        threads[updated.id] = updated
        try persist()
    }

    public func append(_ message: ChatMessage, to threadID: UUID) async throws -> ChatThread {
        var thread = threads[threadID] ?? ChatThread(id: threadID)
        thread.append(message, now: message.createdAt)
        threads[threadID] = thread
        try persist()
        return thread
    }

    public func deleteThread(id: UUID) async throws {
        guard var thread = threads[id] else { return }
        thread.deletedAt = Date()
        thread.updatedAt = Date()
        threads[id] = thread
        try persist()
    }

    public func purgeDeletedThreads() async throws {
        threads = threads.filter { _, thread in thread.deletedAt == nil }
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            threads = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            threads = [:]
            return
        }

        let decoded = try decoder.decode([ChatThread].self, from: data)
        threads = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(threads.values.sorted { $0.createdAt < $1.createdAt })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    private func activeThreads() -> [ChatThread] {
        threads.values.filter { $0.deletedAt == nil }
    }
}
