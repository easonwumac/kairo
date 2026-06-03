#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
    private let popularModelRowLimit = 2
    @State private var pendingDownloadModelID: String?

    let localModelStatus: LocalModelSettingsStatus
    let localModelStatusMessage: String?
    let localModelStatusMessageModelID: String?
    let localModelCatalogSourceText: String
    let localModelStatusColor: (LocalModelSettingsPrimaryAction) -> Color
    let setLocalModelPreference: (ProviderRoutePreference) -> Void
    let refreshLocalModelCatalog: () -> Void
    let downloadLocalModel: (LocalModelSettingsRow) -> Void
    let selectLocalModel: (LocalModelSettingsRow) -> Void
    let runLocalModelBenchmark: (LocalModelSettingsRow) -> Void
    let runLocalModelReplyCheck: (LocalModelSettingsRow) -> Void
    let deleteLocalModel: (LocalModelSettingsRow) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Models")
                        .font(compactSectionTitleFont)
                        .accessibilityIdentifier("settings.models.local")

                    Text("Popular starters only: Qwen + Llama. Full catalog stays in kairo-models.")
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                compactLocalModelControls

                selectedModelSummary

                VStack(alignment: .leading, spacing: 8) {
                    if visibleModelRows.isEmpty {
                        Text("尚未載入 local model catalog。")
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
                    Text("Route Preference")
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
                    Text("Catalog")
                        .font(compactSectionHeadingFont)

                    Text(localModelCatalogSourceText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("settings.models.catalog-source")
                }

                Spacer(minLength: 10)

                compactActionButton(
                    "Refresh",
                    systemImage: "arrow.clockwise",
                    accessibilityIdentifier: "settings.models.refresh-catalog",
                    tint: .blue,
                    action: refreshLocalModelCatalog
                )
                .accessibilityLabel("Refresh Catalog")
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
                Text("Selected model")
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
            return "\(selectedModel.displayName) is active for eligible local tasks."
        }
        if let downloadedModel {
            return "\(downloadedModel.displayName) is downloaded. Select it to use local routing."
        }
        return "No downloaded model selected yet."
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
        Array(localModelStatus.settingsRows.prefix(popularModelRowLimit))
    }

    private var trimmedModelRowCount: Int {
        max(localModelStatus.settingsRows.count - popularModelRowLimit, 0)
    }

    private var trimmedModelSummaryText: String {
        "Showing \(visibleModelRows.count) popular starter models only. Full catalog stays in kairo-models."
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
        .accessibilityLabel("Route Preference")
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
                        "Speed",
                        systemImage: "speedometer",
                        accessibilityIdentifier: "settings.models.\(row.modelID).benchmark-run",
                        tint: .blue
                    ) {
                        runLocalModelBenchmark(row)
                    }
                }

                compactActionButton(
                    "Reply",
                    systemImage: "text.bubble",
                    accessibilityIdentifier: "settings.models.\(row.modelID).reply-check",
                    tint: .blue
                ) {
                    runLocalModelReplyCheck(row)
                }

                if row.canDelete {
                    compactActionButton(
                        "Delete",
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

    private var compactSectionTitleFont: Font { .system(size: 12, weight: .semibold) }

    private var compactSectionHeadingFont: Font { .system(size: 8, weight: .semibold) }

    private var compactModelNameFont: Font { .system(size: 8, weight: .semibold) }

    private var compactModelMetadataFont: Font { .system(size: 7) }

    private var compactModelStatusFont: Font { .system(size: 7, weight: .semibold) }

    private var compactButtonLabelFont: Font { .system(size: 7, weight: .semibold) }

    private var compactControlValueFont: Font { .system(size: 9, weight: .semibold) }

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
            Text("Download requires explicit approval.")
                .font(compactModelStatusFont)
                .fontWeight(.semibold)

            Text("\(row.displayName) · \(row.detailText)")
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Text(row.manifestTransparencyText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.9))
                .lineLimit(2)

            HStack(spacing: 6) {
                compactActionButton(
                    "Confirm Download",
                    systemImage: "checkmark.circle",
                    accessibilityIdentifier: "settings.models.\(row.modelID).download-confirm",
                    tint: .blue
                ) {
                    pendingDownloadModelID = nil
                    downloadLocalModel(row)
                }

                compactActionButton(
                    "Cancel",
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
