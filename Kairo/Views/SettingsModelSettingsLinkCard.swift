#if canImport(SwiftUI)
import SwiftUI

struct SettingsModelSettingsLinkCard: View {
    let localModelStatus: LocalModelSettingsStatus
    let hasAPIKey: Bool
    let connectedConnectorCount: Int

    var body: some View {
        KairoFocusCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "cpu")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)
                    .frame(width: 36, height: 36)
                    .background(KairoDesign.blue.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(KairoL10n.string("settings.models.section"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)

                    Text(summaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(KairoL10n.string("settings.models.entry.accessibility", summaryText))
    }

    private var summaryText: String {
        let cloudStatus = hasAPIKey
            ? KairoL10n.string("settings.models.entry.cloudConfigured")
            : KairoL10n.string("settings.models.entry.cloudNeedsSetup")
        let localStatus = localModelStatus.localModelInstalled
            ? KairoL10n.string("settings.models.entry.localConfigured")
            : KairoL10n.string("settings.models.entry.localNeedsDownload")
        return KairoL10n.string(
            "settings.models.entry.summary",
            cloudStatus,
            Int64(connectedConnectorCount),
            localStatus
        )
    }
}
#endif
