#if canImport(SwiftUI)
import SwiftUI

struct SettingsPrivacySection: View {
    let statusMessage: String?
    let deleteAllChatHistory: () -> Void

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
                    Label(KairoL10n.string("settings.privacy.deleteAllChatHistory"), systemImage: "trash.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                .accessibilityIdentifier("settings.privacy.delete-all-chat-history")
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
}
#endif
