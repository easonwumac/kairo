#if canImport(SwiftUI)
import SwiftUI

struct LocalModelsCompactView: View {
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
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Local Models")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("settings.models.local")

                    Text("Downloadable, user-approved on-device models. Weights stay outside the app bundle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                compactLocalModelControls

                VStack(alignment: .leading, spacing: 10) {
                    if localModelStatus.settingsRows.isEmpty {
                        Text("尚未載入 local model catalog。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(localModelStatus.settingsRows) { row in
                        compactLocalModelRow(row)
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
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 32)
            .accessibilityIdentifier("settings.models.local")
        }
        .scrollIndicators(.visible)
        .background(Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea())
        .accessibilityIdentifier("settings.models.screen")
    }

    private var compactLocalModelControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Route Preference")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(localModelStatus.preference.settingsDetailText)
                        .font(.caption2)
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
                        .font(.caption2)
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
        .padding(12)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func compactLocalModelRow(_ row: LocalModelSettingsRow) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(row.displayName)
                    .font(compactModelNameFont)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .accessibilityIdentifier("settings.models.\(row.modelID).name")

                Spacer(minLength: 8)

                Text(row.statusText)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(localModelStatusColor(row.primaryAction))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(localModelStatusColor(row.primaryAction).opacity(0.11), in: Capsule())
                    .accessibilityIdentifier("settings.models.\(row.modelID).status")
            }

            Text(row.detailText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let benchmarkSummaryText = row.benchmarkSummaryText {
                Text(benchmarkSummaryText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.models.\(row.modelID).benchmark")
            }

            LazyVGrid(columns: compactButtonGridColumns, alignment: .leading, spacing: 8) {
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("settings.models.benchmark-message")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.models.\(row.modelID).row")
    }

    private var compactButtonGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 118), spacing: 8, alignment: .leading)]
    }

    private var compactModelNameFont: Font { .caption }

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
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.green)
                .accessibilityIdentifier("settings.models.\(row.modelID).select")
        case .unavailable:
            Text(row.primaryAction.title)
                .font(.caption)
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
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .center)
                .foregroundStyle(tint)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
#endif
