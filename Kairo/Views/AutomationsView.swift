#if canImport(SwiftUI)
import SwiftUI

public struct AutomationsView: View {
    @Environment(\.openURL) private var openURL

    private let recipeAPI: any KairoRecipeAPI
    private let shortcutTemplateRegistry: ShortcutTemplateRegistry
    private let shortcutDemoRecipeRunner: any ShortcutDemoRecipeRunnerProtocol

    @State private var recipes: [KairoRecipe] = []
    @State private var message: String?
    @State private var shortcutDemoPreviewMessages: [String: String] = [:]
    @State private var isLoading = false
    @State private var showWorkflowDetails = false
    @State private var showAdvancedWorkflowReferences = false

    public init(dependencies: AutomationsFeatureDependencies) {
        self.recipeAPI = dependencies.recipeAPI
        self.shortcutTemplateRegistry = dependencies.shortcutTemplateRegistry
        self.shortcutDemoRecipeRunner = dependencies.shortcutDemoRecipeRunner
    }

    public init(
        recipeStore: any KairoRecipeStore = InMemoryKairoRecipeStore(),
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = ShortcutTemplateRegistry.default,
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog()
    ) {
        self.init(
            dependencies: AutomationsFeatureDependencies(
                recipeStore: recipeStore,
                memoryStore: memoryStore,
                aiProvider: aiProvider,
                shortcutTemplateRegistry: shortcutTemplateRegistry,
                toolCatalog: toolCatalog
            )
        )
    }

