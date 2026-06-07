#if canImport(SwiftUI)
import SwiftUI

struct SettingsOpenAICompatibleSection: View {
    @Binding var endpoint: String
    @Binding var apiKey: String
    @Binding var model: String
    @Binding var displayName: String
    @Binding var showEditor: Bool

    let isConfigured: Bool
    let statusMessage: String?
    let save: () -> Void
    let delete: () -> Void
    let onPushModelPicker: ([String]) -> Void

    @State private var isFetchingModels = false
    @State private var fetchError: String?

    private var trimmedEndpoint: Bool { !endpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var trimmedAPIKey: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 12) {
                summaryRow

                if showEditor {
                    editor
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "network")
                .font(.headline)
                .foregroundStyle(KairoDesign.blue)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(summaryTitle)
                    .font(.subheadline.weight(.semibold))
                if !summarySubtitle.isEmpty {
                    Text(summarySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(isConfigured
                ? KairoL10n.string("settings.omlx.status.configured")
                : KairoL10n.string("settings.omlx.status.notConfigured"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(isConfigured ? .green : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isConfigured ? Color.green : Color.secondary).opacity(0.10), in: Capsule())

            Button {
                withAnimation(.snappy(duration: 0.2)) {
                    showEditor.toggle()
                }
            } label: {
                Image(systemName: showEditor ? "chevron.up.circle.fill" : "pencil.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)
            }
            .buttonStyle(.plain)
        }
    }

    private var summaryTitle: String {
        KairoL10n.string("settings.omlx.apiKey")
    }

    private var summarySubtitle: String {
        if isConfigured {
            let ep = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
            let m = model.trimmingCharacters(in: .whitespacesAndNewlines)
            return m.isEmpty ? ep : "\(ep) · \(m)"
        }
        return ""
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel(KairoL10n.string("settings.omlx.displayName"))
            TextField(KairoL10n.string("settings.omlx.displayNamePlaceholder"), text: $displayName)
                .font(.subheadline)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            fieldLabel(KairoL10n.string("settings.omlx.endpoint"))
            TextField(KairoL10n.string("settings.omlx.endpointPlaceholder"), text: $endpoint)
                .font(.subheadline)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            fieldLabel(KairoL10n.string("settings.omlx.keyLabel"))
            SecureField(KairoL10n.string("settings.omlx.apiKeyPlaceholder"), text: $apiKey)
                .font(.subheadline)
                .textContentType(.password)
                .autocorrectionDisabled()
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            modelSection

            HStack(spacing: 8) {
                Button(KairoL10n.string("settings.omlx.save")) {
                    save()
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true, isCompact: true))
                .disabled(!trimmedEndpoint || !trimmedAPIKey)

                if isConfigured {
                    Button(KairoL10n.string("settings.omlx.delete"), role: .destructive) {
                        delete()
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                }
            }

            if let statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var modelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel(KairoL10n.string("settings.omlx.model"))

            HStack(spacing: 8) {
                if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(KairoL10n.string("settings.omlx.modelPlaceholder"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text(model.trimmingCharacters(in: .whitespacesAndNewlines))
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    fetchModels()
                } label: {
                    if isFetchingModels {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(KairoDesign.blue)
                .disabled(isFetchingModels || !trimmedEndpoint)
                .frame(width: 28, height: 28)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            if let fetchError {
                Text(fetchError)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    private func fetchModels() {
        let ep = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: ep.hasSuffix("/") ? ep + "models" : ep + "/models") else { return }

        isFetchingModels = true
        fetchError = nil

        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 10

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(for: req)
                struct ModelsResponse: Decodable {
                    var data: [ModelEntry]
                    struct ModelEntry: Decodable {
                        var id: String
                    }
                }
                let decoded = try JSONDecoder().decode(ModelsResponse.self, from: data)
                await MainActor.run {
                    isFetchingModels = false
                    let models = decoded.data.map(\.id)
                    onPushModelPicker(models)
                }
            } catch {
                await MainActor.run {
                    fetchError = error.localizedDescription
                    isFetchingModels = false
                }
            }
        }
    }
}
#endif
