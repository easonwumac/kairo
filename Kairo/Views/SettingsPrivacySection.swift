#if canImport(SwiftUI)
import SwiftUI

struct SettingsPrivacySection: View {
    let statusMessage: String?
    let clearAuditLog: () -> Void

    private var displayedStatusMessage: String {
        statusMessage ?? KairoL10n.string("settings.privacy.statusReady")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            KairoGroupedSurface {
                VStack(alignment: .leading, spacing: 12) {
                    headerRow

                    Divider()

                    auditLogStatusRow

                    Text(displayedStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.privacy.status")

                    controls
                }
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
            }

            Spacer(minLength: 8)
        }
    }

    private var auditLogStatusRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "list.bullet.rectangle")
                .font(.headline)
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.privacy.auditLog"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

                Text(displayedStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(KairoL10n.string("settings.privacy.keychainBoundary"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(KairoDesign.teal)
            }

            Text(KairoL10n.string("settings.privacy.auditLogDetail"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.privacy.audit-log-detail")

            Button(role: .destructive) {
                clearAuditLog()
            } label: {
                Label(KairoL10n.string("settings.privacy.clearAuditLog"), systemImage: "trash.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.privacy.clear-audit-log")
        }
    }
}
#endif