    public init(
        recipeAPI: any KairoRecipeAPI,
        shortcutTemplateRegistry: ShortcutTemplateRegistry = ShortcutTemplateRegistry.default,
        shortcutDemoRecipeRunner: (any ShortcutDemoRecipeRunnerProtocol)? = nil
    ) {
        if let shortcutDemoRecipeRunner {
            self.init(
                dependencies: AutomationsFeatureDependencies(
                    recipeAPI: recipeAPI,
                    shortcutTemplateRegistry: shortcutTemplateRegistry,
                    shortcutDemoRecipeRunner: shortcutDemoRecipeRunner
                )
            )
        } else {
            self.init(
                dependencies: AutomationsFeatureDependencies(
                    recipeAPI: recipeAPI,
                    shortcutTemplateRegistry: shortcutTemplateRegistry
                )
            )
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if recipes.isEmpty {
                    recipeCenterCard
                    workflowOverviewCard
                } else {
                    workflowOverviewCard
                    savedRecipesCard
                    recipeCenterCard
                }
                advancedWorkflowReferenceCard

                if let message {
                    statusCard(message)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea())
        .task {
            await loadRecipes()
        }
    }

    private var workflowOverviewCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(KairoL10n.string("automations.title"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(KairoDesign.ink)
                }

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showWorkflowDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(KairoL10n.string("automations.details.title"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: showWorkflowDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("automations.details.toggle")

                if showWorkflowDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            KairoStatusPill(
                                title: KairoL10n.string("automations.status.recipes", Int64(recipes.count)),
                                systemImage: "point.topleft.down.curvedto.point.bottomright.up",
                                tint: KairoDesign.blue
                            )
                            KairoStatusPill(
                                title: KairoL10n.string("automations.status.reviewFirst"),
                                systemImage: "checkmark.shield.fill",
                                tint: KairoDesign.green
                            )
                        }

                        KairoStatusPill(
                            title: KairoL10n.string("automations.recipeCenter.boundary"),
                            systemImage: "checkmark.shield.fill",
                            tint: KairoDesign.green
                        )
                        .accessibilityIdentifier("automations.recipe-center.boundary")
                    }
                }
            }
        }
    }

    private var recipeCenterCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(KairoL10n.string(recipes.isEmpty ? "automations.recipeCenter.emptySection" : "automations.recipeCenter.section"))
                    .accessibilityIdentifier("automations.recipe-center")

                automationSectionTitle(
                    title: KairoL10n.string(recipes.isEmpty ? "automations.recipeCenter.emptySection" : "automations.recipeCenter.section")
                )

                Button {
                    Task { await seedSampleRecipes() }
                } label: {
                    Label(KairoL10n.string(recipes.isEmpty ? "automations.recipeCenter.addStarter" : "automations.recipeCenter.addSamples"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
                .accessibilityLabel(KairoL10n.string(recipes.isEmpty ? "automations.recipeCenter.addStarter" : "automations.recipeCenter.addSamples"))
                .accessibilityIdentifier("automations.seed-samples")
            }
        }
    }

    private var savedRecipesCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                automationSectionTitle(
                    title: KairoL10n.string("automations.recipes.section")
                )

                if recipes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(KairoL10n.string("automations.recipes.empty"), systemImage: "tray")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                        Text(KairoL10n.string("automations.recipes.empty.detail"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                    .accessibilityIdentifier("automations.recipes.empty")
                } else {
                    ForEach(recipes) { recipe in
                        recipeRow(recipe)
                        if recipe.id != recipes.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("automations.list")
    }

    private var advancedWorkflowReferenceCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showAdvancedWorkflowReferences.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            automationSectionHeader(KairoL10n.string("automations.advanced.section"))
                        }

                        Spacer(minLength: 8)

                        Image(systemName: showAdvancedWorkflowReferences ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                            .frame(width: 36, height: 36)
                            .background(KairoDesign.blue.opacity(0.10), in: Circle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showAdvancedWorkflowReferences ? KairoL10n.string("automations.advanced.hide") : KairoL10n.string("automations.advanced.show"))
                .accessibilityIdentifier("automations.advanced.toggle")

                if showAdvancedWorkflowReferences {
                    shortcutTemplatesSection
                    Divider()
                    shortcutDemoSection
                }
            }
        }
        .accessibilityIdentifier("automations.advanced")
    }

    private var shortcutTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            automationSectionTitle(
                title: KairoL10n.string("automations.shortcutTemplates.section")
            )

            Text(shortcutTemplateRegistry.manualInstallDisclaimer)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("automations.shortcut-template.disclaimer")

            ForEach(shortcutTemplateRegistry.templates) { template in
                Divider()
                shortcutTemplateRow(template)
            }
        }
        .accessibilityIdentifier("automations.shortcut-templates")
    }

    private var shortcutDemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            automationSectionTitle(
                title: KairoL10n.string("automations.shortcutDemos.section")
            )

            ForEach(ShortcutDemoCatalog.default.recipes) { recipe in
                shortcutDemoRow(recipe)
                if recipe.id != ShortcutDemoCatalog.default.recipes.last?.id {
                    Divider()
                }
            }
        }
        .accessibilityIdentifier("automations.shortcut-demos")
    }

    private func statusCard(_ message: String) -> some View {
        KairoFocusCard {
            Label(message, systemImage: "info.circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("automations.message")
        }
    }

    private func automationSectionTitle(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            automationSectionHeader(title)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func automationSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline.weight(.semibold))
            .foregroundStyle(KairoDesign.ink)
    }

    private func automationSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            automationSectionHeader(title)
            content()
        }
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
                .lineLimit(4)
                .accessibilityIdentifier("automations.shortcut-template.\(template.identifier).instructions")

            if let installURL = template.installURL {
                Button {
                    openURL(installURL)
                } label: {
                    Label(KairoL10n.string("automations.shortcutTemplates.openTemplate"), systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
                .lineLimit(2)
                .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).steps")

            Text(recipe.settingsInputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityIdentifier("automations.shortcut-demo.\(recipe.id).input")

            Text(recipe.settingsOutputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(recipe.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(2)
                Spacer()
                KairoStatusPill(
                    title: recipe.isEnabled ? KairoL10n.string("automations.recipe.enabled") : KairoL10n.string("automations.recipe.disabled"),
                    systemImage: recipe.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill",
                    tint: recipe.isEnabled ? KairoDesign.green : KairoDesign.ink.opacity(0.55)
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("automations.recipe.\(recipe.id)")

            HStack(spacing: 8) {
                KairoStatusPill(
                    title: KairoL10n.string("automations.recipe.risk", recipe.riskTier.rawValue),
                    systemImage: "shield.lefthalf.filled",
                    tint: KairoDesign.amber
                )
                KairoStatusPill(
                    title: KairoL10n.string("automations.recipe.reviewThenRun"),
                    systemImage: "doc.text.magnifyingglass",
                    tint: KairoDesign.blue
                )
            }

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                Button {
                    Task { await preview(recipe) }
                } label: {
                    Label(KairoL10n.string("automations.recipe.preview"), systemImage: "doc.text.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!recipe.isEnabled || isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).preview")

                Button {
                    Task { await run(recipe) }
                } label: {
                    Label(KairoL10n.string("automations.recipe.run"), systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!recipe.isEnabled || isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).run")
                .buttonStyle(.bordered)

                Button {
                    Task { await toggle(recipe) }
                } label: {
                    Label(
                        recipe.isEnabled ? KairoL10n.string("automations.recipe.disable") : KairoL10n.string("automations.recipe.enable"),
                        systemImage: recipe.isEnabled ? "pause.circle" : "play.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .disabled(isLoading)
                .accessibilityIdentifier("automations.recipe.\(recipe.id).toggle")
                .buttonStyle(.bordered)
            }
            .accessibilityIdentifier("automations.recipe.\(recipe.id).actions")
        }
        .padding(.vertical, 6)
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
            let run = try await shortcutDemoRecipeRunner.runSample(recipe)
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
