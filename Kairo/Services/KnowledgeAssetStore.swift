import Foundation

public struct KnowledgeAssetExport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var assets: [KnowledgeAsset]

    public init(
        schemaVersion: Int = 1,
        exportedAt: Date = Date(),
        assets: [KnowledgeAsset]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.assets = assets
    }
}

public protocol KnowledgeAssetStore: Sendable {
    func save(_ asset: KnowledgeAsset) async throws
    func list(limit: Int) async throws -> [KnowledgeAsset]
    func search(query: String, limit: Int) async throws -> [KnowledgeAsset]
    func delete(id: UUID) async throws
    func erase(id: UUID) async throws
    func export(limit: Int) async throws -> KnowledgeAssetExport
}

public actor InMemoryKnowledgeAssetStore: KnowledgeAssetStore {
    private var assets: [UUID: KnowledgeAsset]

    public init(seed: [KnowledgeAsset] = []) {
        self.assets = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
    }

    public func save(_ asset: KnowledgeAsset) async throws {
        assets[asset.id] = asset
    }

    public func list(limit: Int = 50) async throws -> [KnowledgeAsset] {
        activeAssets()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func search(query: String, limit: Int = 20) async throws -> [KnowledgeAsset] {
        let matcher = KnowledgeAssetSearchMatcher(query: query)
        return activeAssets()
            .compactMap { asset -> (asset: KnowledgeAsset, score: Int)? in
                let score = matcher.score(asset)
                guard score > 0 else { return nil }
                return (asset, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.asset.updatedAt > rhs.asset.updatedAt
            }
            .prefix(limit)
            .map(\.asset)
    }

    public func delete(id: UUID) async throws {
        guard var asset = assets[id] else { return }
        asset.deletedAt = Date()
        asset.updatedAt = Date()
        assets[id] = asset
    }

    public func erase(id: UUID) async throws {
        assets[id] = nil
    }

    public func export(limit: Int = 50) async throws -> KnowledgeAssetExport {
        KnowledgeAssetExport(assets: try await list(limit: limit))
    }

    private func activeAssets() -> [KnowledgeAsset] {
        assets.values.filter { $0.deletedAt == nil }
    }
}

public actor JSONFileKnowledgeAssetStore: KnowledgeAssetStore {
    private let fileURL: URL
    private let iCloudBackupAllowed: Bool
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var assets: [UUID: KnowledgeAsset] = [:]

    public init(fileURL: URL, iCloudBackupAllowed: Bool = false) async throws {
        self.fileURL = fileURL
        self.iCloudBackupAllowed = iCloudBackupAllowed
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
        try Self.applyBackupPolicy(to: fileURL.deletingLastPathComponent(), iCloudBackupAllowed: iCloudBackupAllowed)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try Self.applyBackupPolicy(to: fileURL, iCloudBackupAllowed: iCloudBackupAllowed)
        }
    }

    public func save(_ asset: KnowledgeAsset) async throws {
        var updated = asset
        updated.updatedAt = Date()
        assets[updated.id] = updated
        try persist()
    }

    public func list(limit: Int = 50) async throws -> [KnowledgeAsset] {
        activeAssets()
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(limit)
            .map { $0 }
    }

    public func search(query: String, limit: Int = 20) async throws -> [KnowledgeAsset] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return try await list(limit: limit)
        }
        let matcher = KnowledgeAssetSearchMatcher(query: query)
        return activeAssets()
            .compactMap { asset -> (asset: KnowledgeAsset, score: Int)? in
                let score = matcher.score(asset)
                guard score > 0 else { return nil }
                return (asset, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.asset.updatedAt > rhs.asset.updatedAt
            }
            .prefix(limit)
            .map(\.asset)
    }

    public func delete(id: UUID) async throws {
        guard var asset = assets[id] else { return }
        asset.deletedAt = Date()
        asset.updatedAt = Date()
        assets[id] = asset
        try persist()
    }

    public func erase(id: UUID) async throws {
        assets[id] = nil
        try persist()
    }

    public func export(limit: Int = 50) async throws -> KnowledgeAssetExport {
        KnowledgeAssetExport(assets: try await list(limit: limit))
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            assets = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            assets = [:]
            return
        }

        let decoded = try decoder.decode([KnowledgeAsset].self, from: data)
        assets = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.applyBackupPolicy(to: directory, iCloudBackupAllowed: iCloudBackupAllowed)

        let data = try encoder.encode(assets.values.sorted { $0.createdAt < $1.createdAt })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
        try Self.applyBackupPolicy(to: fileURL, iCloudBackupAllowed: iCloudBackupAllowed)
    }

    private func activeAssets() -> [KnowledgeAsset] {
        assets.values.filter { $0.deletedAt == nil }
    }

    private static func applyBackupPolicy(to url: URL, iCloudBackupAllowed: Bool) throws {
        try (url as NSURL).setResourceValue(!iCloudBackupAllowed, forKey: URLResourceKey.isExcludedFromBackupKey)
    }
}

public struct KnowledgeAssetSearchMatcher: Sendable {
    private let normalizedQuery: String
    private let tokens: [String]

    public init(query: String) {
        self.normalizedQuery = Self.normalize(query)
        self.tokens = Self.searchTokens(from: normalizedQuery)
    }

    public func score(_ asset: KnowledgeAsset) -> Int {
        guard !normalizedQuery.isEmpty else { return 1 }

        let searchableFields = [
            asset.title,
            asset.summary,
            asset.generatedDescription ?? "",
            asset.extractedText,
            asset.tags.joined(separator: " "),
            asset.collections.joined(separator: " "),
            asset.checklistItems.map(\.title).joined(separator: " "),
            asset.attachments.map(\.displayName).joined(separator: " ")
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
            "please", "image", "screenshot", "asset", "kairo", "我", "你", "請", "幫我", "關於", "圖片", "截圖"
        ]

        return query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { token in
                token.count >= 2 && !stopWords.contains(token)
            }
    }
}
