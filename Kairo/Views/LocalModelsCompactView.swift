#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
    private let starterModelIDs = LocalModelCatalog.kairoStarterModelIDs
    @State private var pendingDownloadModelID: String?
    @State private var showAdvancedDiagnostics = false

    var topPadding: CGFloat = 16
    let hasOpenAIAPIKey: Bool
    let isChatGPTOAuthConnected: Bool
    let isChatGPTOAuthAvailable: Bool
    let localModelStatus: LocalModelSettingsStatus
    let localModelDownloadProgress: LocalModelDownloadProgressState?
    let localModelStatusMessage: String?
    let localModelStatusMessageModelID: String?
    let localModelCatalogSourceText: String
    let localModelStatusColor: (LocalModelSettingsPrimaryAction) -> Color
    let setLocalModelPreference: (ProviderRoutePreference) -> Void
    let setResponseLanguage: (ChatResponseLanguagePreference) -> Void
    let refreshLocalModelCatalog: () -> Void
    let downloadLocalModel: (LocalModelSettingsRow) -> Void
    let cancelLocalModelDownload: (LocalModelSettingsRow) -> Void
    let selectLocalModel: (LocalModelSettingsRow) -> Void
    let runLocalModelBenchmark: (LocalModelSettingsRow) -> Void
    let runLocalModelReplyCheck: (LocalModelSettingsRow) -> Void
    let deleteLocalModel: (LocalModelSettingsRow) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                answerRouteCard

                cloudModelsSection

                modelStarterSection

                catalogDiagnosticsCard

                advancedDiagnosticsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, topPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.visible)
        .background(KairoDesign.background.ignoresSafeArea())
        .accessibilityIdentifier("settings.models.screen")
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

            if visibleModelRows.isEmpty {
                Text(KairoL10n.string("settings.models.emptyCatalog"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(visibleModelRows) { row in
                compactLocalModelRow(row)
            }

            if trimmedModelRowCount > 0 {
                HStack {
                    Text(trimmedModelSummaryText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(trimmedModelSummaryText)
                .accessibilityIdentifier("settings.models.trimmed-note")
            }

            if localModelStatusMessageModelID == nil, let localModelStatusMessage {
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

                ForEach(cloudProviderRows) { row in
                    cloudProviderRow(row)
                    if row.id != cloudProviderRows.last?.id {
                        Divider()
                    }
                }
            }
        }
        .accessibilityIdentifier("settings.models.cloud")
    }

    private var advancedDiagnosticsSection: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showAdvancedDiagnostics.toggle()
                    }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Text(KairoL10n.string("settings.models.advanced.section"))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)

                        Spacer(minLength: 8)

                        Image(systemName: showAdvancedDiagnostics ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                            .frame(width: 36, height: 36)
                            .background(KairoDesign.blue.opacity(0.10), in: Circle())
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showAdvancedDiagnostics ? KairoL10n.string("settings.models.advanced.hide") : KairoL10n.string("settings.models.advanced.show"))
                .accessibilityIdentifier("settings.models.advanced-diagnostics.toggle")

                if showAdvancedDiagnostics {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(visibleModelRows) { row in
                            compactModelDiagnostics(for: row)
                        }
                    }
                }
            }
        }
    }

    private var catalogDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(KairoL10n.string("settings.models.catalog"))
                    .font(compactSectionHeadingFont)

                Text(localModelCatalogSourceText)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .accessibilityIdentifier("settings.models.catalog-source")
            }

            compactActionButton(
                KairoL10n.string("settings.models.refresh"),
                systemImage: "arrow.clockwise",
                accessibilityIdentifier: "settings.models.refresh-catalog",
                tint: .blue,
                action: refreshLocalModelCatalog
            )
            .accessibilityLabel(KairoL10n.string("settings.models.refreshCatalog"))
        }
        .padding(12)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localModelCatalogSourceText)
        .accessibilityIdentifier("settings.models.catalog-card")
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
                if row.benchmarkSummaryText != nil {
                    compactActionButton(
                        KairoL10n.string("settings.models.speed"),
                        systemImage: "speedometer",
                        accessibilityIdentifier: "settings.models.\(row.modelID).benchmark-run",
                        tint: .blue
                    ) {
                        runLocalModelBenchmark(row)
                    }
                }

                compactActionButton(
                    KairoL10n.string("settings.models.reply"),
                    systemImage: "text.bubble",
                    accessibilityIdentifier: "settings.models.\(row.modelID).reply-check",
                    tint: .blue
                ) {
                    runLocalModelReplyCheck(row)
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
        .padding(12)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
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
                isConfigured: hasOpenAIAPIKey
            ),
            CloudModelProviderRow(
                id: "chatgpt-oauth",
                title: "ChatGPT",
                method: KairoL10n.string("settings.models.cloud.method.oauth"),
                status: isChatGPTOAuthConnected
                    ? KairoL10n.string("settings.models.cloud.status.configured")
                    : isChatGPTOAuthAvailable
                        ? KairoL10n.string("settings.models.cloud.status.oauthSetup")
                        : KairoL10n.string("settings.models.cloud.status.metadataOnly"),
                isConfigured: isChatGPTOAuthConnected
            ),
            CloudModelProviderRow(
                id: "anthropic",
                title: "Claude",
                method: KairoL10n.string("settings.models.cloud.method.apiKey"),
                status: KairoL10n.string("settings.models.cloud.status.metadataOnly"),
                isConfigured: false
            ),
            CloudModelProviderRow(
                id: "gemini",
                title: "Gemini",
                method: KairoL10n.string("settings.models.cloud.method.apiKeyOrOAuth"),
                status: KairoL10n.string("settings.models.cloud.status.metadataOnly"),
                isConfigured: false
            ),
            CloudModelProviderRow(
                id: "mistral",
                title: "Mistral",
                method: KairoL10n.string("settings.models.cloud.method.apiKey"),
                status: KairoL10n.string("settings.models.cloud.status.metadataOnly"),
                isConfigured: false
            ),
            CloudModelProviderRow(
                id: "perplexity",
                title: "Perplexity",
                method: KairoL10n.string("settings.models.cloud.method.apiKey"),
                status: KairoL10n.string("settings.models.cloud.status.metadataOnly"),
                isConfigured: false
            )
        ]
    }

    private func cloudProviderRow(_ row: CloudModelProviderRow) -> some View {
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
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("settings.models.cloud.\(row.id)")
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

    private var visibleModelRows: [LocalModelSettingsRow] {
        let starterIDs = Set(starterModelIDs)
        let starterRows = localModelStatus.settingsRows.filter { starterIDs.contains($0.modelID) }
        if starterRows.isEmpty {
            return Array(localModelStatus.settingsRows.prefix(starterModelIDs.count))
        }
        return starterRows
    }

    private var trimmedModelRowCount: Int {
        max(localModelStatus.settingsRows.count - visibleModelRows.count, 0)
    }

    private var trimmedModelSummaryText: String {
        KairoL10n.string("settings.models.compact.trimmed", Int64(visibleModelRows.count))
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(row.displayName)
                    .font(compactModelNameFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .accessibilityIdentifier("settings.models.\(row.modelID).name")

                Spacer(minLength: 6)

                Text(row.statusText)
                    .font(compactModelStatusFont)
                    .foregroundStyle(localModelStatusColor(row.primaryAction))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(localModelStatusColor(row.primaryAction).opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            HStack(alignment: .center, spacing: 8) {
                compactLocalModelAction(for: row)
                Spacer(minLength: 0)
            }

            if pendingDownloadModelID == row.modelID {
                downloadPreview(for: row)
            }

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
                pendingDownloadModelID = row.modelID
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

    private func downloadPreview(for row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("settings.models.download.approvalRequired"))
                .font(compactModelStatusFont)
                .fontWeight(.semibold)

            Text("\(row.displayName) · \(row.downloadApprovalText)")
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(row.manifestTransparencyText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.9))
                .lineLimit(2)

            Text(row.licenseApprovalText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.9))
                .lineLimit(2)
                .accessibilityIdentifier("settings.models.\(row.modelID).license-approval")

            Text(row.storagePolicyText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.9))
                .lineLimit(2)

            Text(row.purposeBoundaryText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.9))
                .lineLimit(2)

            HStack(spacing: 8) {
                compactActionButton(
                    KairoL10n.string("settings.models.download.confirm"),
                    systemImage: "checkmark.circle",
                    accessibilityIdentifier: "settings.models.\(row.modelID).download-confirm",
                    tint: .blue
                ) {
                    pendingDownloadModelID = nil
                    downloadLocalModel(row)
                }

                compactActionButton(
                    KairoL10n.string("settings.models.download.cancel"),
                    systemImage: "xmark.circle",
                    accessibilityIdentifier: "settings.models.\(row.modelID).download-cancel",
                    tint: .secondary
                ) {
                    pendingDownloadModelID = nil
                }
            }
        }
        .padding(10)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(KairoDesign.blue.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).download-preview")
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
}
#endif
