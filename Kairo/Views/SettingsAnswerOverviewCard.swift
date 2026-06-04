#if canImport(SwiftUI)
import SwiftUI

struct SettingsAnswerOverviewCard: View {
    @State private var showSetupDetails = false

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
                }

                KairoStatusPill(title: routePreference.settingsTitle, systemImage: "switch.2", tint: KairoDesign.blue)

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showSetupDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(KairoL10n.string("settings.routing.details.title"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: showSetupDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("settings.routing.details.toggle")

                if showSetupDetails {
                    Text(KairoL10n.string("settings.routing.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(KairoL10n.string("settings.routing.details.subtitle"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        KairoStatusPill(
                            title: hasAPIKey ? KairoL10n.string("settings.routing.cloudReady") : KairoL10n.string("settings.routing.cloudNeedsKey"),
                            systemImage: hasAPIKey ? "checkmark.seal.fill" : "key.fill",
                            tint: hasAPIKey ? KairoDesign.green : KairoDesign.amber
                        )
                        KairoStatusPill(
                            title: KairoL10n.string("settings.routing.connectedAccounts", Int64(connectedConnectorCount)),
                            systemImage: "person.crop.circle.badge.checkmark",
                            tint: connectedConnectorCount > 0 ? KairoDesign.green : KairoDesign.violet
                        )
                    }

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
