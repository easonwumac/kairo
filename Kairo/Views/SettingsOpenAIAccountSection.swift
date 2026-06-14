#if canImport(SwiftUI)
import SwiftUI

struct SettingsOpenAIAccountSection: View {
    @Binding var apiKey: String
    @Binding var showAPIKeyEditor: Bool

    let hasAPIKey: Bool
    let statusMessage: String?
    let saveAPIKey: () -> Void
    let dryRunAPIKey: () -> Void
    let deleteAPIKey: () -> Void

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow

                if showAPIKeyEditor {
                    editor
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "key.fill")
                .font(.headline)
                .foregroundStyle(KairoDesign.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.openai.apiKey"))
                    .font(.subheadline.weight(.semibold))
            }

            Spacer(minLength: 8)

            Text(hasAPIKey ? KairoL10n.string("settings.openai.status.configured") : KairoL10n.string("settings.openai.status.notConfigured"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(hasAPIKey ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((hasAPIKey ? Color.green : Color.secondary).opacity(0.10), in: Capsule())
                .accessibilityIdentifier("settings.openai.api-key-status")

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    showAPIKeyEditor.toggle()
                }
            } label: {
                Image(systemName: showAPIKeyEditor ? "chevron.up.circle.fill" : "pencil.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(showAPIKeyEditor ? KairoL10n.string("settings.openai.editor.hide") : KairoL10n.string("settings.openai.editor.show"))
            .accessibilityIdentifier("settings.openai.editor-toggle")
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            SecureField(KairoL10n.string("settings.openai.apiKeyPlaceholder"), text: $apiKey)
                .textContentType(.password)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .kairoGlassField(tint: KairoDesign.blue)
                .accessibilityIdentifier("settings.openai.api-key-field")

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                Button(KairoL10n.string("settings.openai.save")) {
                    saveAPIKey()
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true, isCompact: true))
                .disabled(trimmedAPIKey.isEmpty)
                .accessibilityIdentifier("settings.openai.save-api-key")

                if hasAPIKey {
                    Button(KairoL10n.string("settings.openai.delete"), role: .destructive) {
                        deleteAPIKey()
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                    .accessibilityIdentifier("settings.openai.delete-api-key")
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.openai.status-message")
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
    }
}
#endif
