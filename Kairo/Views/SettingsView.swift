#if canImport(SwiftUI)
import SwiftUI

public enum SettingsViewMode: String, Sendable {
    case all
    case modelsOnly
    case shortcutDemosOnly

    var navigationTitle: String {
        switch self {
        case .all:
            return KairoL10n.string("settings.title.all")
        case .modelsOnly:
            return KairoL10n.string("settings.title.models")
        case .shortcutDemosOnly:
            return KairoL10n.string("settings.title.shortcutDemos")
        }
    }
}

public struct SettingsView: View {
    @Environment(\.openURL) private var openURL

    @State private var apiKey: String = ""
    @State private var hasAPIKey: Bool = false
    @State private var statusMessage: String?
    @State private var connectorOptions: [OAuthConnectorLoginOption] = []
    @State private var connectorStatusMessage: String?
    @State private var oauthCallbackURLText: String = ""
    @State private var oauthCallbackPreviewMessage: String?
    @State private var localModelCatalog: LocalModelCatalog
    @State private var localModelStatus: LocalModelSettingsStatus
    @State private var localModelDownloadProgress: LocalModelDownloadProgressState?
    @State private var localModelDownloadTask: Task<Void, Never>?
    @State private var localModelStatusMessage: String?
    @State private var localModelStatusMessageModelID: String?
    @State private var privacyStatusMessage: String?

    private let settingsService: OpenAISettingsService
    private let mode: SettingsViewMode
    private let credentialStore: any CredentialStore
    private let oauthClientConfigurations: [String: OAuthConnectorClientConfiguration]
    private let oauthCallbackStore: FileBackedOAuthConnectorCallbackStore?
    private let localModelCatalogService: LocalModelCatalogService?
    private let localModelSettingsService: LocalModelSettingsService?
    private let localModelDownloader: (any LocalModelDownloader)?
    private let localModelBenchmarkService: LocalModelBenchmarkService?
    private let localModelReplyCheckService: LocalModelReplyCheckService?
    private let deletionAPI: (any KairoDeletionAPI)?

    public init(
        mode: SettingsViewMode = .all,
        credentialStore: any CredentialStore = InMemoryCredentialStore(),
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) {
        self.settingsService = OpenAISettingsService(credentialStore: credentialStore)
        self.mode = mode
        self.credentialStore = credentialStore
        self.oauthClientConfigurations = oauthClientConfigurations
        self.oauthCallbackStore = oauthCallbackStore
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.deletionAPI = deletionAPI
        self._localModelCatalog = State(initialValue: localModelCatalog)
        self._localModelStatus = State(initialValue: Self.catalogOnlyLocalModelStatus(catalog: localModelCatalog))
    }

    public init(
        settingsService: OpenAISettingsService,
        mode: SettingsViewMode = .all,
        credentialStore: any CredentialStore,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) {
        self.settingsService = settingsService
        self.mode = mode
        self.credentialStore = credentialStore
        self.oauthClientConfigurations = oauthClientConfigurations
        self.oauthCallbackStore = oauthCallbackStore
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.deletionAPI = deletionAPI
        self._localModelCatalog = State(initialValue: localModelCatalog)
        self._localModelStatus = State(initialValue: Self.catalogOnlyLocalModelStatus(catalog: localModelCatalog))
    }

    public var body: some View {
        Group {
            switch mode {
            case .modelsOnly:
                modelsOnlyContent
            case .shortcutDemosOnly:
                shortcutDemosOnlyContent
            case .all:
                settingsFormContent
            }
        }
        .task {
            guard mode != .shortcutDemosOnly else { return }
            await reloadAllStatus()
        }
    }

