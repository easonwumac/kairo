#if canImport(SwiftUI)
import SwiftUI

struct SettingsPrivacySection: View {
    let statusMessage: String?
    let deleteAllChatHistory: () -> Void
    let deleteAllUserData: () -> Void

    var body: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.privacy.status")
                }

                Button(role: .destructive) {
                    deleteAllChatHistory()
                } label: {
                    destructiveLabel(KairoL10n.string("settings.privacy.deleteAllChatHistory"), systemImage: "text.bubble.fill")
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                .accessibilityIdentifier("settings.privacy.delete-all-chat-history")

                Button(role: .destructive) {
                    deleteAllUserData()
                } label: {
                    destructiveLabel(KairoL10n.string("settings.privacy.deleteAllData"), systemImage: "trash.fill")
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                .accessibilityIdentifier("settings.privacy.delete-all-user-data")
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 30, height: 30)
                .background(KairoDesign.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.privacy.section"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
            }

            Spacer(minLength: 8)
        }
    }

    private func destructiveLabel(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 24, height: 24)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
}
#endif
