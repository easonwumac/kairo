#if canImport(SwiftUI)
import SwiftUI

public enum SettingsViewMode: String, Sendable {
    case all
    case modelsOnly

    var navigationTitle: String {
        switch self {
        case .all:
            return "Settings"
        case .modelsOnly:
            return "Models"
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
    @State private var localModelStatusMessage: String?
    @State private var localModelStatusMessageModelID: String?

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
        localModelReplyCheckService: LocalModelReplyCheckService? = nil
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
        localModelReplyCheckService: LocalModelReplyCheckService? = nil
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
        self._localModelCatalog = State(initialValue: localModelCatalog)
        self._localModelStatus = State(initialValue: Self.catalogOnlyLocalModelStatus(catalog: localModelCatalog))
    }

    public var body: some View {
        Group {
            if mode == .modelsOnly {
                modelsOnlyContent
            } else {
                settingsFormContent
            }
        }
        .task { await reloadAllStatus() }
    }

    private var settingsFormContent: some View {
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

                    oauthCallbackPreviewControls()
                }
                .accessibilityIdentifier("settings.oauth.connectors")

                Section("Local Models") {
                    localModelPreferencePicker()
                    localModelCatalogControls()

                    if localModelStatus.settingsRows.isEmpty {
                        Text("尚未載入 local model catalog。")
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
            .navigationTitle(mode.navigationTitle)
            .accessibilityIdentifier("settings.form")
        }
    }

    private var modelsOnlyContent: some View {
        LocalModelsCompactView(
            localModelStatus: localModelStatus,
            localModelStatusMessage: localModelStatusMessage,
            localModelStatusMessageModelID: localModelStatusMessageModelID,
            localModelCatalogSourceText: localModelCatalogSourceText,
            localModelStatusColor: { localModelStatusColor(for: $0) },
            setLocalModelPreference: { setLocalModelPreference($0) },
            refreshLocalModelCatalog: refreshLocalModelCatalog,
            downloadLocalModel: { downloadLocalModel($0) },
            selectLocalModel: { selectLocalModel($0) },
            runLocalModelBenchmark: { runLocalModelBenchmark($0) },
            runLocalModelReplyCheck: { runLocalModelReplyCheck($0) },
            deleteLocalModel: { deleteLocalModel($0) }
        )
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
            Picker("Route Preference", selection: Binding(
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
                Text("Catalog")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button("Refresh Catalog") {
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
                        Button("Run Benchmark") {
                            runLocalModelBenchmark(row)
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityIdentifier("settings.models.\(row.modelID).benchmark-run")
                    }
                }

                HStack(spacing: 10) {
                    Button("Run Reply Check") {
                        runLocalModelReplyCheck(row)
                    }
                    .font(.caption2)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier("settings.models.\(row.modelID).reply-check")

                    if row.canDelete {
                        Button("Delete", role: .destructive) {
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
                    localModelStatusMessage = "尚未設定 local model settings service。"
                }
                return
            }

            do {
                try await localModelSettingsService.setPreference(preference)
                await MainActor.run {
                    localModelStatus.preference = preference
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = "\(preference.settingsTitle) routing 已儲存。"
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = "路由偏好儲存失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func downloadLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard localModelSettingsService != nil else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "尚未設定 local model settings service。"
                }
                return
            }

            guard let localModelDownloader else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "尚未設定 local model downloader。"
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "正在下載 \(row.displayName)。"
                }
                _ = try await localModelDownloader.download(row.manifest, progress: nil)
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "\(row.displayName) 已下載，可選用。"
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "下載失敗：\(error.localizedDescription)"
                }
                await reloadLocalModelStatus()
            }
        }
    }

    private func selectLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "尚未設定 local model settings service。"
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
                    localModelStatusMessage = "\(row.displayName) 已選用。"
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "選用失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func runLocalModelBenchmark(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelBenchmarkService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "尚未設定 local model benchmark service。"
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "正在 benchmark \(row.displayName)。"
                }
                let result = try await localModelBenchmarkService.runBenchmark(
                    modelID: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "\(row.displayName) benchmark：\(result.summaryText)。"
                }
            } catch let error as LocalModelBenchmarkError {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    switch error {
                    case .modelNotInstalled:
                        localModelStatusMessage = "請先下載 \(row.displayName) 後再跑 benchmark。"
                    case let .modelUnavailable(modelID):
                        localModelStatusMessage = "benchmark 模型不可用：\(modelID)。"
                    case let .runtimeUnavailable(reason):
                        localModelStatusMessage = "本機 benchmark runtime 尚未接上：\(reason)"
                    }
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "benchmark 失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func runLocalModelReplyCheck(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelReplyCheckService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "尚未設定 local model reply check service。"
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "正在產生 \(row.displayName) local reply。"
                }
                let result = try await localModelReplyCheckService.runReplyCheck(
                    modelID: row.modelID,
                    minimumSafetyPolicyVersion: localModelCatalog.minimumSafetyPolicyVersion
                )
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "\(row.displayName) reply check：\(result.summaryText)。"
                }
            } catch let error as LocalModelReplyCheckError {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    switch error {
                    case .modelNotInstalled:
                        localModelStatusMessage = "請先下載 \(row.displayName) 後再跑 reply check。"
                    case let .modelUnavailable(modelID):
                        localModelStatusMessage = "reply check 模型不可用：\(modelID)。"
                    case let .runtimeUnavailable(reason):
                        localModelStatusMessage = "本機 reply runtime 尚未接上：\(reason)"
                    }
                }
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "reply check 失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteLocalModel(_ row: LocalModelSettingsRow) {
        Task {
            guard let localModelSettingsService else {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "尚未設定 local model settings service。"
                }
                return
            }

            do {
                try await localModelSettingsService.deleteModel(id: row.modelID)
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "\(row.displayName) 已刪除。"
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = row.modelID
                    localModelStatusMessage = "刪除模型失敗：\(error.localizedDescription)"
                }
            }
        }
    }

    private func refreshLocalModelCatalog() {
        Task {
            guard let localModelCatalogService else {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = "使用內建 local model catalog。"
                }
                return
            }

            do {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = "正在刷新 model catalog。"
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
                    localModelStatusMessage = "已刷新 model catalog：\(count) 個可用模型。"
                }
                await reloadLocalModelStatus()
            } catch {
                await MainActor.run {
                    localModelStatusMessageModelID = nil
                    localModelStatusMessage = "刷新 model catalog 失敗：\(error.localizedDescription)"
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

    private func reloadLocalModelStatus() async {
        let status: LocalModelSettingsStatus
        if let localModelSettingsService {
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
        localModelCatalog.sourceRepository?.absoluteString ?? "Built-in Kairo model catalog"
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
