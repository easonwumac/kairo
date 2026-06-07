#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
    @State private var pageStack: [ModelSettingsPage] = []
    @State private var defaultModelNotice: String?
    @State private var customHuggingFaceModelInput = ""
    @State private var omlxEndpoint = ""
    @State private var omlxAPIKey = ""
    @State private var omlxModel = ""
    @State private var omlxDisplayName = ""
    @State private var showOmlxEditor = false
    @State private var omlxStatusMessage: String?
    @State private var hasOmlxConfigured = false
    @State private var omlxFetchedModels: [String] = []

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
    let localModelDownloadQueue: [LocalModelSettingsRow]
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
    let addCustomHuggingFaceLocalModel: (String) -> Void
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
        .overlay(alignment: .top) {
            if let defaultModelNotice {
                defaultModelNoticeView(defaultModelNotice)
                    .padding(.horizontal, 16)
                    .padding(.top, topPadding)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .task(id: defaultModelNotice) {
            guard let notice = defaultModelNotice else { return }
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled, defaultModelNotice == notice else { return }
            withAnimation(.easeOut(duration: 0.35)) {
                defaultModelNotice = nil
            }
        }
        .preference(key: RootChromePreferenceKey.self, value: rootChromeContext)
        .task {
            loadOmlxSettings()
        }
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
        case .defaultModel, .responseLanguage:
            return page.title
        case let .cloudDetail(providerID):
            return cloudProviderRows.first { $0.id == providerID }?.title ?? page.title
        case let .localDetail(modelID):
            return localModelStatus.settingsRows.first { $0.modelID == modelID }?.displayName ?? page.title
        case .omlxModelPicker:
            return page.title
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
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(KairoL10n.string("settings.models.starter.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                }
                .accessibilityIdentifier("settings.models.starter")

                ForEach(configuredLocalModelRows) { row in
                    compactLocalModelRow(row)
                    if row.modelID != configuredLocalModelRows.last?.modelID {
                        Divider()
                    }
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
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                        .accessibilityIdentifier("settings.models.benchmark-message")
                }
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
        case .defaultModel:
            defaultModelSelectionPage
        case .responseLanguage:
            responseLanguageSelectionPage
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
        case .omlxModelPicker:
            omlxModelPickerPage
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

                    switch page {
                    case .addCloud:
                        cloudAddList
                    case .addLocal:
                        localAddList
                    case .cloudDetail, .localDetail, .defaultModel, .responseLanguage, .omlxModelPicker:
                        EmptyView()
                    }
                }
            }
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
            }

            Spacer(minLength: 8)

            responseLanguageSelectorButton
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.responseLanguage.card")
    }

    private var selectedModelInline: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: selectedModelSummaryIconName)
                .font(.headline)
                .foregroundStyle(selectedModelSummaryIconColor)
                .frame(width: 30, height: 30)
                .background(selectedModelSummaryIconColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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

            defaultModelSelectorButton
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(selectedModelSummaryText)
        .accessibilityIdentifier("settings.models.selected-summary")
    }

    private var defaultModelSelectorButton: some View {
        Button {
            guard hasSelectableDefaultModels else {
                withAnimation(.snappy(duration: 0.2)) {
                    defaultModelNotice = KairoL10n.string("settings.models.default.emptyNotice")
                }
                return
            }
            withAnimation(.snappy(duration: 0.2)) {
                defaultModelNotice = nil
                pushPage(.defaultModel)
            }
        } label: {
            HStack(spacing: 4) {
                Text(KairoL10n.string("settings.models.default.change"))
                    .font(compactButtonLabelFont)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
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

    private var hasSelectableDefaultModels: Bool {
        !configuredCloudProviderRows.isEmpty || !selectableLocalModelRows.isEmpty
    }

    private var defaultModelSelectionPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }

            KairoFocusCard {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(KairoL10n.string("settings.models.default.page.title"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                    }

                    if !configuredCloudProviderRows.isEmpty {
                        defaultModelSectionHeader(KairoL10n.string("settings.models.default.cloud.section"))
                        ForEach(configuredCloudProviderRows) { row in
                            defaultCloudModelRow(row)
                            if row.id != configuredCloudProviderRows.last?.id {
                                Divider()
                            }
                        }
                    }

                    if !selectableLocalModelRows.isEmpty {
                        if !configuredCloudProviderRows.isEmpty {
                            Divider()
                        }
                        defaultModelSectionHeader(KairoL10n.string("settings.models.default.local.section"))
                        ForEach(selectableLocalModelRows) { row in
                            defaultLocalModelRow(row)
                            if row.modelID != selectableLocalModelRows.last?.modelID {
                                Divider()
                            }
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.models.default.page")
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private func defaultModelNoticeView(_ message: String) -> some View {
        Label(message, systemImage: "info.circle.fill")
            .font(compactModelMetadataFont.weight(.semibold))
            .foregroundStyle(KairoDesign.ink)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(KairoDesign.blue.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: KairoDesign.shadow.opacity(0.18), radius: 18, x: 0, y: 8)
            .accessibilityIdentifier("settings.models.default.empty-notice")
    }

    private func defaultModelSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(compactModelMetadataFont.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func defaultCloudModelRow(_ row: CloudModelProviderRow) -> some View {
        Button {
            setLocalModelPreference(.preferCloud)
            withAnimation(.snappy(duration: 0.2)) {
                popPage()
            }
        } label: {
            defaultModelRowContent(
                title: row.title,
                subtitle: row.method,
                systemImage: "cloud.fill",
                tint: KairoDesign.blue,
                isSelected: localModelStatus.preference == .preferCloud
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.models.default.cloud.\(row.id)")
    }

    private func defaultLocalModelRow(_ row: LocalModelSettingsRow) -> some View {
        Button {
            selectLocalModel(row)
            withAnimation(.snappy(duration: 0.2)) {
                popPage()
            }
        } label: {
            defaultModelRowContent(
                title: row.displayName,
                subtitle: KairoL10n.string("settings.models.default.local.subtitle"),
                systemImage: "cpu.fill",
                tint: KairoDesign.teal,
                isSelected: localModelStatus.selectedModel?.id == row.modelID
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.models.default.local.\(row.modelID)")
    }

    private func defaultModelRowContent(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isSelected: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(compactModelNameFont)
                    .foregroundStyle(KairoDesign.ink)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 30, alignment: .center)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.teal)
            }
        }
    }

    private var responseLanguageSelectionPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }

            KairoFocusCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(KairoL10n.string("settings.responseLanguage.page.title"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)

                    ForEach(ChatResponseLanguagePreference.settingsChoices, id: \.self) { responseLanguage in
                        Button {
                            setResponseLanguage(responseLanguage)
                            withAnimation(.snappy(duration: 0.2)) {
                                popPage()
                            }
                        } label: {
                            defaultModelRowContent(
                                title: responseLanguage.settingsTitle,
                                subtitle: responseLanguage.settingsSubtitle,
                                systemImage: "globe",
                                tint: KairoDesign.blue,
                                isSelected: localModelStatus.responseLanguage == responseLanguage
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.responseLanguage.\(responseLanguage.rawValue)")

                        if responseLanguage != ChatResponseLanguagePreference.settingsChoices.last {
                            Divider()
                        }
                    }
                }
            }
            .accessibilityIdentifier("settings.responseLanguage.page")
        }
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
    }

    private var selectedModelSummaryText: String {
        if localModelStatus.preference == .preferCloud, let first = configuredCloudProviderRows.first {
            return first.title
        }
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
                method: "",
                status: hasOpenAIAPIKey
                    ? KairoL10n.string("settings.models.cloud.status.configured")
                    : "",
                isConfigured: hasOpenAIAPIKey,
                setupKind: .openAIAPIKey
            ),
            CloudModelProviderRow(
                id: "openai-codex-oauth",
                title: "OpenAI Codex",
                method: "",
                status: isChatGPTOAuthConnected
                    ? KairoL10n.string("settings.models.cloud.status.configured")
                    : "",
                isConfigured: isChatGPTOAuthConnected,
                setupKind: .chatGPTOAuth
            ),
            CloudModelProviderRow(
                id: "openai-compatible",
                title: KairoL10n.string("settings.omlx.section"),
                method: hasOmlxConfigured && !omlxDisplayName.isEmpty ? omlxDisplayName : "",
                status: hasOmlxConfigured
                    ? KairoL10n.string("settings.models.cloud.status.configured")
                    : "",
                isConfigured: hasOmlxConfigured,
                setupKind: .openAICompatible
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
                        subtitle: "",
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
            prepareSetup(for: row)
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

            Text(row.title)
                .font(compactModelNameFont)
                .foregroundStyle(KairoDesign.ink)
                .frame(minHeight: 30, alignment: .leading)

            Spacer(minLength: 8)

            Text(row.status)
                .font(compactModelStatusFont)
                .foregroundStyle(row.isConfigured ? .green : .secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func prepareSetup(for row: CloudModelProviderRow) {
        switch row.setupKind {
        case .openAIAPIKey:
            showAPIKeyEditor = true
        case .chatGPTOAuth:
            expandedOAuthConnectorDetails.insert("openai-codex")
        case .openAICompatible:
            showOmlxEditor = true
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

                    cloudDetailSubtitleView(for: row.setupKind)

                    cloudProviderSetup(for: row.id)

                    if row.isConfigured && row.setupKind != .openAICompatible {
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
    private func cloudDetailSubtitleView(for kind: CloudModelProviderSetupKind) -> some View {
        let text: String? = {
            switch kind {
            case .openAIAPIKey:
                return nil
            case .chatGPTOAuth:
                return nil
            case .openAICompatible:
                return nil
            }
        }()
        if let text {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cloudProviderSetup(for providerID: String) -> some View {
        switch providerID {
        case "openai-api": openAISetupSection
        case "openai-codex-oauth": codexSetupSection
        case "openai-compatible": omlxSetupSection
        default: EmptyView()
        }
    }

    private var openAISetupSection: some View {
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
    }

    private var codexSetupSection: some View {
        let options = connectorOptions.filter { $0.providerKey == "openai-codex" }.map { option in
            var copy = option
            copy.displayName = KairoL10n.string("settings.models.cloud.method.oauth")
            return copy
        }
        return SettingsOAuthConnectorsSection(
            connectorOptions: options,
            expandedConnectorDetails: $expandedOAuthConnectorDetails,
            presentation: .compact,
            authorizeConnector: authorizeConnector,
            disconnectConnector: disconnectConnector
        )
        .accessibilityIdentifier("settings.models.cloud.openai-codex.setup")
    }

    private var omlxSetupSection: some View {
        SettingsOpenAICompatibleSection(
            endpoint: $omlxEndpoint,
            apiKey: $omlxAPIKey,
            model: $omlxModel,
            displayName: $omlxDisplayName,
            showEditor: $showOmlxEditor,
            isConfigured: hasOmlxConfigured,
            statusMessage: omlxStatusMessage,
            save: saveOmlxSettings,
            delete: deleteOmlxSettings,
            onPushModelPicker: { models in
                omlxFetchedModels = models
                withAnimation(.snappy(duration: 0.2)) {
                    pushPage(.omlxModelPicker)
                }
            }
        )
        .accessibilityIdentifier("settings.models.cloud.omlx.setup")
    }

    private var omlxModelPickerPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !usesRootChromeNavigation {
                pageBackButton
            }

            if omlxFetchedModels.isEmpty {
                KairoFocusCard {
                    HStack {
                        Spacer()
                        Text("No models found")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 24)
                }
            } else {
                KairoFocusCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(omlxFetchedModels, id: \.self) { m in
                            Button {
                                omlxModel = m
                                omlxFetchedModels = []
                                popPage()
                            } label: {
                                HStack {
                                    Text(m)
                                        .font(.subheadline)
                                        .foregroundStyle(KairoDesign.ink)
                                        .lineLimit(1)
                                    Spacer()
                                    if omlxModel.trimmingCharacters(in: .whitespacesAndNewlines) == m {
                                        Image(systemName: "checkmark")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(KairoDesign.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if m != omlxFetchedModels.last {
                                Divider()
                                    .padding(.leading, 12)
                            }
                        }
                    }
                }
            }
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
        case .openAICompatible:
            deleteOmlxSettings()
        }
    }

    private func saveOmlxSettings() {
        let ep = omlxEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = omlxAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ep.isEmpty, !key.isEmpty else {
            omlxStatusMessage = "Endpoint and API key are required"
            return
        }
        UserDefaults.standard.set(ep, forKey: "omlx_endpoint")
        UserDefaults.standard.set(key, forKey: "omlx_api_key")
        UserDefaults.standard.set(omlxModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "omlx_model")
        UserDefaults.standard.set(omlxDisplayName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "omlx_display_name")
        hasOmlxConfigured = true
        omlxStatusMessage = "Saved"
    }

    private func deleteOmlxSettings() {
        UserDefaults.standard.removeObject(forKey: "omlx_endpoint")
        UserDefaults.standard.removeObject(forKey: "omlx_api_key")
        UserDefaults.standard.removeObject(forKey: "omlx_model")
        UserDefaults.standard.removeObject(forKey: "omlx_display_name")
        omlxEndpoint = ""
        omlxAPIKey = ""
        omlxModel = ""
        omlxDisplayName = ""
        hasOmlxConfigured = false
        omlxStatusMessage = nil
    }

    private func loadOmlxSettings() {
        omlxEndpoint = UserDefaults.standard.string(forKey: "omlx_endpoint") ?? ""
        omlxAPIKey = UserDefaults.standard.string(forKey: "omlx_api_key") ?? ""
        omlxModel = UserDefaults.standard.string(forKey: "omlx_model") ?? ""
        omlxDisplayName = UserDefaults.standard.string(forKey: "omlx_display_name") ?? ""
        hasOmlxConfigured = !omlxEndpoint.isEmpty && !omlxAPIKey.isEmpty
    }

    private var configuredLocalModelRows: [LocalModelSettingsRow] {
        localModelStatus.settingsRows.filter { row in
            row.installRecord != nil
                || localModelDownloadProgress?.modelID == row.modelID
                || queuedLocalModelIDs.contains(row.modelID)
        }
    }

    private var queuedLocalModelIDs: Set<String> {
        Set(localModelDownloadQueue.map(\.modelID))
    }

    private var shouldShowSectionLocalModelMessage: Bool {
        guard let localModelStatusMessageModelID else {
            return true
        }
        return !configuredLocalModelRows.contains { $0.modelID == localModelStatusMessageModelID }
    }

    private var addableLocalModelRows: [LocalModelSettingsRow] {
        localModelStatus.settingsRows.filter { row in
            row.primaryAction == .download
                && row.installRecord == nil
                && localModelDownloadProgress?.modelID != row.modelID
                && !queuedLocalModelIDs.contains(row.modelID)
        }
    }

    @ViewBuilder
    private var localAddList: some View {
        customHuggingFaceModelForm

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
                        systemImage: "arrow.down.circle"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.models.local.add.\(row.modelID)")
            }
        }
    }

    private var customHuggingFaceModelForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(
                KairoL10n.string("settings.models.local.custom.placeholder"),
                text: $customHuggingFaceModelInput
            )
            .autocorrectionDisabled()
            .font(compactModelMetadataFont)
            .foregroundStyle(KairoDesign.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(KairoDesign.blue.opacity(0.16), lineWidth: 1)
            }
            .accessibilityIdentifier("settings.models.local.custom.input")

            Button {
                let input = customHuggingFaceModelInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !input.isEmpty else { return }
                addCustomHuggingFaceLocalModel(input)
            } label: {
                Label(KairoL10n.string("settings.models.local.custom.add"), systemImage: "link.badge.plus")
                    .font(compactButtonLabelFont)
                    .foregroundStyle(KairoDesign.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(KairoDesign.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(customHuggingFaceModelInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("settings.models.local.custom.add")
        }
        .padding(.bottom, 4)
    }

    private var selectedModelSummaryIconName: String {
        if localModelStatus.preference == .preferCloud, !configuredCloudProviderRows.isEmpty {
            return "cloud.fill"
        }
        if localModelStatus.localModelInstalled {
            return "checkmark.seal.fill"
        }
        if downloadedModel != nil {
            return "arrow.down.circle.fill"
        }
        return "circle.dashed"
    }

    private var selectedModelSummaryIconColor: Color {
        if localModelStatus.preference == .preferCloud, !configuredCloudProviderRows.isEmpty {
            return KairoDesign.blue
        }
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

    private var responseLanguageSelectorButton: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                pushPage(.responseLanguage)
            }
        } label: {
            pillNavigationLabel(
                Text(localModelStatus.responseLanguage.settingsTitle)
            )
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
        .padding(.vertical, 2)
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

            if localModelDownloadProgress?.modelID == row.modelID {
                EmptyView()
            } else if queuedLocalModelIDs.contains(row.modelID) {
                Text(KairoL10n.string("settings.models.status.queued"))
                    .font(compactModelStatusFont)
                    .foregroundStyle(KairoDesign.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(KairoDesign.blue.opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            } else if row.primaryAction != .download && (showsSelectedStatus || row.primaryAction != .selected) {
                Text(row.statusText)
                    .font(compactModelStatusFont)
                    .foregroundStyle(localModelStatusColor(row.primaryAction))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(localModelStatusColor(row.primaryAction).opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            if showsSelectedStatus {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
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
                    ForEach(LocalModelRuntimeParameters.maxOutputTokenChoices, id: \.self) { tokens in
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
        if (row.primaryAction == .download || row.primaryAction == .retryDownload)
            && localModelDownloadProgress?.modelID != row.modelID
            && !queuedLocalModelIDs.contains(row.modelID) {
            compactActionButton(
                row.primaryAction.title,
                systemImage: "arrow.down.circle",
                accessibilityIdentifier: "settings.models.\(row.modelID).download",
                tint: .blue
            ) {
                downloadLocalModel(row)
            }
        }

        LazyVGrid(columns: compactButtonGridColumns, alignment: .leading, spacing: 8) {
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

    private var compactModelNameFont: Font { .footnote.weight(.semibold) }

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

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

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

    private func pillNavigationLabel(_ title: Text) -> some View {
        HStack(spacing: 4) {
            title
                .font(compactButtonLabelFont)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(KairoDesign.blue)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(KairoDesign.blue.opacity(0.08), in: Capsule())
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
        case .openAICompatible:
            return true
        }
    }
}

private enum CloudModelProviderSetupKind: Equatable {
    case openAIAPIKey
    case chatGPTOAuth
    case openAICompatible

    var systemImage: String {
        switch self {
        case .openAIAPIKey:
            return "key.fill"
        case .chatGPTOAuth:
            return "person.crop.circle.badge.checkmark"
        case .openAICompatible:
            return "network"
        }
    }
}

private enum ModelSettingsPage: Equatable {
    case addCloud
    case addLocal
    case defaultModel
    case responseLanguage
    case cloudDetail(String)
    case localDetail(String)
    case omlxModelPicker

    var title: String {
        switch self {
        case .addCloud:
            return KairoL10n.string("settings.models.cloud.add.title")
        case .addLocal:
            return KairoL10n.string("settings.models.local.add.title")
        case .defaultModel:
            return KairoL10n.string("settings.models.default.page.title")
        case .responseLanguage:
            return KairoL10n.string("settings.responseLanguage.page.title")
        case .cloudDetail:
            return KairoL10n.string("settings.models.cloud.detail.title")
        case .localDetail:
            return KairoL10n.string("settings.models.local.detail.title")
        case .omlxModelPicker:
            return KairoL10n.string("settings.omlx.modelPicker.title")
        }
    }

    var detail: String {
        switch self {
        case .addCloud:
            return KairoL10n.string("settings.models.cloud.add.detail")
        case .addLocal:
            return KairoL10n.string("settings.models.local.add.detail")
        case .defaultModel:
            return KairoL10n.string("settings.models.default.page.detail")
        case .responseLanguage:
            return KairoL10n.string("settings.responseLanguage.page.title")
        case .cloudDetail:
            return KairoL10n.string("settings.models.cloud.detail.detail")
        case .localDetail:
            return KairoL10n.string("settings.models.local.detail.detail")
        case .omlxModelPicker:
            return ""
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .addCloud:
            return "settings.models.cloud.add.page"
        case .addLocal:
            return "settings.models.local.add.page"
        case .defaultModel:
            return "settings.models.default.page"
        case .responseLanguage:
            return "settings.responseLanguage.page"
        case .cloudDetail:
            return "settings.models.cloud.detail.page"
        case .localDetail:
            return "settings.models.local.detail.page"
        case .omlxModelPicker:
            return "settings.models.cloud.omlx.modelPicker"
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
