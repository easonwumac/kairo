#if canImport(SwiftUI)
import SwiftUI

public struct AutomationsView: View {
    @Environment(\.openURL) private var openURL

    private let recipeAPI: any KairoRecipeAPI
    private let shortcutTemplateRegistry: ShortcutTemplateRegistry

    @State private var recipes: [KairoRecipe] = []
    @State private var message: String?
    @State private var shortcutDemoPreviewMessages: [String: String] = [:]
    @State private var isLoading = false

    public init(
        recipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = ShortcutTemplateRegistry.default
    ) {
        self.recipeAPI = KairoRecipeBackendService(
            recipeStore: recipeStore,
            memoryStore: memoryStore,
            aiProvider: aiProvider
        )
        self.shortcutTemplateRegistry = shortcutTemplateRegistry
    }

    public init(
        recipeAPI: any KairoRecipeAPI,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = ShortcutTemplateRegistry.default
    ) {
        self.recipeAPI = recipeAPI
        self.shortcutTemplateRegistry = shortcutTemplateRegistry
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(KairoL10n.string("automations.title"))
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(KairoL10n.string("automations.subtitle"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                automationSection(KairoL10n.string("automations.recipeCenter.section")) {
                    Text(KairoL10n.string("automations.recipeCenter.detail"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Button(KairoL10n.string("automations.recipeCenter.addSamples")) {
                        Task { await seedSampleRecipes() }
                    }
                    .accessibilityLabel(KairoL10n.string("automations.recipeCenter.addSamples"))
                    .accessibilityIdentifier("automations.seed-samples")
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .accessibilityIdentifier("automations.recipe-center")

                automationSection(KairoL10n.string("automations.shortcutTemplates.section")) {
                    Text(shortcutTemplateRegistry.manualInstallDisclaimer)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("automations.shortcut-template.disclaimer")

                    ForEach(shortcutTemplateRegistry.templates) { template in
                        shortcutTemplateRow(template)
                    }
                }
                .accessibilityIdentifier("automations.shortcut-templates")

                automationSection(KairoL10n.string("automations.shortcutDemos.section")) {
                    Text(KairoL10n.string("automations.shortcutDemos.detail"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    ForEach(ShortcutDemoCatalog.default.recipes) { recipe in
                        shortcutDemoRow(recipe)
                    }
                }
                .accessibilityIdentifier("automations.shortcut-demos")

                automationSection(KairoL10n.string("automations.recipes.section")) {
                    if recipes.isEmpty {
                        Text(KairoL10n.string("automations.recipes.empty"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(recipes) { recipe in
                        recipeRow(recipe)
                    }
                }
                .accessibilityIdentifier("automations.list")

                if let message {
                    automationSection(KairoL10n.string("automations.status.section")) {
                        Text(message)
                            .font(.caption2)
                            .accessibilityIdentifier("automations.message")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea())
        .task {
            await loadRecipes()
        }
    }

    private func automationSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            automationSectionHeader(title)
            content()
            Divider()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func automationSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.none)
    }

    private func shortcutTemplateRow(_ template: ShortcutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(template.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier("automations.shortcut-template.\(template.identifier)")

            if !template.description.isEmpty {
                Text(template.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(template.setupInstructions.joined(separator: "\n"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("automations.shortcut-template.\(template.identifier).instructions")

            if let installURL = template.installURL {
                Button(KairoL10n.string("automations.shortcutTemplates.openTemplate")) {
                    openURL(installURL)
                }
                .accessibilityIdentifier("automations.shortcut-template.\(template.identifier).open")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func shortcutDemoRow(_ recipe: ShortcutDemoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id)")

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recipe.settingsStepSummary)
                .font(.caption)
                .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).steps")

            Text(recipe.settingsInputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).input")

            Text(recipe.settingsOutputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).output")

            if !recipe.settingsSampleInputPreview.isEmpty {
                Text(recipe.settingsSampleInputPreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).sample")
            }

            Button(KairoL10n.string("automations.shortcutDemos.previewSample")) {
                Task { await previewShortcutDemo(recipe) }
            }
            .accessibilityLabel(KairoL10n.string("automations.shortcutDemos.previewSampleAccessibility", recipe.title))
            .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).preview-sample")
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isLoading)

            if let previewMessage = shortcutDemoPreviewMessages[recipe.id] {
                Text(previewMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).preview-result")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func recipeRow(_ recipe: KairoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.title)
                    .font(.headline)
                    .accessibilityIdentifier("automations.recipe.\(recipe.id)")
                Spacer()
                Text(recipe.isEnabled ? KairoL10n.string("automations.recipe.enabled") : KairoL10n.string("automations.recipe.disabled"))
                    .font(.caption)
                    .foregroundStyle(recipe.isEnabled ? .green : .secondary)
            }

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(KairoL10n.string("automations.recipe.risk", recipe.riskTier.rawValue))
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button(KairoL10n.string("automations.recipe.preview")) {
                    Task { await preview(recipe) }
                }
                .disabled(!recipe.isEnabled || isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).preview")

                Button(KairoL10n.string("automations.recipe.run")) {
                    Task { await run(recipe) }
                }
                .disabled(!recipe.isEnabled || isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).run")

                Button(recipe.isEnabled ? KairoL10n.string("automations.recipe.disable") : KairoL10n.string("automations.recipe.enable")) {
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
            recipes = try await recipeAPI.listRecipes()
        } catch {
            message = KairoL10n.string("automations.message.loadFailed")
        }
    }

    @MainActor
    private func seedSampleRecipes() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recipes = try await recipeAPI.seedSampleRecipes()
            message = KairoL10n.string("automations.message.samplesAdded", Int64(recipes.count))
        } catch {
            message = KairoL10n.string("automations.message.samplesAddFailed")
        }
    }

    @MainActor
    private func previewShortcutDemo(_ recipe: ShortcutDemoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
            let runner = ShortcutDemoRecipeRunner(runtime: runtime)
            let run = try await runner.runSample(recipe)
            let finalOutput = run.steps.last?.output.displayText.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalOutputSummary = finalOutput?.isEmpty == false ? " \(finalOutput ?? "")" : ""
            let previewMessage = KairoL10n.string("automations.message.samplePreview", run.displaySummary, finalOutputSummary)
            shortcutDemoPreviewMessages[recipe.id] = previewMessage
            message = previewMessage
        } catch {
            let previewMessage = KairoL10n.string("automations.message.samplePreviewFailed", recipe.title)
            shortcutDemoPreviewMessages[recipe.id] = previewMessage
            message = previewMessage
        }
    }

    @MainActor
    private func preview(_ recipe: KairoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await recipeAPI.run(KairoRecipeRunRequest(
                recipeID: recipe.id,
                surface: .app,
                input: recipe.summary,
                dryRun: true,
                userConfirmed: false
            ))
            message = KairoL10n.string("automations.message.previewResult", recipe.title, result.summary)
        } catch {
            message = KairoL10n.string("automations.message.previewFailed", recipe.title)
        }
    }

    @MainActor
    private func run(_ recipe: KairoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await recipeAPI.run(KairoRecipeRunRequest(
                recipeID: recipe.id,
                surface: .app,
                input: recipe.summary,
                dryRun: false,
                userConfirmed: true
            ))
            if result.requiresConfirmation {
                message = KairoL10n.string("automations.message.requiresConfirmation", recipe.title)
            } else {
                message = KairoL10n.string("automations.message.runResult", recipe.title, result.summary)
            }
        } catch {
            message = KairoL10n.string("automations.message.runFailed", recipe.title)
        }
    }

    @MainActor
    private func toggle(_ recipe: KairoRecipe) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let nextEnabled = !recipe.isEnabled
            try await recipeAPI.setEnabled(nextEnabled, id: recipe.id)
            recipes = try await recipeAPI.listRecipes()
            let state = nextEnabled ? KairoL10n.string("automations.recipe.enabled") : KairoL10n.string("automations.recipe.disabled")
            message = KairoL10n.string("automations.message.toggleResult", state, recipe.title)
        } catch {
            message = KairoL10n.string("automations.message.toggleFailed", recipe.title)
        }
    }
}
#endif