    private var settingsFormContent: some View {
        NavigationStack {
            Form {
                Section(KairoL10n.string("settings.openai.section")) {
                    HStack {
                        Text(KairoL10n.string("settings.openai.apiKey"))
                        Spacer()
                        Text(hasAPIKey ? KairoL10n.string("settings.openai.status.configured") : KairoL10n.string("settings.openai.status.notConfigured"))
                            .foregroundStyle(hasAPIKey ? .green : .secondary)
                            .accessibilityIdentifier("settings.openai.api-key-status")
                    }

                    SecureField("sk-...", text: $apiKey)
                        .textContentType(.password)
                        .accessibilityIdentifier("settings.openai.api-key-field")

                    HStack {
                        Button(KairoL10n.string("settings.openai.save")) {
                            saveAPIKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("settings.openai.save-api-key")

                        Button(KairoL10n.string("settings.openai.dryRun")) {
                            dryRunAPIKey()
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !hasAPIKey)
                        .accessibilityIdentifier("settings.openai.dry-run-api-key")
                    }

                    Button(KairoL10n.string("settings.openai.delete"), role: .destructive) {
                        deleteAPIKey()
                    }
                    .disabled(!hasAPIKey)
                    .accessibilityIdentifier("settings.openai.delete-api-key")

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption)
                            .accessibilityIdentifier("settings.openai.status-message")
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

                    oauthCallbackPreviewControls()
                }
                .accessibilityIdentifier("settings.oauth.connectors")

                Section(KairoL10n.string("settings.models.section")) {
                    localModelPreferencePicker()
                    localModelCatalogControls()

                    if localModelStatus.settingsRows.isEmpty {
                        Text(KairoL10n.string("settings.models.emptyCatalog"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(localModelStatus.settingsRows) { row in
                        localModelRow(row)
                    }

                    if localModelStatusMessageModelID == nil, let localModelStatusMessage {
                        Text(localModelStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("settings.models.benchmark-message")
                    }
                }
                .accessibilityIdentifier("settings.models.local")

                SettingsShortcutDemosSection()

                Section("Privacy") {
                    Text("API key 只應儲存在 Keychain。Kairo 不應把 secret 寫入 UserDefaults、log 或 analytics。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Clear Audit Log", role: .destructive) {
                        clearAuditLog()
                    }
                    .disabled(deletionAPI == nil)
                    .accessibilityIdentifier("settings.privacy.clear-audit-log")

                    Text("Clears the local metadata-only audit log. It does not delete chat history, memories, API keys, OAuth tokens, or downloaded models.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.privacy.audit-log-detail")

                    if let privacyStatusMessage {
                        Text(privacyStatusMessage)
                            .font(.caption)
                            .accessibilityIdentifier("settings.privacy.status")
                    }
                }
                .accessibilityIdentifier("settings.privacy")

                if connectorStatusMessage != nil {
                    Section("Status") {
                        if let connectorStatusMessage {
                            Text(connectorStatusMessage)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle(mode.navigationTitle)
            .accessibilityIdentifier("settings.form")
        }
    }

    private var modelsOnlyContent: some View {
        LocalModelsCompactView(
            localModelStatus: localModelStatus,
            localModelDownloadProgress: localModelDownloadProgress,
            localModelStatusMessage: localModelStatusMessage,
            localModelStatusMessageModelID: localModelStatusMessageModelID,
            localModelCatalogSourceText: localModelCatalogSourceText,
            localModelStatusColor: { localModelStatusColor(for: $0) },
            setLocalModelPreference: { setLocalModelPreference($0) },
            refreshLocalModelCatalog: refreshLocalModelCatalog,
            downloadLocalModel: { downloadLocalModel($0) },
            cancelLocalModelDownload: { cancelLocalModelDownload($0) },
            selectLocalModel: { selectLocalModel($0) },
            runLocalModelBenchmark: { runLocalModelBenchmark($0) },
            runLocalModelReplyCheck: { runLocalModelReplyCheck($0) },
            deleteLocalModel: { deleteLocalModel($0) }
        )
    }

    private var shortcutDemosOnlyContent: some View {
        NavigationStack {
            Form {
                SettingsShortcutDemosSection()
            }
            .navigationTitle(mode.navigationTitle)
            .accessibilityIdentifier("settings.form")
        }
    }

    @ViewBuilder
    private func connectorRow(_ option: OAuthConnectorLoginOption) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(option.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).name")

                Spacer()

                Text(option.readiness.settingsStatusText)
                    .font(.caption)
                    .foregroundStyle(statusColor(for: option.readiness))
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).status")
            }

            Text(option.settingsDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.oauth.\(option.providerKey).detail")

            if option.requiresBackendTokenExchange {
                Text("需要後端 token exchange。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).backend-exchange")
            }

        if option.canStartAuthorization || option.readiness == .connected {
            HStack {
                if option.canStartAuthorization {
                    Button("Authorize") {
                        authorizeConnector(option)
                    }
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).authorize")
                }

                if option.readiness == .connected || option.readiness == .needsReauthorization {
                    Button("Disconnect", role: .destructive) {
                        disconnectConnector(option)
                    }
                    .accessibilityIdentifier("settings.oauth.\(option.providerKey).disconnect")
                }
            }
        } else if option.readiness == .needsClientConfiguration {
            Text("尚未設定 iOS OAuth client。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.oauth.\(option.providerKey).row")
    }

    @ViewBuilder
    private func oauthCallbackPreviewControls() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("OAuth Callback Preview")
                .font(.subheadline)
                .fontWeight(.medium)

            TextField("kairo://oauth/google/callback?code=...&state=...", text: $oauthCallbackURLText)
                .autocorrectionDisabled()
                .accessibilityIdentifier("settings.oauth.callback-url")

            Button("Preview Callback") {
                previewOAuthCallback()
            }
            .disabled(oauthCallbackURLText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("settings.oauth.preview-callback")

            if let oauthCallbackPreviewMessage {
                Text(oauthCallbackPreviewMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.oauth.callback-message")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func localModelPreferencePicker() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(KairoL10n.string("settings.models.routePreference"), selection: Binding(
                get: { localModelStatus.preference },
                set: { preference in
                    setLocalModelPreference(preference)
                }
            )) {
                ForEach(ProviderRoutePreference.settingsChoices, id: \.self) { preference in
                    Text(preference.settingsTitle)
                        .tag(preference)
                        .accessibilityIdentifier("settings.models.preference.\(preference.rawValue)")
                }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("settings.models.preference")

            Text(localModelStatus.preference.settingsDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func localModelCatalogControls() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(KairoL10n.string("settings.models.catalog"))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button(KairoL10n.string("settings.models.refreshCatalog")) {
                    refreshLocalModelCatalog()
                }
                .accessibilityIdentifier("settings.models.refresh-catalog")
            }

            Text(localModelCatalogSourceText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.models.catalog-source")
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func localModelRow(_ row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.displayName)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("settings.models.\(row.modelID).name")

                Spacer()

                Text(row.statusText)
                    .font(.caption2)
                    .foregroundStyle(localModelStatusColor(for: row.primaryAction))
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            Text(row.detailText)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let benchmarkSummaryText = row.benchmarkSummaryText {
                Text(benchmarkSummaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.models.\(row.modelID).benchmark")
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    localModelAction(for: row)

                    if row.benchmarkSummaryText != nil {
                        Button(KairoL10n.string("settings.models.runBenchmark")) {
                            runLocalModelBenchmark(row)
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.models.\(row.modelID).benchmark-run")
                    }
                }

                HStack(spacing: 10) {
                    Button(KairoL10n.string("settings.models.runReplyCheck")) {
                        runLocalModelReplyCheck(row)
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.models.\(row.modelID).reply-check")

                    if row.canDelete {
                        Button(KairoL10n.string("settings.models.delete"), role: .destructive) {
                            deleteLocalModel(row)
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.models.\(row.modelID).delete")
                    }
                }
            }

            if localModelStatusMessageModelID == row.modelID, let localModelStatusMessage {
                Text(localModelStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.models.benchmark-message")
            }

            if localModelDownloadProgress?.modelID == row.modelID, let progress = localModelDownloadProgress {
                LocalModelDownloadProgressInlineView(
                    progress: progress,
                    modelID: row.modelID
                ) {
                    cancelLocalModelDownload(row)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).row")
    }

    @ViewBuilder
    private func localModelAction(for row: LocalModelSettingsRow) -> some View {
        switch row.primaryAction {
        case .download, .retryDownload:
            Button(row.primaryAction.title) {
                downloadLocalModel(row)
            }
            .font(.caption2)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("settings.models.\(row.modelID).download")
        case .select:
            Button(row.primaryAction.title) {
                selectLocalModel(row)
            }
            .font(.caption2)
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("settings.models.\(row.modelID).select")
        case .selected:
            Label(row.primaryAction.title, systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.green)
                .accessibilityIdentifier("settings.models.\(row.modelID).select")
        case .unavailable:
            Text(row.primaryAction.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.models.\(row.modelID).unavailable")
        }
    }

    private func saveAPIKey() {
        Task {
            do {
                try await settingsService.saveAPIKey(apiKey)
                await MainActor.run {
                    apiKey = ""
                    statusMessage = KairoL10n.string("settings.openai.saved")
                }
                await reloadStatus()
            } catch {
                await MainActor.run {
                    statusMessage = KairoL10n.string("settings.openai.saveFailed", error.localizedDescription)
                }
            }
        }
    }

    private func deleteAPIKey() {
        Task {
            do {
                try await settingsService.deleteAPIKey()
                await MainActor.run {
                    statusMessage = KairoL10n.string("settings.openai.deleted")
                }
                await reloadStatus()
            } catch {
                await MainActor.run {
                    statusMessage = KairoL10n.string("settings.openai.deleteFailed", error.localizedDescription)
                }
            }
        }
    }

    private func dryRunAPIKey() {
        Task {
            do {
                let input = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : apiKey
                let result = try await settingsService.dryRunAPIKey(input)
                await MainActor.run {
                    statusMessage = KairoL10n.string("settings.openai.dryRunSuccess", result.redactedKey)
                }
            } catch {
                await MainActor.run {
                    statusMessage = KairoL10n.string("settings.openai.dryRunFailed", error.localizedDescription)
                }
            }
        }
    }

    private func clearAuditLog() {
        Task {
            guard let deletionAPI else {
                await MainActor.run {
                    privacyStatusMessage = "Audit log deletion is unavailable in this environment."
                }
                return
            }
            do {
                try await deletionAPI.clearAuditLog()
                await MainActor.run {
                    privacyStatusMessage = "Metadata-only audit log 已清除。"
                }
            } catch {
                await MainActor.run {
                    privacyStatusMessage = "Audit log 清除失敗：\(error.localizedDescription)"
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

    private func disconnectConnector(_ option: OAuthConnectorLoginOption) {
        Task {
            do {
                try await connectorLoginCenter().disconnect(providerKey: option.providerKey)
                await reloadConnectorOptions()
                await MainActor.run {
                    connectorStatusMessage = "\(option.displayName) 已登出並刪除儲存 token。"
                }
            } catch {
                await MainActor.run {
                    connectorStatusMessage = "刪除 OAuth token 失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func previewOAuthCallback() {
        Task {
            let trimmed = oauthCallbackURLText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed) else {
                await MainActor.run {
                    oauthCallbackPreviewMessage = "OAuth callback URL 格式不正確。"
                }
                return
            }

            do {
                let preview = try await connectorLoginCenter().previewCallback(url)
                await MainActor.run {
                    oauthCallbackPreviewMessage = preview.settingsStatusText
                }
                await reloadConnectorOptions()
            } catch {
                await MainActor.run {
                    oauthCallbackPreviewMessage = "OAuth callback preview 失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func setLocalModelPreference(_ preference: ProviderRoutePreference) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.setPreference(preference)
                await MainActor.run {
                    localModelStatus.preference = preference
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.preferenceSaved", preference.settingsTitle)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.preferenceFailed", error.localizedDescription)
                }
            }
        }
    }

    private func downloadLocalModel(_ row: LocalModelSettingsRow) {
        if let progress = localModelDownloadProgress {
            localModelStatusMessageModelID = progress.modelID
            localModelStatusMessage = KairoL10n.string("settings.models.message.downloadInProgress")
            return
        }

        guard localModelSettingsService != nil else {
            localModelStatusMessageModelID = row.modelID
            localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
            return
        }

        guard let localModelDownloader else {
            localModelStatusMessageModelID = row.modelID
            localModelStatusMessage = KairoL10n.string("settings.models.message.downloaderMissing")
            return
        }

        let task = Task {
            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.downloading", row.displayName)
                    localModelDownloadProgress = LocalModelDownloadProgressState(
                        modelID: row.modelID,
                        fractionCompleted: 0.05
                    )
                }
                _ = try await localModelDownloader.download(row.manifest) { fractionCompleted in
                    Task { @MainActor in
                        localModelDownloadProgress = LocalModelDownloadProgressState(
                            modelID: row.modelID,
                            fractionCompleted: fractionCompleted
                        )
                    }
                }
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloaded", row.displayName)) }
                await reloadLocalModelStatus()
            } catch LocalModelDownloadError.cancelled {
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloadCancelled", row.displayName)) }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run { finishLocalModelDownload(row, message: KairoL10n.string("settings.models.message.downloadFailed", error.localizedDescription)) }
                await reloadLocalModelStatus()
            }
        }
        localModelDownloadTask = task
    }

    private func cancelLocalModelDownload(_ row: LocalModelSettingsRow) {
        localModelDownloadTask?.cancel()
        localModelStatusMessageModelID = row.modelID
        localModelStatusMessage = KairoL10n.string("settings.models.message.cancellingDownload", row.displayName)
    }

    private func finishLocalModelDownload(_ row: LocalModelSettingsRow, message: String) {
        localModelStatusMessageModelID = row.modelID
        localModelDownloadProgress = nil
        localModelDownloadTask = nil
        localModelStatusMessage = message
    }

    private func selectLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.selectModel(
                    id: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.selected", row.displayName)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.selectFailed", error.localizedDescription)
                }
            }
        }
    }

    private func runLocalModelBenchmark(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelBenchmarkService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkServiceMissing")
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkRunning", row.displayName)
                }
                let result = try await localModelBenchmarkService.runBenchmark(
                    modelID: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkResult", row.displayName, result.summaryText)
                }
            } catch let error as LocalModelBenchmarkError {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    switch error {
                    case .modelNotInstalled:
                        localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkNeedsDownload", row.displayName)
                    case let .modelUnavailable(modelID):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkModelUnavailable", modelID)
                    case let .runtimeUnavailable(reason):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkRuntimeUnavailable", reason)
                    }
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.benchmarkFailed", error.localizedDescription)
                }
            }
        }
    }

    private func runLocalModelReplyCheck(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelReplyCheckService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckServiceMissing")
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckRunning", row.displayName)
                }
                let result = try await localModelReplyCheckService.runReplyCheck(
                    modelID: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckResult", row.displayName, result.summaryText)
                }
            } catch let error as LocalModelReplyCheckError {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    switch error {
                    case .modelNotInstalled:
                        localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckNeedsDownload", row.displayName)
                    case let .modelUnavailable(modelID):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckModelUnavailable", modelID)
                    case let .runtimeUnavailable(reason):
                        localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckRuntimeUnavailable", reason)
                    }
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.replyCheckFailed", error.localizedDescription)
                }
            }
        }
    }

    private func deleteLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.settingsServiceMissing")
                }
                return
            }

            do {
                try await localModelSettingsService.deleteModel(id: row.modelID)
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.deleted", row.displayName)
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = KairoL10n.string("settings.models.message.deleteFailed", error.localizedDescription)
                }
            }
        }
    }

    private func refreshLocalModelCatalog() {
        Task {
            guard let localModelCatalogService else {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.usingBuiltInCatalog")
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.refreshingCatalog")
                }
                let mergedCatalog = try await localModelCatalogService.fetchMergedCatalog(with: localModelCatalog)
                if let localModelSettingsService {
                    await localModelSettingsService.replaceCatalog(mergedCatalog)
                }
                if let localModelBenchmarkService {
                    await localModelBenchmarkService.replaceCatalog(mergedCatalog)
                }
                if let localModelReplyCheckService {
                    await localModelReplyCheckService.replaceCatalog(mergedCatalog)
                }
                await MainActor.run {
                    localModelCatalog = mergedCatalog
                    localModelStatusMessageModelID = nil
                    let count = mergedCatalog.availableModels(
                        minimumSafetyPolicyVersion: mergedCatalog.minimumSafetyPolicyVersion
                    ).count
                    localModelStatusMessage = KairoL10n.string("settings.models.message.catalogRefreshed", Int64(count))
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = KairoL10n.string("settings.models.message.catalogRefreshFailed", error.localizedDescription)
                }
            }
        }
    }

