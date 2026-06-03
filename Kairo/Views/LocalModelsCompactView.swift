#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
    private let starterModelRowLimit = 2
    @State private var showsAllModelRows = false

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
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Models")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("settings.models.local")

                    Text("Starter list: Qwen plus one popular alternative. Downloads stay user-approved and outside the app bundle.")
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

                    if hiddenModelRowCount > 0 || showsAllModelRows {
                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showsAllModelRows.toggle()
                            }
                        } label: {
                            Label(modelListToggleTitle, systemImage: showsAllModelRows ? "chevron.up" : "chevron.down")
                                .font(compactButtonLabelFont)
                                .imageScale(.small)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .foregroundStyle(.blue)
                                .background(Color.blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(modelListToggleTitle)
                        .accessibilityIdentifier("settings.models.show-more")
                    }

                    if localModelStatusMessageModelID == nil, let localModelStatusMessage {
                        Text(localModelStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                            .accessibilityIdentifier("settings.models.benchmark-message")
                    }
                }
                .accessibilityIdentifier("settings.models.compact-list")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
            .accessibilityIdentifier("settings.models.local")
        }
        .scrollIndicators(.visible)
        .background(Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea())
        .accessibilityIdentifier("settings.models.screen")
    }

    private var compactLocalModelControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Route Preference")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(localModelStatus.preference.settingsDetailText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

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
                .font(.caption)
                .accessibilityIdentifier("settings.models.preference")
            }

            Divider()

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Catalog")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(localModelCatalogSourceText)
                        .font(compactModelMetadataFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("settings.models.catalog-source")
                }

                Spacer(minLength: 12)

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
        .padding(9)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(localModelCatalogSourceText)
        .accessibilityIdentifier("settings.models.catalog-source")
    }

    private var selectedModelSummary: some View {
        HStack(alignment: .center, spacing: 10) {
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
        .padding(9)
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
        if showsAllModelRows {
            return localModelStatus.settingsRows
        }
        return Array(localModelStatus.settingsRows.prefix(starterModelRowLimit))
    }

    private var hiddenModelRowCount: Int {
        max(localModelStatus.settingsRows.count - starterModelRowLimit, 0)
    }

    private var modelListToggleTitle: String {
        showsAllModelRows ? "Show starter set" : "Show \(hiddenModelRowCount) more popular"
    }

    @ViewBuilder
    private func compactLocalModelRow(_ row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(row.displayName)
                    .font(compactModelNameFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .accessibilityIdentifier("settings.models.\(row.modelID).name")

                Spacer(minLength: 8)

                Text(row.statusText)
                    .font(compactModelStatusFont)
                    .foregroundStyle(localModelStatusColor(row.primaryAction))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(localModelStatusColor(row.primaryAction).opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            Text(row.detailText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Text(row.manifestTransparencyText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.85))
                .lineLimit(2)
                .truncationMode(.tail)
                .accessibilityIdentifier("settings.models.\(row.modelID).manifest")

            Text(row.runtimeFitText)
                .font(compactModelMetadataFont)
                .foregroundStyle(.secondary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.tail)
                .accessibilityIdentifier("settings.models.\(row.modelID).runtime-fit")

            if let benchmarkSummaryText = row.benchmarkSummaryText {
                Text(benchmarkSummaryText)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .accessibilityIdentifier("settings.models.\(row.modelID).benchmark")
            }

            LazyVGrid(columns: compactButtonGridColumns, alignment: .leading, spacing: 5) {
                compactLocalModelAction(for: row)

                if row.benchmarkSummaryText != nil {
                    compactActionButton(
                        "Benchmark",
                        systemImage: "speedometer",
                        accessibilityIdentifier: "settings.models.\(row.modelID).benchmark-run",
                        tint: .blue
                    ) {
                        runLocalModelBenchmark(row)
                    }
                }

                compactActionButton(
                    "Reply Check",
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

            if localModelStatusMessageModelID == row.modelID, let localModelStatusMessage {
                Text(localModelStatusMessage)
                    .font(compactModelMetadataFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.models.benchmark-message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(6)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).row")
    }

    private var compactButtonGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 72), spacing: 4, alignment: .leading)]
    }

    private var compactModelNameFont: Font { .system(size: 8, weight: .semibold) }

    private var compactModelMetadataFont: Font { .system(size: 7) }

    private var compactModelStatusFont: Font { .system(size: 7, weight: .semibold) }

    private var compactButtonLabelFont: Font { .system(size: 7, weight: .semibold) }

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
                .accessibilityIdentifier("settings.models.\(row.modelID).select")
        case .unavailable:
            Text(row.primaryAction.title)
                .font(compactButtonLabelFont)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("settings.models.\(row.modelID).unavailable")
        }
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
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(tint)
                .background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
#endif
