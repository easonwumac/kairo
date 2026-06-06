import Foundation

public enum KairoOnboarding {
    public static let completedStorageKey = "kairo.onboarding.completed"

    public static let defaultCategories: [KairoOnboardingCategory] = [
        .init(id: "travel", titleKey: "category.travel"),
        .init(id: "bookings", titleKey: "category.bookings"),
        .init(id: "receipts", titleKey: "category.receipts"),
        .init(id: "warranty", titleKey: "category.warranty"),
        .init(id: "projects", titleKey: "category.projects"),
        .init(id: "meetings", titleKey: "category.meetings"),
        .init(id: "medical", titleKey: "category.medical"),
        .init(id: "finance", titleKey: "category.finance"),
        .init(id: "identity", titleKey: "category.identity"),
        .init(id: "home-devices", titleKey: "category.homeDevices"),
        .init(id: "subscriptions", titleKey: "category.subscriptions"),
        .init(id: "recipes", titleKey: "category.recipes"),
        .init(id: "learning", titleKey: "category.learning"),
        .init(id: "shopping", titleKey: "category.shopping"),
        .init(id: "family", titleKey: "category.family"),
        .init(id: "work", titleKey: "category.work"),
        .init(id: "legal", titleKey: "category.legal"),
        .init(id: "ideas", titleKey: "category.ideas"),
        .init(id: "passwords", titleKey: "category.passwords"),
        .init(id: "general", titleKey: "category.general")
    ]

    public static func folders(for selectedIDs: Set<String>, now: Date = Date()) -> [KnowledgeAssetFolder] {
        defaultCategories
            .filter { selectedIDs.contains($0.id) }
            .map { category in
                KnowledgeAssetFolder(name: KairoL10n.string(category.titleKey), createdAt: now, updatedAt: now)
            }
    }
}

public struct KairoOnboardingCategory: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var titleKey: String

    public init(id: String, titleKey: String) {
        self.id = id
        self.titleKey = titleKey
    }
}
