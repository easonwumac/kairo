#if canImport(SwiftUI)
import SwiftUI

public struct AutomationsView: View {
    private let recipeStore: any KairoRecipeStore
    private let memoryStore: (any MemoryStore)?
    private let aiProvider: (any AIProvider)?

    @State private var recipes: [KairoRecipe] = []
    @State private var message: String?
    @State private var isLoading = false

    public init(
        recipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil
    ) {
        self.recipeStore = recipeStore
        self.memoryStore = memoryStore
        self.aiProvider = aiProvider
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Center") {
                    Text("Kairo internal recipe center. Kairo creates internal recipes and does not create Apple Shortcuts silently.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Add Sample Recipes") {
                        Task { await seedSampleRecipes() }
                    }
                    .accessibilityIdentifier("automations.seed-samples")
                }

                Section("Recipes") {
                    if recipes.isEmpty {
                        Text("No internal recipes yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(recipes) { recipe in
                        recipeRow(recipe)
                    }
                }
                .accessibilityIdentifier("automations.list")

                if let message {
                    Section("Status") {
                        Text(message)
                            .font(.caption)
                            .accessibilityIdentifier("automations.message")
                    }
                }
            }
            .navigationTitle("Automations")
            .accessibilityIdentifier("automations.recipe-center")
            .task {
                await loadRecipes()
            }
        }
    }

    private func recipeRow(_ recipe: KairoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.title)
                    .font(.headline)
                    .accessibilityIdentifier("automations.recipe.\(recipe.id)")
                Spacer()
                Text(recipe.isEnabled ? "Enabled" : "Disabled")
                    .font(.caption)
                    .foregroundStyle(recipe.isEnabled ? .green : .secondary)
            }

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("Risk: \(recipe.riskTier.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button("Preview") {
                    Task { await preview(recipe) }
                }
                .disabled(!recipe.isEnabled || isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).preview")

                Button("Run") {
                    Task { await run(recipe) }
                }
                .disabled(!recipe.isEnabled || isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).run")

                Button(recipe.isEnabled ? "Disable" : "Enable") {
                    Task { await toggle(recipe) }
                }
                .disabled(isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).toggle")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    @MainActor
    private func loadRecipes() async {
        do {
            recipes = try await recipeStore.listRecipes()
        } catch {
            message = "Unable to load Kairo internal recipes."
        }
    }

    @MainActor
    private func seedSampleRecipes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            for recipe in KairoRecipeTemplateFactory.sampleCatalog().recipes {
                try await recipeStore.save(recipe)
            }
            recipes = try await recipeStore.listRecipes()
            message = "Added \(recipes.count) Kairo internal recipe samples."
        } catch {
            message = "Unable to add Kairo internal recipe samples."
        }
    }

    @MainActor
    private func preview(_ recipe: KairoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await runner.run(KairoRecipeRunRequest(
                recipeID: recipe.id,
                surface: .app,
                input: recipe.summary,
                dryRun: true,
                userConfirmed: false
            ))
            message = "Preview \(recipe.title): \(result.summary)"
        } catch {
            message = "Unable to preview \(recipe.title)."
        }
    }

    @MainActor
    private func run(_ recipe: KairoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await runner.run(KairoRecipeRunRequest(
                recipeID: recipe.id,
                surface: .app,
                input: recipe.summary,
                dryRun: false,
                userConfirmed: true
            ))
            if result.requiresConfirmation {
                message = "\(recipe.title) requires confirmation in Kairo before running."
            } else {
                message = "Ran \(recipe.title): \(result.summary)"
            }
        } catch {
            message = "Unable to run \(recipe.title)."
        }
    }

    @MainActor
    private func toggle(_ recipe: KairoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let nextEnabled = !recipe.isEnabled
            try await recipeStore.setEnabled(nextEnabled, id: recipe.id)
            recipes = try await recipeStore.listRecipes()
            message = "\(nextEnabled ? "Enabled" : "Disabled") \(recipe.title)."
        } catch {
            message = "Unable to update \(recipe.title)."
        }
    }

    private var runner: KairoRecipeRunner {
        KairoRecipeRunner(
            recipeStore: recipeStore,
            memoryStore: memoryStore,
            aiProvider: aiProvider
        )
    }
}
#endif
