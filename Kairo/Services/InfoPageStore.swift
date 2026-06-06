import Foundation

public struct InfoPageExport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var pages: [InfoPage]

    public init(schemaVersion: Int = 1, exportedAt: Date = Date(), pages: [InfoPage]) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.pages = pages
    }
}

public protocol InfoPageStore: Sendable {
    func save(_ page: InfoPage) async throws
    func list(limit: Int) async throws -> [InfoPage]
    func search(query: String, limit: Int) async throws -> [InfoPage]
    func delete(id: UUID) async throws
    func erase(id: UUID) async throws
    func export(limit: Int) async throws -> InfoPageExport
}

public actor InMemoryInfoPageStore: InfoPageStore {
    private var pages: [UUID: InfoPage]

    public init(seed: [InfoPage] = []) {
        self.pages = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func save(_ page: InfoPage) async throws {
        pages[page.id] = page
    }

    public func list(limit: Int = 50) async throws -> [InfoPage] {
        activePages()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func search(query: String, limit: Int = 20) async throws -> [InfoPage] {
        let matcher = InfoPageSearchMatcher(query: query)
        return activePages()
            .compactMap { page -> (page: InfoPage, score: Int)? in
                let score = matcher.score(page)
                guard score > 0 else { return nil }
                return (page, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.page.updatedAt > rhs.page.updatedAt
            }
            .prefix(limit)
            .map(\.page)
    }

    public func delete(id: UUID) async throws {
        guard var page = pages[id] else { return }
        page.deletedAt = Date()
        page.updatedAt = Date()
        pages[id] = page
    }

    public func erase(id: UUID) async throws {
        pages[id] = nil
    }

    public func export(limit: Int = 50) async throws -> InfoPageExport {
        InfoPageExport(pages: try await list(limit: limit))
    }

    private func activePages() -> [InfoPage] {
        pages.values.filter { $0.deletedAt == nil }
    }
}

public actor JSONFileInfoPageStore: InfoPageStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var pages: [UUID: InfoPage] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func save(_ page: InfoPage) async throws {
        var updated = page
        updated.updatedAt = Date()
        pages[updated.id] = updated
        try persist()
    }

    public func list(limit: Int = 50) async throws -> [InfoPage] {
        activePages()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func search(query: String, limit: Int = 20) async throws -> [InfoPage] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await list(limit: limit)
        }
        let matcher = InfoPageSearchMatcher(query: query)
        return activePages()
            .compactMap { page -> (page: InfoPage, score: Int)? in
                let score = matcher.score(page)
                guard score > 0 else { return nil }
                return (page, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.page.updatedAt > rhs.page.updatedAt
            }
            .prefix(limit)
            .map(\.page)
    }

    public func delete(id: UUID) async throws {
        guard var page = pages[id] else { return }
        page.deletedAt = Date()
        page.updatedAt = Date()
        pages[id] = page
        try persist()
    }

    public func erase(id: UUID) async throws {
        pages[id] = nil
        try persist()
    }

    public func export(limit: Int = 50) async throws -> InfoPageExport {
        InfoPageExport(pages: try await list(limit: limit))
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            pages = [:]
            return
        }
        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            pages = [:]
            return
        }
        let decoded = try decoder.decode([InfoPage].self, from: data)
        pages = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(pages.values.sorted { $0.createdAt < $1.createdAt })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])
        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }

    private func activePages() -> [InfoPage] {
        pages.values.filter { $0.deletedAt == nil }
    }
}

public struct InfoPageSearchMatcher: Sendable {
    private let normalizedQuery: String
    private let tokens: [String]

    public init(query: String) {
        self.normalizedQuery = Self.normalize(query)
        self.tokens = Self.searchTokens(from: normalizedQuery)
    }

    public func score(_ page: InfoPage) -> Int {
        guard !normalizedQuery.isEmpty else { return 1 }
        let searchableFields = [
            page.title,
            page.category.rawValue,
            page.templateID.rawValue,
            page.summary,
            page.facts.map { "\($0.label) \($0.value)" }.joined(separator: " "),
            page.timeline.map { "\($0.title) \($0.note ?? "")" }.joined(separator: " "),
            page.reminderLinks.map(\.title).joined(separator: " ")
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
            "about", "what", "when", "where", "which", "who", "why", "how",
            "the", "this", "that", "with", "from", "into", "for", "and", "or",
            "please", "page", "asset", "kairo", "我", "你", "請", "幫我", "關於", "資料", "頁面"
        ]
        return query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                token.count >= 2 && !stopWords.contains(token)
            }
    }
}
