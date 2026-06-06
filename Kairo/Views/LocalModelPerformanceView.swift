#if canImport(SwiftUI)
import SwiftUI

struct LocalModelPerformanceView: View {
    let benchmarkService: LocalModelBenchmarkService?
    @State private var snapshot = LocalModelPerformanceSnapshot(totalRunCount: 0)

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if benchmarkService == nil {
                        emptyState(KairoL10n.string("performance.local.unavailable"))
                    } else if snapshot.totalRunCount == 0 {
                        emptyState(KairoL10n.string("performance.local.empty"))
                    } else {
                        overviewCard
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
            snapshot = await benchmarkService?.performanceSnapshot() ?? LocalModelPerformanceSnapshot(totalRunCount: 0)
        }
        .accessibilityIdentifier("performance.local.screen")
    }

    private var overviewCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(KairoL10n.string("performance.local.overview"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricTile(KairoL10n.string("performance.local.runs"), "\(snapshot.totalRunCount)")
                    metricTile(KairoL10n.string("performance.local.kvHitRate"), formattedPercent(snapshot.kvCacheHitRate))
                    metricTile(KairoL10n.string("performance.local.pp"), formattedRate(snapshot.averagePromptTokensPerSecond))
                    metricTile(KairoL10n.string("performance.local.tk"), formattedRate(snapshot.averageGenerationTokensPerSecond))
                    metricTile(KairoL10n.string("performance.local.firstToken"), formattedLatency(snapshot.averageFirstTokenLatencyMS))
                    metricTile(KairoL10n.string("performance.local.peakMemory"), formattedMemory(snapshot.peakMemoryMB))
                }
            }
        }
        .accessibilityIdentifier("performance.local.overview")
    }

    private var modelBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("performance.local.models"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            KairoGroupedSurface {
                ForEach(snapshot.modelSummaries) { summary in
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
                            compactMetric(KairoL10n.string("performance.local.pp"), formattedRate(summary.averagePromptTokensPerSecond))
                            compactMetric(KairoL10n.string("performance.local.tk"), formattedRate(summary.averageGenerationTokensPerSecond))
                            compactMetric(KairoL10n.string("performance.local.kvHitRate"), formattedPercent(summary.kvCacheHitRate))
                        }
                        HStack(spacing: 8) {
                            compactMetric(KairoL10n.string("performance.local.firstToken"), formattedLatency(summary.averageFirstTokenLatencyMS))
                            compactMetric(KairoL10n.string("performance.local.peakMemory"), formattedMemory(summary.peakMemoryMB))
                        }
                    }
                    .padding(.vertical, 10)
                    .accessibilityIdentifier("performance.local.model.\(summary.modelID)")

                    if summary.id != snapshot.modelSummaries.last?.id {
                        Divider()
                    }
                }
            }
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

    private func formattedNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
    }
}
#endif
