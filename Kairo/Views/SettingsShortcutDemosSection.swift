#if canImport(SwiftUI)
import SwiftUI

struct SettingsShortcutDemosSection: View {
    var recipes: [ShortcutDemoRecipe] = ShortcutDemoCatalog.default.recipes

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            KairoFocusCard {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Shortcut Demos")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(KairoDesign.ink)

                    Text(KairoL10n.string("settings.shortcuts.demos.detail"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach(recipes) { recipe in
                KairoFocusCard {
                    shortcutDemoRow(recipe)
                }
            }
        }
        .accessibilityIdentifier("settings.shortcuts.demos")
    }

    @ViewBuilder
    private func shortcutDemoRow(_ recipe: ShortcutDemoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

                Text(recipe.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                KairoStatusPill(
                    title: recipe.triggerSummary,
                    systemImage: "square.and.arrow.down",
                    tint: KairoDesign.blue
                )
            }

            Text(recipe.settingsStepSummary)
                .font(.caption)
                .fontWeight(.semibold)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).steps")

            Text(recipe.settingsInputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).input")

            Text(recipe.settingsOutputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
