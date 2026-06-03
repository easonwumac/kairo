#if canImport(SwiftUI)
import SwiftUI

struct SettingsShortcutDemosSection: View {
    var recipes: [ShortcutDemoRecipe] = ShortcutDemoCatalog.default.recipes

    var body: some View {
        Section("Shortcut Demos") {
            ForEach(recipes) { recipe in
                shortcutDemoRow(recipe)
            }
        }
        .accessibilityIdentifier("settings.shortcuts.demos")
    }

    @ViewBuilder
    private func shortcutDemoRow(_ recipe: ShortcutDemoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recipe.triggerSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(recipe.settingsStepSummary)
                .font(.caption)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).steps")

            Text(recipe.settingsInputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).input")

            Text(recipe.settingsOutputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).output")

            if !recipe.settingsSampleInputPreview.isEmpty {
                Text(recipe.settingsSampleInputPreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).sample")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id)")
    }
}
#endif
