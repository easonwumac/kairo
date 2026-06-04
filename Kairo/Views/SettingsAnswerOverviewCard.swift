#if canImport(SwiftUI)
import SwiftUI

struct SettingsAnswerOverviewCard: View {
    let hasAPIKey: Bool
    let routePreference: ProviderRoutePreference
    let connectedConnectorCount: Int
    let localModelInstalled: Bool

    var body: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(KairoL10n.string("settings.routing.section"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(KairoL10n.string("settings.routing.detail"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    KairoStatusPill(
                        title: hasAPIKey ? KairoL10n.string("settings.routing.cloudReady") : KairoL10n.string("settings.routing.cloudNeedsKey"),
                        systemImage: hasAPIKey ? "checkmark.seal.fill" : "key.fill",
                        tint: hasAPIKey ? KairoDesign.green : KairoDesign.amber
                    )
                    KairoStatusPill(title: routePreference.settingsTitle, systemImage: "switch.2", tint: KairoDesign.blue)
                }

                HStack(spacing: 8) {
                    KairoStatusPill(
                        title: KairoL10n.string("settings.routing.connectedAccounts", Int64(connectedConnectorCount)),
                        systemImage: "person.crop.circle.badge.checkmark",
                        tint: connectedConnectorCount > 0 ? KairoDesign.green : KairoDesign.violet
                    )
                    KairoStatusPill(
                        title: localModelInstalled ? KairoL10n.string("settings.routing.localSelected") : KairoL10n.string("settings.routing.localOptional"),
                        systemImage: "cpu.fill",
                        tint: KairoDesign.teal
                    )
                }
            }
        }
        .accessibilityIdentifier("settings.routing.overview")
    }
}
#endif
