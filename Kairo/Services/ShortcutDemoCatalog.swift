import Foundation

public struct ShortcutDemoCatalog: Codable, Equatable, Sendable {
    public var recipes: [ShortcutDemoRecipe]

    public init(recipes: [ShortcutDemoRecipe]) {
        self.recipes = recipes
    }

    public func recipe(id: String) -> ShortcutDemoRecipe? {
        recipes.first { $0.id == id }
    }

    public static let `default` = ShortcutDemoCatalog(recipes: ShortcutDemoCatalog.officialRecipes)
}
