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
    func get(id: UUID) async throws -> MemoryRecord?
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

    public func get(id: UUID) async throws -> MemoryRecord? {
        guard let record = records[id], record.deletedAt == nil else { return nil }
        if let expiresAt = record.expiresAt, expiresAt < Date() {
            return nil
        }
        return record
    }

    public func search(query: String, limit: Int = 20) async throws -> [MemoryRecord] {
        let matcher = MemorySearchMatcher(query: query)
        return records.values
            .filter { $0.deletedAt == nil }
            .compactMap { record -> (record: MemoryRecord, score: Int)? in
                let score = matcher.score(record)
                guard score > 0 else { return nil }
                return (record, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.record.updatedAt > rhs.record.updatedAt
            }
            .prefix(limit)
            .map(\.record)
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

public struct MemorySearchMatcher: Sendable {
    private let normalizedQuery: String
    private let tokens: [String]

    public init(query: String) {
        self.normalizedQuery = Self.normalize(query)
        self.tokens = Self.searchTokens(from: normalizedQuery)
    }

    public func score(_ record: MemoryRecord) -> Int {
        guard !normalizedQuery.isEmpty else { return 1 }

        let searchableFields = [
            record.title,
            record.summary,
            record.content,
            record.tags.joined(separator: " ")
        ].map(Self.normalize)
        let searchableText = searchableFields.joined(separator: " ")

        var score = 0
        if searchableText.contains(normalizedQuery) {
            score += 100
        }

        for token in tokens where searchableText.contains(token) {
            score += 10
            if searchableFields.first?.contains(token) == true {
                score += 5
            }
        }

        return score
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func searchTokens(from query: String) -> [String] {
        let stopWords: Set<String> = [
            "about", "should", "what", "when", "where", "which", "who", "why", "how",
            "the", "this", "that", "with", "from", "into", "for", "and", "or", "but",
            "please", "remember", "memory", "kairo", "我", "你", "請", "幫我", "關於"
        ]

        return query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                token.count >= 3 && !stopWords.contains(token)
            }
    }
}
