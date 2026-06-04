#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
    private let starterModelIDs = LocalModelCatalog.kairoStarterModelIDs
    @State private var pendingDownloadModelID: String?

    let localModelStatus: LocalModelSettingsStatus
    let localModelDownloadProgress: LocalModelDownloadProgressState?
    let localModelStatusMessage: String?
    let localModelStatusMessageModelID: String?
    let localModelCatalogSourceText: String
    let localModelStatusColor: (LocalModelSettingsPrimaryAction) -> Color
    let setLocalModelPreference: (ProviderRoutePreference) -> Void
    let refreshLocalModelCatalog: () -> Void
    let downloadLocalModel: (LocalModelSettingsRow) -> Void
    let cancelLocalModelDownload: (LocalModelSettingsRow) -> Void
    let selectLocalModel: (LocalModelSettingsRow) -> Void
    let runLocalModelBenchmark: (LocalModelSettingsRow) -> Void
    let runLocalModelReplyCheck: (LocalModelSettingsRow) -> Void
    let deleteLocalModel: (LocalModelSettingsRow) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KairoL10n.string("settings.models.section"))
                        .font(compactSectionTitleFont)
                        .accessibilityIdentifier("settings.models.local")

                    Text(KairoL10n.string("settings.models.compact.subtitle"))
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                compactLocalModelControls

                selectedModelSummary

                VStack(alignment: .leading, spacing: 8) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.visible)
        .background(Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea())
        .accessibilityIdentifier("settings.models.screen")
    }

    private var compactLocalModelControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(KairoL10n.string("settings.models.routePreference"))
                        .font(compactSectionHeadingFont)

                    Text(localModelStatus.preference.settingsDetailText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 10)

                compactRoutePreferenceMenu
            }

            Divider()

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(KairoL10n.string("settings.models.catalog"))
                        .font(compactSectionHeadingFont)

                    Text(localModelCatalogSourceText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("settings.models.catalog-source")
                }

                Spacer(minLength: 10)

                compactActionButton(
                    KairoL10n.string("settings.models.refresh"),
                    systemImage: "arrow.clockwise",
                    accessibilityIdentifier: "settings.models.refresh-catalog",
                    tint: .blue,
                    action: refreshLocalModelCatalog
                )
                .accessibilityLabel(KairoL10n.string("settings.models.refreshCatalog"))
            }
        }
        .padding(8)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localModelCatalogSourceText)
        .accessibilityIdentifier("settings.models.catalog-card")
    }

    private var selectedModelSummary: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: selectedModelSummaryIconName)
                .font(.subheadline)
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

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(selectedModelSummaryText)
        .accessibilityIdentifier("settings.models.selected-summary")
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
                    .font(.system(size: 6.5, weight: .semibold))
            }
            .foregroundStyle(.blue)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KairoL10n.string("settings.models.routePreference"))
        .accessibilityIdentifier("settings.models.preference")
    }

    @ViewBuilder
    private func compactLocalModelRow(_ row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(row.displayName)
                    .font(compactModelNameFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .accessibilityIdentifier("settings.models.\(row.modelID).name")

                Spacer(minLength: 6)

                Text(row.statusText)
                    .font(compactModelStatusFont)
                    .foregroundStyle(localModelStatusColor(row.primaryAction))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(localModelStatusColor(row.primaryAction).opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            Text(row.detailText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            runtimePills(for: row)

            Text(row.manifestTransparencyText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.85))
                .lineLimit(1)
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

            LazyVGrid(columns: compactButtonGridColumns, alignment: .leading, spacing: 4) {
                compactLocalModelAction(for: row)

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
        .padding(5)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).row")
    }

    private func runtimePills(for row: LocalModelSettingsRow) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(row.runtimePillTexts.enumerated()), id: \.offset) { index, text in
                Text(text)
                    .font(compactModelMetadataFont)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
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
        [GridItem(.adaptive(minimum: 52), spacing: 4, alignment: .leading)]
    }

    private var compactSectionTitleFont: Font { .system(size: 10, weight: .semibold) }

    private var compactSectionHeadingFont: Font { .system(size: 7, weight: .semibold) }

    private var compactModelNameFont: Font { .system(size: 7, weight: .semibold) }

    private var compactModelMetadataFont: Font { .system(size: 6) }

    private var compactModelStatusFont: Font { .system(size: 6, weight: .semibold) }

    private var compactButtonLabelFont: Font { .system(size: 6, weight: .semibold) }

    private var compactControlValueFont: Font { .system(size: 8, weight: .semibold) }

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
                .accessibilityIdentifier("settings.models.\(row.modelID).select")
        case .unavailable:
            Text(row.primaryAction.title)
                .font(compactButtonLabelFont)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.models.\(row.modelID).unavailable")
        }
    }

    private func downloadPreview(for row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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

            HStack(spacing: 6) {
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
        .padding(6)
        .background(Color.blue.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.blue.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).download-preview")
    }

    private func downloadProgressView(_ progress: LocalModelDownloadProgressState, row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
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
        .padding(6)
        .background(Color.orange.opacity(0.055), in: RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.orange.opacity(0.14), lineWidth: 1)
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
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(tint)
                .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
#endif
