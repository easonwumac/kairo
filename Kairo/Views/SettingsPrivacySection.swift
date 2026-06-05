#if canImport(SwiftUI)
import SwiftUI

struct SettingsPrivacySection: View {
    let statusMessage: String?
    let clearAuditLog: () -> Void

    private var displayedStatusMessage: String {
        statusMessage ?? KairoL10n.string("settings.privacy.statusReady")
    }

    var body: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                Text(displayedStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.privacy.status")

                Button(role: .destructive) {
                    clearAuditLog()
                } label: {
                    Label(KairoL10n.string("settings.privacy.clearAuditLog"), systemImage: "trash.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                .accessibilityIdentifier("settings.privacy.clear-audit-log")
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.headline)
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.privacy.section"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(KairoL10n.string("settings.privacy.summary"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
        }
    }
}
#endif
