#if canImport(SwiftUI)
import SwiftUI

struct LocalModelPerformanceView: View {
    let benchmarkService: LocalModelBenchmarkService?
    let settingsService: LocalModelSettingsService?
    @State private var snapshot = LocalModelPerformanceSnapshot(totalRunCount: 0)
    @State private var selectedModelID: String?
    @State private var statusMessage: String?

    private var displayedSnapshot: LocalModelPerformanceSnapshot {
        snapshot.filtered(to: selectedModelID)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    modelScopePicker
                    overviewCard

                    if let statusMessage {
                        Text(statusMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.muted)
                            .accessibilityIdentifier("performance.local.status")
                    }

                    if benchmarkService == nil {
                        emptyState(KairoL10n.string("performance.local.unavailable"))
                    } else if displayedSnapshot.totalRunCount > 0 {
                        modelBreakdown
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(KairoDesign.background.ignoresSafeArea())
        }
        .task {
            await reloadSnapshot()
        }
        .accessibilityIdentifier("performance.local.screen")
    }

    private var overviewCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(overviewTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricTile(KairoL10n.string("performance.local.prefillTokens"), "\(displayedSnapshot.prefillTokenCount)")
                    metricTile(KairoL10n.string("performance.local.cachedTokens"), "\(displayedSnapshot.cachedTokenCount)")
                    metricTile(KairoL10n.string("performance.local.cacheEfficiency"), formattedPercent(displayedSnapshot.kvCacheHitRate))
                    metricTile(KairoL10n.string("performance.local.pp"), formattedRate(displayedSnapshot.averagePromptTokensPerSecond))
                    metricTile(KairoL10n.string("performance.local.tk"), formattedRate(displayedSnapshot.averageGenerationTokensPerSecond))
                    metricTile(KairoL10n.string("performance.local.cacheStorage"), formattedStorage(displayedSnapshot.cacheUsedBytes, capacity: displayedSnapshot.cacheCapacityBytes))
                    metricTile(KairoL10n.string("performance.local.firstToken"), formattedLatency(displayedSnapshot.averageFirstTokenLatencyMS))
                    metricTile(KairoL10n.string("performance.local.peakMemory"), formattedMemory(displayedSnapshot.peakMemoryMB))
                }

                HStack(spacing: 8) {
                    compactMetric(
                        KairoL10n.string("performance.local.cacheState"),
                        displayedSnapshot.isCacheEnabled
                            ? KairoL10n.string("performance.local.cacheEnabled")
                            : KairoL10n.string("performance.local.cacheDisabled")
                    )
                    Spacer(minLength: 8)
                    Button {
                        Task {
                            await clearCache()
                        }
                    } label: {
                        Label(KairoL10n.string("performance.local.clearCache"), systemImage: "trash")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(displayedSnapshot.cacheUsedBytes == 0)
                    .accessibilityIdentifier("performance.local.clearCache")
                }
            }
        }
        .accessibilityIdentifier("performance.local.overview")
    }

    @ViewBuilder
    private var modelScopePicker: some View {
        if !snapshot.modelSummaries.isEmpty {
            Picker(KairoL10n.string("performance.local.scope"), selection: Binding(
                get: { selectedModelID ?? "all" },
                set: { selectedModelID = $0 == "all" ? nil : $0 }
            )) {
                Text(KairoL10n.string("performance.local.allModels"))
                    .tag("all")
                ForEach(snapshot.modelSummaries) { summary in
                    Text(summary.modelDisplayName)
                        .tag(summary.modelID)
                }
            }
            .pickerStyle(.menu)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(KairoDesign.line, lineWidth: 1)
            }
            .accessibilityIdentifier("performance.local.scope")
        }
    }

    private var overviewTitle: String {
        guard let selectedModelID,
              let summary = snapshot.modelSummaries.first(where: { $0.modelID == selectedModelID }) else {
            return KairoL10n.string("performance.local.overview")
        }
        return summary.modelDisplayName
    }

    private var modelBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("performance.local.models"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            KairoGroupedSurface {
                ForEach(displayedSnapshot.modelSummaries) { summary in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(summary.modelDisplayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            Spacer()
                            Text(KairoL10n.string("performance.local.modelRuns", Int64(summary.runCount)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(KairoDesign.muted)
                        }
                        HStack(spacing: 8) {
                            compactMetric(KairoL10n.string("performance.local.prefillTokens"), "\(summary.prefillTokenCount)")
                            compactMetric(KairoL10n.string("performance.local.cachedTokens"), "\(summary.cachedTokenCount)")
                        }
                        HStack(spacing: 8) {
                            compactMetric(KairoL10n.string("performance.local.pp"), formattedRate(summary.averagePromptTokensPerSecond))
                            compactMetric(KairoL10n.string("performance.local.tk"), formattedRate(summary.averageGenerationTokensPerSecond))
                            compactMetric(KairoL10n.string("performance.local.cacheEfficiency"), formattedPercent(summary.kvCacheHitRate))
                        }
                        HStack(spacing: 8) {
                            compactMetric(KairoL10n.string("performance.local.firstToken"), formattedLatency(summary.averageFirstTokenLatencyMS))
                            compactMetric(KairoL10n.string("performance.local.peakMemory"), formattedMemory(summary.peakMemoryMB))
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("performance.local.model.\(summary.modelID)")

                    if summary.id != displayedSnapshot.modelSummaries.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    @MainActor
    private func reloadSnapshot() async {
        let cacheSettings = await settingsService?.status().cacheSettings ?? .defaultValue
        snapshot = await benchmarkService?.performanceSnapshot(cacheSettings: cacheSettings)
            ?? LocalModelPerformanceSnapshot(
                totalRunCount: 0,
                cacheCapacityBytes: cacheSettings.capacityBytes,
                isCacheEnabled: cacheSettings.isEnabled
            )
    }

    @MainActor
    private func clearCache() async {
        do {
            try await benchmarkService?.clearInferenceCache()
            await reloadSnapshot()
            statusMessage = KairoL10n.string("performance.local.cacheCleared")
        } catch {
            statusMessage = KairoL10n.string("performance.local.cacheClearFailed", error.localizedDescription)
        }
    }

    private func metricTile(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(KairoDesign.muted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        Text("\(title) \(value)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(KairoDesign.muted)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(KairoDesign.groupedSurface, in: Capsule())
    }

    private func emptyState(_ text: String) -> some View {
        KairoFocusCard {
            HStack(spacing: 10) {
                Image(systemName: "speedometer")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func formattedRate(_ value: Double?) -> String {
        guard let value else { return "0 tok/s" }
        return "\(formattedNumber(value)) tok/s"
    }

    private func formattedRate(_ value: Double) -> String {
        "\(formattedNumber(value)) tok/s"
    }

    private func formattedPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func formattedLatency(_ value: Double?) -> String {
        guard let value else { return "0ms" }
        if value >= 1000 {
            return String(format: "%.2fs", value / 1000.0)
        }
        return "\(Int(value.rounded()))ms"
    }

    private func formattedMemory(_ value: Int?) -> String {
        guard let value else { return "0 MB" }
        if value >= 1024 {
            return String(format: "%.2f GB", Double(value) / 1024.0)
        }
        return "\(value) MB"
    }

    private func formattedStorage(_ usedBytes: Int64, capacity: Int64) -> String {
        "\(formattedBytes(usedBytes)) / \(formattedBytes(capacity))"
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        if bytes >= 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        }
        if bytes >= 1_048_576 {
            return "\(Int((Double(bytes) / 1_048_576).rounded())) MB"
        }
        return "\(bytes) B"
    }

    private func formattedNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
#endif