    private func reloadAllStatus() async {
        await reloadStatus()
        await reloadConnectorOptions()
        await reloadLocalModelStatus()
    }

    private func reloadStatus() async {
        do {
            let status = try await settingsService.status()
            await MainActor.run {
                hasAPIKey = status.hasAPIKey
            }
        } catch {
            await MainActor.run {
                statusMessage = KairoL10n.string("settings.openai.loadFailed", error.localizedDescription)
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

    private func reloadLocalModelStatus() async {
        let status: LocalModelSettingsStatus
        if let localModelSettingsService {
            if localModelDownloadTask == nil {
                do {
                    let cleanedModelIDs = try await localModelSettingsService.cleanupStaleDownloadingRecords()
                    if !cleanedModelIDs.isEmpty {
                        await MainActor.run {
                            localModelStatusMessageModelID = nil
                            localModelStatusMessage = KairoL10n.string("settings.models.message.cleanedStaleDownload")
                        }
                    }
                } catch {
                    await MainActor.run {
                        localModelStatusMessageModelID = nil
                        localModelStatusMessage = KairoL10n.string("settings.models.message.cleanStaleDownloadFailed", error.localizedDescription)
                    }
                }
            }
            status = await localModelSettingsService.status(
                minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
            )
        } else {
            status = Self.catalogOnlyLocalModelStatus(catalog: localModelCatalog)
        }

        await MainActor.run {
            localModelStatus = status
        }
    }

    private func connectorLoginCenter() -> OAuthConnectorLoginCenter {
        OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: credentialStore,
            clientConfigurations: oauthClientConfigurations,
            callbackStore: oauthCallbackStore
        )
    }

    private static func catalogOnlyLocalModelStatus(catalog: LocalModelCatalog) -> LocalModelSettingsStatus {
        LocalModelSettingsStatus(
            selectedModelID: nil,
            selectedModel: nil,
            installedRecord: nil,
            preference: .automatic,
            availableModels: catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion),
            installedModels: []
        )
    }

    private var localModelCatalogSourceText: String {
        localModelCatalog.sourceRepository?.absoluteString ?? KairoL10n.string("settings.models.catalogBuiltIn")
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

    private func localModelStatusColor(for action: LocalModelSettingsPrimaryAction) -> Color {
        switch action {
        case .selected:
            return .green
        case .select:
            return .blue
        case .download, .retryDownload:
            return .orange
        case .unavailable:
            return .secondary
        }
    }
}
#endif
