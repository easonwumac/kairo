import Foundation

public protocol KairoRecipeStore: Sendable {
    func listRecipes() async throws -> [KairoRecipe]
    func recipe(id: String) async throws -> KairoRecipe?
    func save(_ recipe: KairoRecipe) async throws
    func delete(id: String) async throws
    func setEnabled(_ enabled: Bool, id: String) async throws
}

public actor InMemoryKairoRecipeStore: KairoRecipeStore {
    private var recipes: [String: KairoRecipe]

    public init(recipes: [KairoRecipe] = []) {
        self.recipes = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    }

    public func listRecipes() async throws -> [KairoRecipe] {
        recipes.values.sorted { $0.title < $1.title }
    }

    public func recipe(id: String) async throws -> KairoRecipe? {
        recipes[id]
    }

    public func save(_ recipe: KairoRecipe) async throws {
        var updated = recipe
        updated.updatedAt = Date()
        recipes[recipe.id] = updated
    }

    public func delete(id: String) async throws {
        recipes[id] = nil
    }

    public func setEnabled(_ enabled: Bool, id: String) async throws {
        guard var recipe = recipes[id] else { return }
        recipe.isEnabled = enabled
        recipe.updatedAt = Date()
        recipes[id] = recipe
    }
}

public actor FileBackedKairoRecipeStore: KairoRecipeStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var recipes: [String: KairoRecipe] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func listRecipes() async throws -> [KairoRecipe] {
        recipes.values.sorted { $0.title < $1.title }
    }

    public func recipe(id: String) async throws -> KairoRecipe? {
        recipes[id]
    }

    public func save(_ recipe: KairoRecipe) async throws {
        var updated = recipe
        updated.updatedAt = Date()
        recipes[recipe.id] = updated
        try persist()
    }

    public func delete(id: String) async throws {
        recipes[id] = nil
        try persist()
    }

    public func setEnabled(_ enabled: Bool, id: String) async throws {
        guard var recipe = recipes[id] else { return }
        recipe.isEnabled = enabled
        recipe.updatedAt = Date()
        recipes[id] = recipe
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            recipes = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            recipes = [:]
            return
        }

        let decoded = try decoder.decode([KairoRecipe].self, from: data)
        recipes = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sortedRecipes = recipes.values.sorted { $0.createdAt < $1.createdAt }
        let data = try encoder.encode(sortedRecipes)
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}
