import Foundation

public struct KnowledgeAssetExport: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var exportedAt: Date
    public var assets: [KnowledgeAsset]
    public var folders: [KnowledgeAssetFolder]

    public init(
        schemaVersion: Int = 2,
        exportedAt: Date = Date(),
        assets: [KnowledgeAsset],
        folders: [KnowledgeAssetFolder] = []
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.assets = assets
        self.folders = folders
    }
}

public protocol KnowledgeAssetStore: Sendable {
    func save(_ asset: KnowledgeAsset) async throws
    func list(limit: Int) async throws -> [KnowledgeAsset]
    func search(query: String, limit: Int) async throws -> [KnowledgeAsset]
    func query(_ query: KnowledgeAssetQuery, limit: Int) async throws -> [KnowledgeAsset]
    func delete(id: UUID) async throws
    func erase(id: UUID) async throws
    func saveFolder(_ folder: KnowledgeAssetFolder) async throws
    func listFolders() async throws -> [KnowledgeAssetFolder]
    func deleteFolder(id: UUID) async throws
    func export(limit: Int) async throws -> KnowledgeAssetExport
}

public actor InMemoryKnowledgeAssetStore: KnowledgeAssetStore {
    private var assets: [UUID: KnowledgeAsset]
    private var folders: [UUID: KnowledgeAssetFolder]

    public init(seed: [KnowledgeAsset] = [], folders: [KnowledgeAssetFolder] = []) {
        self.assets = Dictionary(uniqueKeysWithValues: seed.map { ($0.id, $0) })
        self.folders = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
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
        try await self.query(KnowledgeAssetQuery(text: query), limit: limit)
    }

    public func query(_ query: KnowledgeAssetQuery, limit: Int = 50) async throws -> [KnowledgeAsset] {
        let matcher = KnowledgeAssetSearchMatcher(query: query.text)
        return activeAssets()
            .filter { KnowledgeAssetQueryMatcher.matches($0, query: query) }
            .compactMap { asset -> (asset: KnowledgeAsset, score: Int)? in
                let score = query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : matcher.score(asset)
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

    public func saveFolder(_ folder: KnowledgeAssetFolder) async throws {
        folders[folder.id] = folder
    }

    public func listFolders() async throws -> [KnowledgeAssetFolder] {
        activeFolders()
    }

    public func deleteFolder(id: UUID) async throws {
        guard var folder = folders[id] else { return }
        folder.deletedAt = Date()
        folder.updatedAt = Date()
        folders[id] = folder
    }

    public func export(limit: Int = 50) async throws -> KnowledgeAssetExport {
        KnowledgeAssetExport(assets: try await list(limit: limit), folders: try await listFolders())
    }

    private func activeAssets() -> [KnowledgeAsset] {
        assets.values.filter { $0.deletedAt == nil }
    }

    private func activeFolders() -> [KnowledgeAssetFolder] {
        folders.values
            .filter { $0.deletedAt == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
    }
}

public actor JSONFileKnowledgeAssetStore: KnowledgeAssetStore {
    private let fileURL: URL
    private let foldersURL: URL
    private let iCloudBackupAllowed: Bool
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var assets: [UUID: KnowledgeAsset] = [:]
    private var folders: [UUID: KnowledgeAssetFolder] = [:]

    public init(fileURL: URL, iCloudBackupAllowed: Bool = false) async throws {
        self.fileURL = fileURL
        self.foldersURL = fileURL.deletingLastPathComponent().appendingPathComponent("knowledge-asset-folders.json")
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
        if FileManager.default.fileExists(atPath: foldersURL.path) {
            try Self.applyBackupPolicy(to: foldersURL, iCloudBackupAllowed: iCloudBackupAllowed)
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
        try await self.query(KnowledgeAssetQuery(text: query), limit: limit)
    }

    public func query(_ query: KnowledgeAssetQuery, limit: Int = 50) async throws -> [KnowledgeAsset] {
        let matcher = KnowledgeAssetSearchMatcher(query: query.text)
        return activeAssets()
            .filter { KnowledgeAssetQueryMatcher.matches($0, query: query) }
            .compactMap { asset -> (asset: KnowledgeAsset, score: Int)? in
                let score = query.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1 : matcher.score(asset)
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

    public func saveFolder(_ folder: KnowledgeAssetFolder) async throws {
        var updated = folder
        updated.updatedAt = Date()
        folders[updated.id] = updated
        try persistFolders()
    }

    public func listFolders() async throws -> [KnowledgeAssetFolder] {
        activeFolders()
    }

    public func deleteFolder(id: UUID) async throws {
        guard var folder = folders[id] else { return }
        folder.deletedAt = Date()
        folder.updatedAt = Date()
        folders[id] = folder
        try persistFolders()
    }

    public func export(limit: Int = 50) async throws -> KnowledgeAssetExport {
        KnowledgeAssetExport(assets: try await list(limit: limit), folders: try await listFolders())
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
            try loadFoldersFromDisk()
            return
        }

        let decoded = try decoder.decode([KnowledgeAsset].self, from: data)
        assets = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        try loadFoldersFromDisk()
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

    private func loadFoldersFromDisk() throws {
        guard FileManager.default.fileExists(atPath: foldersURL.path) else {
            folders = [:]
            return
        }
        let data = try Data(contentsOf: foldersURL)
        guard !data.isEmpty else {
            folders = [:]
            return
        }
        let decoded = try decoder.decode([KnowledgeAssetFolder].self, from: data)
        folders = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persistFolders() throws {
        let directory = foldersURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.applyBackupPolicy(to: directory, iCloudBackupAllowed: iCloudBackupAllowed)

        let data = try encoder.encode(folders.values.sorted { $0.createdAt < $1.createdAt })
        let temporaryURL = foldersURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: foldersURL.path) {
            _ = try FileManager.default.replaceItemAt(foldersURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: foldersURL)
        }
        try Self.applyBackupPolicy(to: foldersURL, iCloudBackupAllowed: iCloudBackupAllowed)
    }

    private func activeAssets() -> [KnowledgeAsset] {
        assets.values.filter { $0.deletedAt == nil }
    }

    private func activeFolders() -> [KnowledgeAssetFolder] {
        folders.values
            .filter { $0.deletedAt == nil }
            .sorted { $0.updatedAt > $1.updatedAt }
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

        if score == 0 {
            let words = Self.searchTokens(from: searchableText)
            for token in tokens where words.contains(where: { Self.fuzzyMatches(token, candidate: $0) }) {
                score += 4
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

    private static func fuzzyMatches(_ token: String, candidate: String) -> Bool {
        guard token.count >= 3, candidate.count >= 3 else { return false }
        if candidate.hasPrefix(token) || token.hasPrefix(candidate) {
            return true
        }
        if isSubsequence(token, of: candidate) {
            return true
        }
        return levenshteinDistance(token, candidate, maximum: 1) <= 1
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var iterator = haystack.makeIterator()
        for character in needle {
            var found = false
            while let next = iterator.next() {
                if next == character {
                    found = true
                    break
                }
            }
            if !found { return false }
        }
        return true
    }

    private static func levenshteinDistance(_ lhs: String, _ rhs: String, maximum: Int) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        if abs(left.count - right.count) > maximum {
            return maximum + 1
        }
        var previous = Array(0...right.count)
        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1] + Array(repeating: 0, count: right.count)
            var rowMinimum = current[0]
            for (rightIndex, rightCharacter) in right.enumerated() {
                let cost = leftCharacter == rightCharacter ? 0 : 1
                current[rightIndex + 1] = min(
                    previous[rightIndex + 1] + 1,
                    current[rightIndex] + 1,
                    previous[rightIndex] + cost
                )
                rowMinimum = min(rowMinimum, current[rightIndex + 1])
            }
            if rowMinimum > maximum {
                return maximum + 1
            }
            previous = current
        }
        return previous.last ?? maximum + 1
    }
}

public enum KnowledgeAssetQueryMatcher {
    public static func matches(_ asset: KnowledgeAsset, query: KnowledgeAssetQuery) -> Bool {
        if !query.kinds.isEmpty && !query.kinds.contains(asset.kind) {
            return false
        }
        if let folderName = query.folderName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !folderName.isEmpty,
           !asset.collections.contains(where: { $0.localizedCaseInsensitiveCompare(folderName) == .orderedSame }) {
            return false
        }
        if let createdAfter = query.createdAfter, asset.createdAt < createdAfter {
            return false
        }
        if let createdBefore = query.createdBefore, asset.createdAt >= createdBefore {
            return false
        }
        return true
    }
}
