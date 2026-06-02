#if canImport(SwiftUI)
import SwiftUI

public struct SettingsView: View {
    @Environment(\.openURL) private var openURL

    @State private var apiKey: String = ""
    @State private var hasAPIKey: Bool = false
    @State private var statusMessage: String?
    @State private var connectorOptions: [OAuthConnectorLoginOption] = []
    @State private var connectorStatusMessage: String?

    private let settingsService: OpenAISettingsService
    private let credentialStore: any CredentialStore
    private let oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]

    public init(
        credentialStore: any CredentialStore = InMemoryCredentialStore(),
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:]
    ) {
        self.settingsService = OpenAISettingsService(credentialStore: credentialStore)
        self.credentialStore = credentialStore
        self.oauthClientConfigurations = oauthClientConfigurations
    }

    public init(
        settingsService: OpenAISettingsService,
        credentialStore: any CredentialStore,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:]
    ) {
        self.settingsService = settingsService
        self.credentialStore = credentialStore
        self.oauthClientConfigurations = oauthClientConfigurations
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI") {
                    HStack {
                        Text("API Key")
                        Spacer()
                        Text(hasAPIKey ? "已設定" : "未設定")
                            .foregroundStyle(hasAPIKey ? .green : .secondary)
                            .accessibilityIdentifier("settings.openai.api-key-status")
                    }

                    SecureField("sk-...", text: $apiKey)
                        .textContentType(.password)
                        .accessibilityIdentifier("settings.openai.api-key-field")

                    HStack {
                        Button("Save API Key") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("settings.openai.save-api-key")

                        Spacer()

                        Button("Delete", role: .destructive) {
                            deleteAPIKey()
                        }
                        .disabled(!hasAPIKey)
                        .accessibilityIdentifier("settings.openai.delete-api-key")
                    }
                }

                Section("OAuth Connectors") {
                    if connectorOptions.isEmpty {
                        Text("尚未載入 connector 狀態。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(connectorOptions) { option in
                        connectorRow(option)
                    }
                }
                .accessibilityIdentifier("settings.oauth.connectors")

                Section("Shortcut Demos") {
                    ForEach(ShortcutDemoCatalog.default.recipes) { recipe in
                        shortcutDemoRow(recipe)
                    }
                }
                .accessibilityIdentifier("settings.shortcuts.demos")

                Section("Privacy") {
                    Text("API key 只應儲存在 Keychain。Kairo 不應把 secret 寫入 UserDefaults、log 或 analytics。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if statusMessage != nil || connectorStatusMessage != nil {
                    Section("Status") {
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption)
                        }
                        if let connectorStatusMessage {
                            Text(connectorStatusMessage)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .accessibilityIdentifier("settings.form")
            .task { await reloadAllStatus() }
        }
    }

    @ViewBuilder
    private func connectorRow(_ option: OAuthConnectorLoginOption) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(option.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Text(option.readiness.settingsStatusText)
                    .font(.caption)
                    .foregroundStyle(statusColor(for: option.readiness))
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).status")
            }

            Text(option.settingsDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if option.requiresBackendTokenExchange {
                Text("需要後端 token exchange。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if option.canStartAuthorization {
                Button("Authorize") {
                    authorizeConnector(option)
                }
                .accessibilityIdentifier("settings.oauth.\(option.providerKey).authorize")
            } else if option.readiness == .needsClientConfiguration {
                Text("尚未設定 iOS OAuth client。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func shortcutDemoRow(_ recipe: ShortcutDemoRecipe) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(recipe.title)
                .font(.subheadline)
                .fontWeight(.medium)

            Text(recipe.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(recipe.triggerSummary)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(recipe.settingsStepSummary)
                .font(.caption)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id)")

            Text(recipe.settingsInputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).input")

            Text(recipe.settingsOutputSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.shortcuts.demo.\(recipe.id).output")

            if !recipe.settingsSampleInputPreview.isEmpty {
                Text(recipe.settingsSampleInputPreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private func saveAPIKey() {
        Task {
            do {
                try await settingsService.saveAPIKey(apiKey)
                await MainActor.run {
                    apiKey = ""
                    statusMessage = "OpenAI API key 已儲存。"
                }
                await reloadStatus()
            } catch {
                await MainActor.run {
                    statusMessage = "儲存失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteAPIKey() {
        Task {
            do {
                try await settingsService.deleteAPIKey()
                await MainActor.run {
                    statusMessage = "OpenAI API key 已刪除。"
                }
                await reloadStatus()
            } catch {
                await MainActor.run {
                    statusMessage = "刪除失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func authorizeConnector(_ option: OAuthConnectorLoginOption) {
        Task {
            do {
                let center = connectorLoginCenter()
                let session = try await center.makeAuthorizationSession(for: option.integrationKey)
                await MainActor.run {
                    connectorStatusMessage = "正在開啟 \(option.displayName) 授權。"
                    openURL(session.authorizationURL)
                }
            } catch {
                await MainActor.run {
                    connectorStatusMessage = "授權啟動失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func reloadAllStatus() async {
        await reloadStatus()
        await reloadConnectorOptions()
    }

    private func reloadStatus() async {
        do {
            let status = try await settingsService.status()
            await MainActor.run {
                hasAPIKey = status.hasAPIKey
            }
        } catch {
            await MainActor.run {
                statusMessage = "讀取設定失敗：\(error.localizedDescription)"
            }
        }
    }

    private func reloadConnectorOptions() async {
        do {
            let options = try await connectorLoginCenter().loginOptions()
            await MainActor.run {
                connectorOptions = options
            }
        } catch {
            await MainActor.run {
                connectorStatusMessage = "讀取 OAuth connector 失敗：\(error.localizedDescription)"
            }
        }
    }

    private func connectorLoginCenter() -> OAuthConnectorLoginCenter {
        OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: credentialStore,
            clientConfigurations: oauthClientConfigurations
        )
    }

    private func statusColor(for readiness: OAuthConnectorLoginReadiness) -> Color {
        switch readiness {
        case .connected:
            return .green
        case .readyToAuthorize:
            return .blue
        case .needsClientConfiguration:
            return .secondary
        case .needsReauthorization:
            return .orange
        }
    }
}
#endif
