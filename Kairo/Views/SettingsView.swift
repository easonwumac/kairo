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
    @AppStorage(KairoAppearancePreference.storageKey) private var appearancePreferenceRawValue = KairoAppearancePreference.system.rawValue

    @State private var apiKey: String = ""
    @State private var hasAPIKey: Bool = false
    @State private var statusMessage: String?
    @State private var connectorOptions: [OAuthConnectorLoginOption] = []
    @State private var connectorStatusMessage: String?
    @State var localModelCatalog: LocalModelCatalog
    @State var localModelStatus: LocalModelSettingsStatus
    @State var localModelDownloadProgress: LocalModelDownloadProgressState?
    @State var localModelDownloadTask: Task<Void, Never>?
    @State var localModelStatusMessage: String?
    @State var localModelStatusMessageModelID: String?
    @State private var privacyStatusMessage: String?
    @State private var showConnectionSetup = true
    @State private var showConnectionDetails = false
    @State private var showAPIKeyEditor = false
    @State private var expandedOAuthConnectorDetails: Set<String> = []

    private let openAIKeyCoordinator: SettingsOpenAIKeyCoordinator
    private let mode: SettingsViewMode
    private let credentialStore: any CredentialStore
    private let oauthCoordinator: SettingsOAuthConnectorCoordinator
    private let privacyCoordinator: SettingsPrivacyCoordinator
    let localModelCatalogService: LocalModelCatalogService?
    let localModelSettingsService: LocalModelSettingsService?
    let localModelDownloader: (any LocalModelDownloader)?
    let localModelBenchmarkService: LocalModelBenchmarkService?
    let localModelReplyCheckService: LocalModelReplyCheckService?

    public init(
        dependencies: SettingsFeatureDependencies,
        mode: SettingsViewMode = .all,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) {
        self.init(
            settingsService: dependencies.settingsService,
            mode: mode,
            credentialStore: dependencies.credentialStore,
            oauthConnectorRegistry: dependencies.oauthConnectorRegistry,
            oauthClientConfigurations: dependencies.oauthClientConfigurations,
            oauthCallbackStore: dependencies.oauthCallbackStore,
            oauthLoginService: dependencies.oauthLoginService,
            oauthLoginServiceFactory: dependencies.oauthLoginServiceFactory,
            oauthWebAuthenticationRunner: dependencies.oauthWebAuthenticationRunner ?? Self.defaultOAuthWebAuthenticationRunner(),
            openAIKeyCoordinator: dependencies.openAIKeyCoordinator,
            oauthCoordinator: dependencies.oauthCoordinator,
            privacyCoordinator: dependencies.privacyCoordinator,
            localModelCatalog: dependencies.localModelCatalog,
            localModelCatalogService: dependencies.localModelCatalogService,
            localModelSettingsService: dependencies.localModelSettingsService,
            localModelDownloader: dependencies.localModelDownloader,
            localModelBenchmarkService: dependencies.localModelBenchmarkService,
            localModelReplyCheckService: dependencies.localModelReplyCheckService,
            deletionAPI: deletionAPI ?? dependencies.deletionAPI
        )
    }

    public init(
        mode: SettingsViewMode = .all,
        credentialStore: (any CredentialStore)? = nil,
        oauthConnectorRegistry: (any AppIntegrationRegistryProviding)? = nil,
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        oauthLoginService: (any OAuthConnectorLoginServicing)? = nil,
        oauthLoginServiceFactory: any OAuthConnectorLoginServiceMaking = OAuthConnectorLoginServiceFactory(),
        oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)? = Self.defaultOAuthWebAuthenticationRunner(),
        openAIKeyCoordinator: SettingsOpenAIKeyCoordinator? = nil,
        oauthCoordinator: SettingsOAuthConnectorCoordinator? = nil,
        privacyCoordinator: SettingsPrivacyCoordinator? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) {
        self.init(
            dependencies: SettingsFeatureDependencyFactory().makeDependencies(
                credentialStore: credentialStore,
                oauthConnectorRegistry: oauthConnectorRegistry,
                oauthClientConfigurations: oauthClientConfigurations,
                oauthCallbackStore: oauthCallbackStore,
                oauthLoginService: oauthLoginService,
                oauthLoginServiceFactory: oauthLoginServiceFactory,
                oauthWebAuthenticationRunner: oauthWebAuthenticationRunner,
                openAIKeyCoordinator: openAIKeyCoordinator,
                oauthCoordinator: oauthCoordinator,
                privacyCoordinator: privacyCoordinator,
                localModelCatalog: localModelCatalog,
                localModelCatalogService: localModelCatalogService,
                localModelSettingsService: localModelSettingsService,
                localModelDownloader: localModelDownloader,
                localModelBenchmarkService: localModelBenchmarkService,
                localModelReplyCheckService: localModelReplyCheckService,
                deletionAPI: deletionAPI
            ),
            mode: mode,
            deletionAPI: deletionAPI
        )
    }

    public init(
        settingsService: OpenAISettingsService,
        mode: SettingsViewMode = .all,
        credentialStore: any CredentialStore,
        oauthConnectorRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry.appIntegrationHarnessRegistry(),
        oauthClientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        oauthCallbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        oauthLoginService: (any OAuthConnectorLoginServicing)? = nil,
        oauthLoginServiceFactory: any OAuthConnectorLoginServiceMaking = OAuthConnectorLoginServiceFactory(),
        oauthWebAuthenticationRunner: (any OAuthWebAuthenticationRunner)? = Self.defaultOAuthWebAuthenticationRunner(),
        openAIKeyCoordinator: SettingsOpenAIKeyCoordinator? = nil,
        oauthCoordinator: SettingsOAuthConnectorCoordinator? = nil,
        privacyCoordinator: SettingsPrivacyCoordinator? = nil,
        localModelCatalog: LocalModelCatalog = .kairoDefault,
        localModelCatalogService: LocalModelCatalogService? = nil,
        localModelSettingsService: LocalModelSettingsService? = nil,
        localModelDownloader: (any LocalModelDownloader)? = nil,
        localModelBenchmarkService: LocalModelBenchmarkService? = nil,
        localModelReplyCheckService: LocalModelReplyCheckService? = nil,
        deletionAPI: (any KairoDeletionAPI)? = nil
    ) {
        self.openAIKeyCoordinator = openAIKeyCoordinator ?? SettingsOpenAIKeyCoordinator(settingsService: settingsService)
        self.mode = mode
        self.credentialStore = credentialStore
        let oauthLoginService = oauthLoginServiceFactory.makeLoginService(
            override: oauthLoginService,
            credentialStore: credentialStore,
            oauthConnectorRegistry: oauthConnectorRegistry,
            oauthClientConfigurations: oauthClientConfigurations,
            oauthCallbackStore: oauthCallbackStore
        )
        self.oauthCoordinator = oauthCoordinator ?? SettingsOAuthConnectorCoordinator(
            loginService: oauthLoginService,
            webAuthenticationRunner: oauthWebAuthenticationRunner
        )
        self.localModelCatalogService = localModelCatalogService
        self.localModelSettingsService = localModelSettingsService
        self.localModelDownloader = localModelDownloader
        self.localModelBenchmarkService = localModelBenchmarkService
        self.localModelReplyCheckService = localModelReplyCheckService
        self.privacyCoordinator = privacyCoordinator ?? SettingsPrivacyCoordinator(deletionAPI: deletionAPI)
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
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        SettingsAnswerOverviewCard(
                            hasAPIKey: hasAPIKey,
                            routePreference: localModelStatus.preference,
                            connectedConnectorCount: connectedConnectorCount,
                            localModelInstalled: localModelStatus.localModelInstalled
                        )
                        appearanceSettingsSection
                        connectionSetupSection

                        if let connectorStatusMessage {
                            KairoGroupedSurface {
                                Label(connectorStatusMessage, systemImage: "info.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .accessibilityIdentifier("settings.status.message")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeTopPadding)
                    .padding(.bottom, 32)
                }
                .navigationTitle(mode.navigationTitle)
                .background(KairoDesign.background.ignoresSafeArea())
                .accessibilityIdentifier("settings.form")
            }
        }
    }

    private var connectionSetupSection: some View {
        SettingsConnectionSetupSection(
            showsConnectionSetup: $showConnectionSetup,
            showsConnectionDetails: $showConnectionDetails,
            hasAPIKey: hasAPIKey,
            connectedConnectorCount: connectedConnectorCount
        ) {
            accountSettingsSection
            oauthConnectorsSection
            privacySettingsSection
        }
    }

    private var appearanceSettingsSection: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 10) {
                Label(KairoL10n.string("settings.appearance.section"), systemImage: "circle.lefthalf.filled")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

                Picker(KairoL10n.string("settings.appearance.picker"), selection: Binding(
                    get: { KairoAppearancePreference(rawValue: appearancePreferenceRawValue) ?? .system },
                    set: { appearancePreferenceRawValue = $0.rawValue }
                )) {
                    ForEach(KairoAppearancePreference.allCases) { preference in
                        Text(preference.title)
                            .tag(preference)
                            .accessibilityIdentifier("settings.appearance.\(preference.rawValue)")
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("settings.appearance.picker")

                Text(KairoL10n.string("settings.appearance.detail"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("settings.appearance.section")
    }

    private var accountSettingsSection: some View {
        SettingsOpenAIAccountSection(
            apiKey: $apiKey,
            showAPIKeyEditor: $showAPIKeyEditor,
            hasAPIKey: hasAPIKey,
            statusMessage: statusMessage,
            saveAPIKey: saveAPIKey,
            dryRunAPIKey: dryRunAPIKey,
            deleteAPIKey: deleteAPIKey
        )
    }

    private var oauthConnectorsSection: some View {
        SettingsOAuthConnectorsSection(
            connectorOptions: connectorOptions,
            expandedConnectorDetails: $expandedOAuthConnectorDetails,
            authorizeConnector: authorizeConnector,
            disconnectConnector: disconnectConnector
        )
    }

    private var privacySettingsSection: some View {
        SettingsPrivacySection(
            statusMessage: privacyStatusMessage,
            clearAuditLog: clearAuditLog
        )
    }

    private var connectedConnectorCount: Int {
        connectorOptions.filter { $0.readiness == .connected }.count
    }

    private var modelsOnlyContent: some View {
        GeometryReader { proxy in
            LocalModelsCompactView(
                topPadding: max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeTopPadding,
                localModelStatus: localModelStatus,
                localModelDownloadProgress: localModelDownloadProgress,
                localModelStatusMessage: localModelStatusMessage,
                localModelStatusMessageModelID: localModelStatusMessageModelID,
                localModelCatalogSourceText: localModelCatalogSourceText,
                localModelStatusColor: { localModelStatusColor(for: $0) },
                setLocalModelPreference: { setLocalModelPreference($0) },
                setResponseLanguage: { setResponseLanguage($0) },
                refreshLocalModelCatalog: refreshLocalModelCatalog,
                downloadLocalModel: { downloadLocalModel($0) },
                cancelLocalModelDownload: { cancelLocalModelDownload($0) },
                selectLocalModel: { selectLocalModel($0) },
                runLocalModelBenchmark: { runLocalModelBenchmark($0) },
                runLocalModelReplyCheck: { runLocalModelReplyCheck($0) },
                deleteLocalModel: { deleteLocalModel($0) }
            )
        }
    }

    private var shortcutDemosOnlyContent: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SettingsShortcutDemosSection()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeTopPadding)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
                .background(KairoDesign.background.ignoresSafeArea())
                .navigationTitle(mode.navigationTitle)
                .accessibilityIdentifier("settings.form")
            }
        }
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
                try await openAIKeyCoordinator.saveAPIKey(apiKey)
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
                try await openAIKeyCoordinator.deleteAPIKey()
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
                let result = try await openAIKeyCoordinator.dryRunAPIKey(input)
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
        privacyStatusMessage = KairoL10n.string("settings.privacy.auditLogClearing")
        Task {
            do {
                try await privacyCoordinator.clearAuditLog()
                await MainActor.run {
                    privacyStatusMessage = KairoL10n.string("settings.privacy.auditLogCleared")
                }
            } catch SettingsPrivacyCoordinatorError.unavailable {
                await MainActor.run {
                    privacyStatusMessage = KairoL10n.string("settings.privacy.auditLogUnavailable")
                }
            } catch {
                await MainActor.run {
                    privacyStatusMessage = KairoL10n.string("settings.privacy.auditLogClearFailed", error.localizedDescription)
                }
            }
        }
    }

    private func authorizeConnector(_ option: OAuthConnectorLoginOption) {
        Task {
            do {
                await MainActor.run {
                    connectorStatusMessage = KairoL10n.string("settings.oauth.openingAuthorization", option.displayName)
                }

                let outcome = try await oauthCoordinator.authorize(option)
                switch outcome {
                case .completed:
                    await reloadConnectorOptions()
                    await MainActor.run {
                        connectorStatusMessage = KairoL10n.string("settings.oauth.loginCompleted", option.displayName)
                    }
                case .fallback(let session):
                    await MainActor.run {
                        openURL(session.authorizationURL)
                    }
                }
            } catch {
                await MainActor.run {
                    connectorStatusMessage = KairoL10n.string("settings.oauth.authorizationFailed", error.localizedDescription)
                }
            }
        }
    }

    private func disconnectConnector(_ option: OAuthConnectorLoginOption) {
        Task {
            do {
                try await oauthCoordinator.disconnect(providerKey: option.providerKey)
                await reloadConnectorOptions()
                await MainActor.run {
                    connectorStatusMessage = KairoL10n.string("settings.oauth.disconnected", option.displayName)
                }
            } catch {
                await MainActor.run {
                    connectorStatusMessage = KairoL10n.string("settings.oauth.disconnectFailed", error.localizedDescription)
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
            let status = try await openAIKeyCoordinator.status()
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
            let options = try await oauthCoordinator.loginOptions()
            await MainActor.run {
                connectorOptions = options
            }
        } catch {
            await MainActor.run {
                connectorStatusMessage = KairoL10n.string("settings.oauth.loadFailed", error.localizedDescription)
            }
        }
    }

    public static func defaultOAuthWebAuthenticationRunner() -> (any OAuthWebAuthenticationRunner)? {
        SettingsOAuthWebAuthenticationRunnerFactory().makeDefaultRunner()
    }

}
#endif
