#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
    @State private var pageStack: [ModelSettingsPage] = []

    var topPadding: CGFloat = 16
    @Binding var apiKey: String
    @Binding var showAPIKeyEditor: Bool
    @Binding var expandedOAuthConnectorDetails: Set<String>
    let hasOpenAIAPIKey: Bool
    let isChatGPTOAuthConnected: Bool
    let isChatGPTOAuthAvailable: Bool
    let openAIStatusMessage: String?
    let connectorOptions: [OAuthConnectorLoginOption]
    let localModelStatus: LocalModelSettingsStatus
    let localModelDownloadProgress: LocalModelDownloadProgressState?
    let localModelStatusMessage: String?
    let localModelStatusMessageModelID: String?
    let localModelCatalogSourceText: String
    let localModelBenchmarkRunInfo: LocalModelBenchmarkRunInfo?
    @Binding var rootChromeBackRequestID: Int
    let usesRootChromeNavigation: Bool
    let localModelStatusColor: (LocalModelSettingsPrimaryAction) -> Color
    let saveAPIKey: () -> Void
    let dryRunAPIKey: () -> Void
    let deleteAPIKey: () -> Void
    let authorizeConnector: (OAuthConnectorLoginOption) -> Void
    let disconnectConnector: (OAuthConnectorLoginOption) -> Void
    let setLocalModelPreference: (ProviderRoutePreference) -> Void
    let setResponseLanguage: (ChatResponseLanguagePreference) -> Void
    let setLocalModelRuntimeParameters: (LocalModelRuntimeParameters, LocalModelSettingsRow) -> Void
    let refreshLocalModelCatalog: () -> Void
    let downloadLocalModel: (LocalModelSettingsRow) -> Void
    let cancelLocalModelDownload: (LocalModelSettingsRow) -> Void
    let selectLocalModel: (LocalModelSettingsRow) -> Void
    let runLocalModelBenchmark: (LocalModelSettingsRow, Int) -> Void
    let deleteLocalModel: (LocalModelSettingsRow) -> Void

    var body: some View {
        ScrollView {
            Group {
                if let activePage {
                    pageView(for: activePage)
                } else {
                    modelSettingsHome
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, topPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.visible)
        .background(KairoDesign.background.ignoresSafeArea())
        .preference(key: RootChromePreferenceKey.self, value: rootChromeContext)
        .onChange(of: rootChromeBackRequestID) { _, _ in
            popPage()
        }
        .accessibilityIdentifier("settings.models.screen")
    }

    private var activePage: ModelSettingsPage? {
        pageStack.last
    }

    private func pushPage(_ page: ModelSettingsPage) {
        pageStack.append(page)
    }

    private func popPage() {
        guard !pageStack.isEmpty else { return }
        withAnimation(.snappy(duration: 0.2)) {
            _ = pageStack.popLast()
        }
    }

    private var rootChromeContext: RootChromeContext {
        guard usesRootChromeNavigation, let activePage else {
            return .standard
        }
        return RootChromeContext(
            leadingAction: .back,
            title: chromeTitle(for: activePage)
        )
    }

    private func chromeTitle(for page: ModelSettingsPage) -> String {
        switch page {
        case .addCloud, .addLocal:
            return page.title
        case let .cloudDetail(providerID):
            return cloudProviderRows.first { $0.id == providerID }?.title ?? page.title
        case let .localDetail(modelID):
            return localModelStatus.settingsRows.first { $0.modelID == modelID }?.displayName ?? page.title
        }
    }

    private var modelSettingsHome: some View {
        VStack(alignment: .leading, spacing: 14) {
            answerRouteCard

            cloudModelsSection

            modelStarterSection
        }
    }

    private var modelStarterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(KairoL10n.string("settings.models.starter.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
            }
            .padding(.horizontal, 2)
            .accessibilityIdentifier("settings.models.starter")

            if configuredLocalModelRows.isEmpty {
                Text(KairoL10n.string("settings.models.local.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(configuredLocalModelRows) { row in
                compactLocalModelRow(row)
            }

            modelAddButton(
                title: KairoL10n.string("settings.models.local.add"),
                accessibilityIdentifier: "settings.models.local.add"
            ) {
                withAnimation(.snappy(duration: 0.2)) {
                    pushPage(.addLocal)
                }
            }

            if shouldShowSectionLocalModelMessage, let localModelStatusMessage {
                Text(localModelStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                    .accessibilityIdentifier("settings.models.benchmark-message")
            }
        }
    }

    private var answerRouteCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KairoL10n.string("settings.models.section"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)

                    Text(KairoL10n.string("settings.models.defaultModel.detail"))
                        .font(compactModelMetadataFont)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                responseLanguageInline

                Divider()

                selectedModelInline
            }
            .accessibilityIdentifier("settings.models.answer-route")
        }
        .accessibilityIdentifier("settings.models.local")
    }

    private var cloudModelsSection: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(KairoL10n.string("settings.models.cloud.section"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)

                    Text(KairoL10n.string("settings.models.cloud.detail"))
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if configuredCloudProviderRows.isEmpty {
                    Text(KairoL10n.string("settings.models.cloud.empty"))
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.models.cloud.empty")
                }

                ForEach(configuredCloudProviderRows) { row in
                    cloudProviderRow(row)
                    if row.id != configuredCloudProviderRows.last?.id {
                        Divider()
                    }
                }

                modelAddButton(
                    title: KairoL10n.string("settings.models.cloud.add"),
                accessibilityIdentifier: "settings.models.cloud.add"
            ) {
                withAnimation(.snappy(duration: 0.2)) {
                    pushPage(.addCloud)
                }
            }
            }
        }
        .accessibilityIdentifier("settings.models.cloud")
    }

    @ViewBuilder
    private func pageView(for page: ModelSettingsPage) -> some View {
        switch page {
        case .addCloud, .addLocal:
            addPage(for: page)
        case .cloudDetail(let providerID):
            if let row = cloudProviderRows.first(where: { $0.id == providerID }) {
                cloudDetailPage(for: row)
            } else {
                unavailablePage
            }
        case .localDetail(let modelID):
            if let row = localModelStatus.settingsRows.first(where: { $0.modelID == modelID }) {
                localDetailPage(for: row)
            } else {
                unavailablePage
            }
        }
    }

    private func addPage(for page: ModelSettingsPage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }

            KairoFocusCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text(page.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)

                    Text(page.detail)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    switch page {
                    case .addCloud:
                        cloudAddList
                    case .addLocal:
                        localAddList
                    case .cloudDetail, .localDetail:
                        EmptyView()
                    }
                }
            }
            .accessibilityIdentifier(page.accessibilityIdentifier)
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var pageBackButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                popPage()
            }
        } label: {
            Label(KairoL10n.string("settings.models.add.back"), systemImage: "chevron.left")
                .font(compactButtonLabelFont)
                .foregroundStyle(KairoDesign.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(KairoDesign.blue.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.models.add.back")
    }

    private var unavailablePage: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }
            KairoFocusCard {
                Text(KairoL10n.string("settings.models.detail.unavailable"))
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var routePreferenceInline: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "switch.2")
                .font(.headline)
                .foregroundStyle(KairoDesign.blue)
                .frame(width: 30, height: 30)
                .background(KairoDesign.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.models.routePreference"))
                    .font(compactModelMetadataFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(localModelStatus.preference.settingsDetailText)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            compactRoutePreferenceMenu
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.route-card")
    }

    private var responseLanguageInline: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "globe")
                .font(.headline)
                .foregroundStyle(KairoDesign.blue)
                .frame(width: 30, height: 30)
                .background(KairoDesign.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.responseLanguage.title"))
                    .font(compactModelMetadataFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(localModelStatus.responseLanguage.settingsDetailText)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            compactResponseLanguageMenu
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.responseLanguage.card")
    }

    private var selectedModelInline: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: selectedModelSummaryIconName)
                .font(.headline)
                .foregroundStyle(selectedModelSummaryIconColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(KairoL10n.string("settings.models.compact.selectedModel"))
                    .font(compactModelMetadataFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(selectedModelSummaryText)
                    .font(compactModelNameFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            defaultModelMenu
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(selectedModelSummaryText)
        .accessibilityIdentifier("settings.models.selected-summary")
    }

    private var defaultModelMenu: some View {
        Menu {
            Button {
                setLocalModelPreference(.preferCloud)
            } label: {
                Text(KairoL10n.string("settings.models.default.cloud.openai"))
            }
            .disabled(!hasOpenAIAPIKey)
            .accessibilityIdentifier("settings.models.default.openai")

            ForEach(selectableLocalModelRows) { row in
                Button {
                    selectLocalModel(row)
                } label: {
                    Text(KairoL10n.string("settings.models.default.local", row.displayName))
                }
                .accessibilityIdentifier("settings.models.default.\(row.modelID)")
            }
        } label: {
            HStack(spacing: 4) {
                Text(KairoL10n.string("settings.models.default.change"))
                    .font(compactButtonLabelFont)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(KairoDesign.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(KairoDesign.blue.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KairoL10n.string("settings.models.default.change"))
        .accessibilityIdentifier("settings.models.default.menu")
    }

    private var selectedModelSummaryText: String {
        if localModelStatus.localModelInstalled, let selectedModel = localModelStatus.selectedModel {
            return KairoL10n.string("settings.models.compact.activeForLocalTasks", selectedModel.displayName)
        }
        if let downloadedModel {
            return KairoL10n.string("settings.models.compact.downloadedSelectForRouting", downloadedModel.displayName)
        }
        return KairoL10n.string("settings.models.compact.noDownloadedModel")
    }

    private var cloudProviderRows: [CloudModelProviderRow] {
        [
            CloudModelProviderRow(
                id: "openai-api",
                title: "OpenAI",
                method: KairoL10n.string("settings.models.cloud.method.apiKey"),
                status: hasOpenAIAPIKey
                    ? KairoL10n.string("settings.models.cloud.status.configured")
                    : KairoL10n.string("settings.models.cloud.status.needsApiKey"),
                isConfigured: hasOpenAIAPIKey,
                setupKind: .openAIAPIKey
            ),
            CloudModelProviderRow(
                id: "openai-codex-oauth",
                title: "OpenAI Codex",
                method: KairoL10n.string("settings.models.cloud.method.oauth"),
                status: isChatGPTOAuthConnected
                    ? KairoL10n.string("settings.models.cloud.status.configured")
                    : isChatGPTOAuthAvailable
                        ? KairoL10n.string("settings.models.cloud.status.oauthSetup")
                        : KairoL10n.string("settings.models.cloud.status.metadataOnly"),
                isConfigured: isChatGPTOAuthConnected,
                setupKind: .chatGPTOAuth
            )
        ]
    }

    private var configuredCloudProviderRows: [CloudModelProviderRow] {
        cloudProviderRows.filter(\.isConfigured)
    }

    private var addableCloudProviderRows: [CloudModelProviderRow] {
        cloudProviderRows.filter { !$0.isConfigured && $0.canConfigure }
    }

    @ViewBuilder
    private var cloudAddList: some View {
        if addableCloudProviderRows.isEmpty {
            Text(KairoL10n.string("settings.models.cloud.add.empty"))
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.models.cloud.add.empty")
        } else {
            ForEach(addableCloudProviderRows) { row in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        pushPage(.cloudDetail(row.id))
                    }
                    prepareSetup(for: row)
                } label: {
                    addListRow(
                        title: row.title,
                        subtitle: row.method,
                        status: row.status,
                        systemImage: row.setupKind.systemImage
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.models.cloud.add.\(row.id)")
            }
        }
    }

    private func cloudProviderRow(_ row: CloudModelProviderRow) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                pushPage(.cloudDetail(row.id))
            }
        } label: {
            providerSummaryRow(row)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.models.cloud.\(row.id)")
    }

    private func providerSummaryRow(_ row: CloudModelProviderRow) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: row.isConfigured ? "checkmark.seal.fill" : "cloud")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.isConfigured ? .green : KairoDesign.blue)
                .frame(width: 30, height: 30)
                .background((row.isConfigured ? Color.green : KairoDesign.blue).opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .font(compactModelNameFont)
                    .foregroundStyle(KairoDesign.ink)

                Text(row.method)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(row.status)
                .font(compactModelStatusFont)
                .foregroundStyle(row.isConfigured ? .green : .secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func prepareSetup(for row: CloudModelProviderRow) {
        switch row.setupKind {
        case .openAIAPIKey:
            showAPIKeyEditor = true
        case .chatGPTOAuth:
            expandedOAuthConnectorDetails.insert("openai-codex")
        }
    }

    private func cloudDetailPage(for row: CloudModelProviderRow) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }

            KairoFocusCard {
                VStack(alignment: .leading, spacing: 12) {
                    providerSummaryRow(row)

                    Divider()

                    cloudProviderSetup(for: row.id)

                    if row.isConfigured {
                        compactActionButton(
                            KairoL10n.string("settings.models.cloud.remove"),
                            systemImage: "trash",
                            accessibilityIdentifier: "settings.models.cloud.\(row.id).remove",
                            tint: .red,
                            role: .destructive
                        ) {
                            removeCloudProvider(row)
                            withAnimation(.snappy(duration: 0.2)) {
                                popPage()
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.models.cloud.\(row.id).detail")
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    @ViewBuilder
    private func cloudProviderSetup(for providerID: String) -> some View {
        switch providerID {
        case "openai-api":
            SettingsOpenAIAccountSection(
                apiKey: $apiKey,
                showAPIKeyEditor: $showAPIKeyEditor,
                hasAPIKey: hasOpenAIAPIKey,
                statusMessage: openAIStatusMessage,
                saveAPIKey: saveAPIKey,
                dryRunAPIKey: dryRunAPIKey,
                deleteAPIKey: deleteAPIKey
            )
            .accessibilityIdentifier("settings.models.cloud.openai.setup")
        case "openai-codex-oauth":
            SettingsOAuthConnectorsSection(
                connectorOptions: connectorOptions.filter { $0.providerKey == "openai-codex" },
                expandedConnectorDetails: $expandedOAuthConnectorDetails,
                authorizeConnector: authorizeConnector,
                disconnectConnector: disconnectConnector
            )
            .accessibilityIdentifier("settings.models.cloud.openai-codex.setup")
        default:
            EmptyView()
        }
    }

    private func removeCloudProvider(_ row: CloudModelProviderRow) {
        switch row.setupKind {
        case .openAIAPIKey:
            deleteAPIKey()
        case .chatGPTOAuth:
            if let option = connectorOptions.first(where: { $0.providerKey == "openai-codex" }) {
                disconnectConnector(option)
            }
        }
    }

    private var configuredLocalModelRows: [LocalModelSettingsRow] {
        localModelStatus.settingsRows.filter { row in
            row.installRecord != nil || localModelDownloadProgress?.modelID == row.modelID
        }
    }

    private var shouldShowSectionLocalModelMessage: Bool {
        guard let localModelStatusMessageModelID else {
            return true
        }
        return !configuredLocalModelRows.contains { $0.modelID == localModelStatusMessageModelID }
    }

    private var addableLocalModelRows: [LocalModelSettingsRow] {
        localModelStatus.settingsRows.filter { row in
            row.primaryAction == .download && row.installRecord == nil && localModelDownloadProgress?.modelID != row.modelID
        }
    }

    @ViewBuilder
    private var localAddList: some View {
        if addableLocalModelRows.isEmpty {
            Text(KairoL10n.string("settings.models.local.add.empty"))
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.models.local.add.empty")
        } else {
            ForEach(addableLocalModelRows) { row in
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        pushPage(.localDetail(row.modelID))
                    }
                    downloadLocalModel(row)
                } label: {
                    addListRow(
                        title: row.displayName,
                        subtitle: row.detailText,
                        status: row.statusText,
                        systemImage: "arrow.down.circle"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.models.local.add.\(row.modelID)")
            }
        }
    }

    private var selectedModelSummaryIconName: String {
        if localModelStatus.localModelInstalled {
            return "checkmark.seal.fill"
        }
        if downloadedModel != nil {
            return "arrow.down.circle.fill"
        }
        return "circle.dashed"
    }

    private var selectedModelSummaryIconColor: Color {
        if localModelStatus.localModelInstalled || downloadedModel != nil {
            return .blue
        }
        return .secondary
    }

    private var downloadedModel: LocalModelManifest? {
        let installedModelIDs = Set(localModelStatus.installedModels
            .filter { $0.status == .installed }
            .map(\.modelID))
        return localModelStatus.availableModels.first { installedModelIDs.contains($0.id) }
    }

    private var selectableLocalModelRows: [LocalModelSettingsRow] {
        localModelStatus.settingsRows.filter { row in
            switch row.primaryAction {
            case .select, .selected:
                return true
            case .download, .retryDownload, .unavailable:
                return false
            }
        }
    }

    private var compactRoutePreferenceMenu: some View {
        Menu {
            ForEach(ProviderRoutePreference.settingsChoices, id: \.self) { preference in
                Button {
                    setLocalModelPreference(preference)
                } label: {
                    Text(preference.settingsTitle)
                }
                .accessibilityIdentifier("settings.models.preference.\(preference.rawValue)")
            }
        } label: {
            HStack(spacing: 3) {
                Text(localModelStatus.preference.settingsTitle)
                    .font(compactControlValueFont)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KairoL10n.string("settings.models.routePreference"))
        .accessibilityIdentifier("settings.models.preference")
    }

    private var compactResponseLanguageMenu: some View {
        Menu {
            ForEach(ChatResponseLanguagePreference.settingsChoices, id: \.self) { responseLanguage in
                Button {
                    setResponseLanguage(responseLanguage)
                } label: {
                    Text(responseLanguage.settingsTitle)
                }
                .accessibilityIdentifier("settings.responseLanguage.\(responseLanguage.rawValue)")
            }
        } label: {
            HStack(spacing: 3) {
                Text(localModelStatus.responseLanguage.settingsTitle)
                    .font(compactControlValueFont)
                    .lineLimit(1)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.blue.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KairoL10n.string("settings.responseLanguage.title"))
        .accessibilityIdentifier("settings.responseLanguage")
    }

    @ViewBuilder
    private func compactLocalModelRow(_ row: LocalModelSettingsRow) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                pushPage(.localDetail(row.modelID))
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                localModelSummaryRow(row)

                if localModelDownloadProgress?.modelID == row.modelID, let progress = localModelDownloadProgress {
                    downloadProgressView(progress, row: row)
                }

                if localModelStatusMessageModelID == row.modelID, let localModelStatusMessage {
                    Text(localModelStatusMessage)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("settings.models.benchmark-message")
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).row")
    }

    private func localModelSummaryRow(_ row: LocalModelSettingsRow, showsSelectedStatus: Bool = true) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(row.displayName)
                .font(compactModelNameFont)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundStyle(KairoDesign.ink)
                .accessibilityIdentifier("settings.models.\(row.modelID).name")

            Spacer(minLength: 6)

            if showsSelectedStatus || row.primaryAction != .selected {
                Text(row.statusText)
                    .font(compactModelStatusFont)
                    .foregroundStyle(localModelStatusColor(row.primaryAction))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(localModelStatusColor(row.primaryAction).opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private func localDetailPage(for row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }

            KairoFocusCard {
                VStack(alignment: .leading, spacing: 12) {
                    localModelSummaryRow(row, showsSelectedStatus: false)

                    if localModelDownloadProgress?.modelID == row.modelID, let progress = localModelDownloadProgress {
                        downloadProgressView(progress, row: row)
                    }

                    if localModelStatusMessageModelID == row.modelID, let localModelStatusMessage {
                        Text(localModelStatusMessage)
                            .font(compactModelMetadataFont)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.models.benchmark-message")
                    }

                    Divider()

                    runtimePills(for: row)

                    Text(row.manifestTransparencyText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary.opacity(0.85))
                        .lineLimit(2)
                        .truncationMode(.tail)

                    Text(row.licenseApprovalText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary.opacity(0.9))
                        .lineLimit(2)

                    if row.primaryAction == .select || row.primaryAction == .selected {
                        localModelParameterControls(for: row)
                    }

                    localModelDetailActions(for: row)
                }
            }
            .accessibilityIdentifier("settings.models.\(row.modelID).detail")
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private func localModelParameterControls(for row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(KairoL10n.string("settings.models.parameters.title"))
                    .font(compactSectionHeadingFont)
                    .foregroundStyle(KairoDesign.ink)
            }

            parameterPickerRow(
                title: KairoL10n.string("settings.models.benchmark.context"),
                accessibilityIdentifier: "settings.models.\(row.modelID).context-size"
            ) {
                Picker(
                    KairoL10n.string("settings.models.benchmark.context"),
                    selection: Binding(
                        get: { row.runtimeParameters.contextSize },
                        set: { updateRuntimeParameters(for: row, contextSize: $0) }
                    )
                ) {
                    ForEach(availableBenchmarkContextSizes(for: row), id: \.self) { size in
                        Text(KairoL10n.string("settings.models.benchmark.contextOption", Int64(size / 1024)))
                            .tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            parameterPickerRow(
                title: KairoL10n.string("settings.models.parameters.output"),
                accessibilityIdentifier: "settings.models.\(row.modelID).max-output"
            ) {
                Picker(
                    KairoL10n.string("settings.models.parameters.output"),
                    selection: Binding(
                        get: { row.runtimeParameters.maxOutputTokens },
                        set: { updateRuntimeParameters(for: row, maxOutputTokens: $0) }
                    )
                ) {
                    ForEach([64, 128, 256, 512, 1_024, 2_048], id: \.self) { tokens in
                        Text(KairoL10n.string("settings.models.parameters.outputOption", Int64(tokens)))
                            .tag(tokens)
                    }
                }
                .pickerStyle(.segmented)
            }

            parameterSliderRow(
                title: KairoL10n.string("settings.models.parameters.temperature"),
                valueText: String(format: "%.1f", row.runtimeParameters.temperature),
                accessibilityIdentifier: "settings.models.\(row.modelID).temperature"
            ) {
                Slider(
                    value: Binding(
                        get: { row.runtimeParameters.temperature },
                        set: { updateRuntimeParameters(for: row, temperature: $0) }
                    ),
                    in: 0...1.5,
                    step: 0.1
                )
            }

            if let runInfo = localModelBenchmarkRunInfo, runInfo.modelID == row.modelID {
                localModelBenchmarkRunInfoView(runInfo)
            }
        }
        .padding(10)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .accessibilityIdentifier("settings.models.\(row.modelID).parameters")
    }

    private func parameterPickerRow<Content: View>(
        title: String,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(compactModelMetadataFont.weight(.semibold))
                .foregroundStyle(KairoDesign.muted)
            content()
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func parameterSliderRow<Content: View>(
        title: String,
        valueText: String,
        accessibilityIdentifier: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(compactModelMetadataFont.weight(.semibold))
                    .foregroundStyle(KairoDesign.muted)
                Spacer()
                Text(valueText)
                    .font(compactModelStatusFont)
                    .foregroundStyle(KairoDesign.ink)
                    .monospacedDigit()
            }
            content()
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func updateRuntimeParameters(
        for row: LocalModelSettingsRow,
        contextSize: Int? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil
    ) {
        let updated = LocalModelRuntimeParameters(
            contextSize: contextSize ?? row.runtimeParameters.contextSize,
            maxOutputTokens: maxOutputTokens ?? row.runtimeParameters.maxOutputTokens,
            temperature: temperature ?? row.runtimeParameters.temperature
        ).clamped(to: row.manifest)
        setLocalModelRuntimeParameters(updated, row)
    }

    private func localModelBenchmarkRunInfoView(_ runInfo: LocalModelBenchmarkRunInfo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if runInfo.state == .running {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: runInfo.state.systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(runInfo.state.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(runInfo.state.title)
                    .font(compactModelMetadataFont.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(KairoL10n.string(
                    "settings.models.benchmark.liveDetail",
                    Int64(runInfo.contextSize),
                    Int64(runInfo.outputTokenTarget)
                ))
                    .font(compactModelMetadataFont)
                    .foregroundStyle(KairoDesign.muted)
                if let summary = runInfo.summary {
                    Text(summary)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(KairoDesign.muted)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityIdentifier("settings.models.\(runInfo.modelID).benchmark-run-info.\(runInfo.state.identifier)")
    }

    private func selectedBenchmarkContext(for row: LocalModelSettingsRow) -> Int {
        row.runtimeParameters.contextSize
    }

    private func availableBenchmarkContextSizes(for row: LocalModelSettingsRow) -> [Int] {
        LocalModelBenchmarkRunInfo.contextSizeChoices.filter { $0 <= row.manifest.contextWindow }
    }

    @ViewBuilder
    private func localModelDetailActions(for row: LocalModelSettingsRow) -> some View {
        if row.primaryAction == .retryDownload {
            compactActionButton(
                row.primaryAction.title,
                systemImage: "arrow.down.circle",
                accessibilityIdentifier: "settings.models.\(row.modelID).retry",
                tint: .blue
            ) {
                downloadLocalModel(row)
            }
        }

        LazyVGrid(columns: compactButtonGridColumns, alignment: .leading, spacing: 8) {
            if row.primaryAction == .select {
                compactActionButton(
                    row.primaryAction.title,
                    systemImage: "checkmark.circle",
                    accessibilityIdentifier: "settings.models.\(row.modelID).select",
                    tint: .blue
                ) {
                    selectLocalModel(row)
                }
            }

            if row.primaryAction == .select || row.primaryAction == .selected {
                compactActionButton(
                    KairoL10n.string("settings.models.speed"),
                    systemImage: "speedometer",
                    accessibilityIdentifier: "settings.models.\(row.modelID).benchmark-run",
                    tint: .blue
                ) {
                    runLocalModelBenchmark(row, selectedBenchmarkContext(for: row))
                }
            }

            if row.canDelete {
                compactActionButton(
                    KairoL10n.string("settings.models.delete"),
                    systemImage: "trash",
                    accessibilityIdentifier: "settings.models.\(row.modelID).delete",
                    tint: .red,
                    role: .destructive
                ) {
                    deleteLocalModel(row)
                    withAnimation(.snappy(duration: 0.2)) {
                        popPage()
                    }
                }
            }
        }
    }

    private func compactModelDiagnostics(for row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(row.displayName)
                    .font(compactModelNameFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }

            runtimePills(for: row)

            Text(row.manifestTransparencyText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.85))
                .lineLimit(2)
                .truncationMode(.tail)
                .accessibilityIdentifier("settings.models.\(row.modelID).manifest")

            if let benchmarkSummaryText = row.benchmarkSummaryText {
                Text(benchmarkSummaryText)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("settings.models.\(row.modelID).benchmark")
            }

            LazyVGrid(columns: compactButtonGridColumns, alignment: .leading, spacing: 8) {
                compactActionButton(
                    KairoL10n.string("settings.models.speed"),
                    systemImage: "speedometer",
                    accessibilityIdentifier: "settings.models.\(row.modelID).benchmark-run",
                    tint: .blue
                ) {
                    runLocalModelBenchmark(row, selectedBenchmarkContext(for: row))
                }

                if row.canDelete {
                    compactActionButton(
                        KairoL10n.string("settings.models.delete"),
                        systemImage: "trash",
                        accessibilityIdentifier: "settings.models.\(row.modelID).delete",
                        tint: .red,
                        role: .destructive
                    ) {
                        deleteLocalModel(row)
                    }
                }
            }
        }
        .padding(10)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
    }

    private func runtimePills(for row: LocalModelSettingsRow) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(row.runtimePillTexts.enumerated()), id: \.offset) { index, text in
                Text(text)
                    .font(compactModelMetadataFont)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.06), in: Capsule())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.models.\(row.modelID).runtime-pill.\(index)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(row.runtimeFitText)
        .accessibilityIdentifier("settings.models.\(row.modelID).runtime-fit")
    }

    private var compactButtonGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 108), spacing: 8, alignment: .leading)]
    }

    private var compactSectionTitleFont: Font { .title3.weight(.semibold) }

    private var compactSectionHeadingFont: Font { .subheadline.weight(.semibold) }

    private var compactModelNameFont: Font { .subheadline.weight(.semibold) }

    private var compactModelMetadataFont: Font { .caption }

    private var compactModelStatusFont: Font { .caption2.weight(.semibold) }

    private var compactButtonLabelFont: Font { .caption.weight(.semibold) }

    private var compactControlValueFont: Font { .subheadline.weight(.semibold) }

    @ViewBuilder
    private func compactLocalModelAction(for row: LocalModelSettingsRow) -> some View {
        switch row.primaryAction {
        case .download, .retryDownload:
            compactActionButton(
                row.primaryAction.title,
                systemImage: "arrow.down.circle",
                accessibilityIdentifier: "settings.models.\(row.modelID).download",
                tint: .blue
            ) {
                downloadLocalModel(row)
            }
        case .select:
            compactActionButton(
                row.primaryAction.title,
                systemImage: "checkmark.circle",
                accessibilityIdentifier: "settings.models.\(row.modelID).select",
                tint: .blue
            ) {
                selectLocalModel(row)
            }
        case .selected:
            Label(row.primaryAction.title, systemImage: "checkmark.circle.fill")
                .font(compactButtonLabelFont)
                .foregroundStyle(.green)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .accessibilityIdentifier("settings.models.\(row.modelID).select")
        case .unavailable:
            Text(row.primaryAction.title)
                .font(compactButtonLabelFont)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .accessibilityIdentifier("settings.models.\(row.modelID).unavailable")
        }
    }

    private func modelAddButton(
        title: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(compactButtonLabelFont)
                .foregroundStyle(KairoDesign.blue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(KairoDesign.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func addListRow(
        title: String,
        subtitle: String,
        status: String,
        systemImage: String
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.blue)
                .frame(width: 30, height: 30)
                .background(KairoDesign.blue.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(compactModelNameFont)
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(2)

                Text(subtitle)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(status)
                .font(compactModelStatusFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
    }

    private func downloadProgressView(_ progress: LocalModelDownloadProgressState, row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ProgressView(value: progress.fractionCompleted)
                    .progressViewStyle(.linear)
                    .accessibilityIdentifier("settings.models.\(progress.modelID).download-progress-bar")

                Text(progress.displayText)
                    .font(compactModelStatusFont)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                    .accessibilityIdentifier("settings.models.\(progress.modelID).download-progress-text")
            }

            if progress.allowsCancellation {
                HStack(spacing: 6) {
                    Text(KairoL10n.string("settings.models.download.keepOpen"))
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("settings.models.\(progress.modelID).download-cancel-note")

                    compactActionButton(
                        KairoL10n.string("settings.models.download.cancelActive"),
                        systemImage: "xmark.circle",
                        accessibilityIdentifier: "settings.models.\(progress.modelID).download-active-cancel",
                        tint: .secondary,
                        role: .cancel
                    ) {
                        cancelLocalModelDownload(row)
                    }
                }
            }
        }
        .padding(10)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KairoDesign.amber.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(progress.displayText)
        .accessibilityIdentifier("settings.models.\(progress.modelID).download-progress")
    }

    private func compactActionButton(
        _ title: String,
        systemImage: String,
        accessibilityIdentifier: String,
        tint: Color,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role) {
            action()
        } label: {
            Label(title, systemImage: systemImage)
                .font(compactButtonLabelFont)
                .imageScale(.small)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(tint)
                .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct CloudModelProviderRow: Identifiable, Equatable {
    var id: String
    var title: String
    var method: String
    var status: String
    var isConfigured: Bool
    var setupKind: CloudModelProviderSetupKind

    var canConfigure: Bool {
        switch setupKind {
        case .openAIAPIKey:
            return true
        case .chatGPTOAuth:
            return true
        }
    }
}

private enum CloudModelProviderSetupKind: Equatable {
    case openAIAPIKey
    case chatGPTOAuth

    var systemImage: String {
        switch self {
        case .openAIAPIKey:
            return "key.fill"
        case .chatGPTOAuth:
            return "person.crop.circle.badge.checkmark"
        }
    }
}

private enum ModelSettingsPage: Equatable {
    case addCloud
    case addLocal
    case cloudDetail(String)
    case localDetail(String)

    var title: String {
        switch self {
        case .addCloud:
            return KairoL10n.string("settings.models.cloud.add.title")
        case .addLocal:
            return KairoL10n.string("settings.models.local.add.title")
        case .cloudDetail:
            return KairoL10n.string("settings.models.cloud.detail.title")
        case .localDetail:
            return KairoL10n.string("settings.models.local.detail.title")
        }
    }

    var detail: String {
        switch self {
        case .addCloud:
            return KairoL10n.string("settings.models.cloud.add.detail")
        case .addLocal:
            return KairoL10n.string("settings.models.local.add.detail")
        case .cloudDetail:
            return KairoL10n.string("settings.models.cloud.detail.detail")
        case .localDetail:
            return KairoL10n.string("settings.models.local.detail.detail")
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .addCloud:
            return "settings.models.cloud.add.page"
        case .addLocal:
            return "settings.models.local.add.page"
        case .cloudDetail:
            return "settings.models.cloud.detail.page"
        case .localDetail:
            return "settings.models.local.detail.page"
        }
    }
}

struct LocalModelBenchmarkRunInfo: Equatable {
    static let contextSizeChoices = LocalModelRuntimeParameters.contextSizeChoices
    static let defaultContextSize = 4_096

    var modelID: String
    var contextSize: Int
    var outputTokenTarget: Int
    var state: State
    var summary: String?

    enum State: Equatable {
        case running
        case finished
        case failed

        var title: String {
            switch self {
            case .running:
                return KairoL10n.string("settings.models.benchmark.running")
            case .finished:
                return KairoL10n.string("settings.models.benchmark.finished")
            case .failed:
                return KairoL10n.string("settings.models.benchmark.failed")
            }
        }

        var identifier: String {
            switch self {
            case .running:
                return "running"
            case .finished:
                return "finished"
            case .failed:
                return "failed"
            }
        }

        var systemImage: String {
            switch self {
            case .running:
                return "speedometer"
            case .finished:
                return "checkmark.circle.fill"
            case .failed:
                return "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .running:
                return KairoDesign.blue
            case .finished:
                return KairoDesign.green
            case .failed:
                return KairoDesign.red
            }
        }
    }
}
#endif
