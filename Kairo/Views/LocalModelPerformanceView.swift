#if canImport(SwiftUI)
import SwiftUI

struct LocalModelPerformanceView: View {
    let benchmarkService: LocalModelBenchmarkService?
    let settingsService: LocalModelSettingsService?
    @State private var snapshot = LocalModelPerformanceSnapshot(totalRunCount: 0)
    @State private var selectedModelID: String?
    @State private var statusMessage: String?
    @State private var isScopePalettePresented = false

    private var displayedSnapshot: LocalModelPerformanceSnapshot {
        snapshot.filtered(to: selectedModelID)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                performanceContent
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

    @ViewBuilder
    private var performanceContent: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                performanceStack
            }
        } else {
            performanceStack
        }
    }

    private var performanceStack: some View {
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
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(overviewTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                metricTile(KairoL10n.string("performance.local.prefillTokens"), "\(displayedSnapshot.prefillTokenCount)")
                metricTile(KairoL10n.string("performance.local.cachedTokens"), "\(displayedSnapshot.cachedTokenCount)")
                metricTile(KairoL10n.string("performance.local.cacheEfficiency"), formattedCacheEfficiency)
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
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                .disabled(displayedSnapshot.cacheUsedBytes == 0)
                .accessibilityIdentifier("performance.local.clearCache")
            }
        }
        .padding(16)
        .localPerformanceGlassSurface(tint: KairoDesign.blue)
        .accessibilityIdentifier("performance.local.overview")
    }

    @ViewBuilder
    private var modelScopePicker: some View {
        if !snapshot.modelSummaries.isEmpty {
            VStack(spacing: 7) {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                        isScopePalettePresented.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speedometer")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                        Text(KairoL10n.string("performance.local.scope"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KairoDesign.muted)
                        Text(scopeTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KairoDesign.muted)
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .localPerformanceGlassCapsule(isInteractive: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("performance.local.scope")

                if isScopePalettePresented {
                    VStack(spacing: 7) {
                        scopeButton(
                            title: KairoL10n.string("performance.local.allModels"),
                            isSelected: selectedModelID == nil
                        ) {
                            selectedModelID = nil
                            isScopePalettePresented = false
                        }
                        ForEach(snapshot.modelSummaries) { summary in
                            scopeButton(
                                title: summary.modelDisplayName,
                                isSelected: selectedModelID == summary.modelID
                            ) {
                                selectedModelID = summary.modelID
                                isScopePalettePresented = false
                            }
                        }
                    }
                    .padding(8)
                    .localPerformanceGlassSurface(tint: KairoDesign.blue, cornerRadius: 18, shadowRadius: 14, shadowY: 9)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityIdentifier("performance.local.scope.palette")
                }
            }
            .animation(.spring(response: 0.24, dampingFraction: 0.88), value: isScopePalettePresented)
        }
    }

    private var scopeTitle: String {
        guard let selectedModelID,
              let summary = snapshot.modelSummaries.first(where: { $0.modelID == selectedModelID }) else {
            return KairoL10n.string("performance.local.allModels")
        }
        return summary.modelDisplayName
    }

    private func scopeButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(KairoDesign.blue)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .localPerformanceGlassRow(tint: isSelected ? KairoDesign.blue : KairoDesign.muted, fallbackOpacity: isSelected ? 0.70 : 0.55)
        }
        .buttonStyle(.plain)
    }

    private var overviewTitle: String {
        guard let selectedModelID,
              let summary = snapshot.modelSummaries.first(where: { $0.modelID == selectedModelID }) else {
            return KairoL10n.string("performance.local.overview")
        }
        return summary.modelDisplayName
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
        .localPerformanceGlassSurface(tint: KairoDesign.teal, cornerRadius: 12, fallbackOpacity: 0.52, shadowRadius: 0, shadowY: 0)
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        Text("\(title) \(value)")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(KairoDesign.muted)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .localPerformanceGlassCapsule()
    }

    private func emptyState(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "speedometer")
                .font(.headline.weight(.semibold))
                .foregroundStyle(KairoDesign.blue)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .localPerformanceGlassSurface(tint: KairoDesign.blue)
    }

    private func formattedRate(_ value: Double?) -> String {
        guard let value else { return "--" }
        return "\(formattedNumber(value)) tok/s"
    }

    private func formattedRate(_ value: Double) -> String {
        "\(formattedNumber(value)) tok/s"
    }

    private func formattedPercent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var formattedCacheEfficiency: String {
        guard displayedSnapshot.cachedTokenCount > 0 else { return "--" }
        return formattedPercent(displayedSnapshot.kvCacheHitRate)
    }

    private func formattedLatency(_ value: Double?) -> String {
        guard let value else { return "--" }
        if value >= 1000 {
            return String(format: "%.2fs", value / 1000.0)
        }
        return "\(Int(value.rounded()))ms"
    }

    private func formattedMemory(_ value: Int?) -> String {
        guard let value else { return "--" }
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

private extension View {
    @ViewBuilder
    func localPerformanceGlassSurface(
        tint: Color,
        cornerRadius: CGFloat = 20,
        fallbackOpacity: Double = 0.66,
        shadowRadius: CGFloat = 18,
        shadowY: CGFloat = 11
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint.opacity(0.09)), in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    shape.stroke(KairoDesign.line.opacity(0.58), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(shadowRadius > 0 ? 0.24 : 0), radius: shadowRadius, x: 0, y: shadowY)
        } else {
            self
                .background(KairoDesign.elevatedSurface.opacity(fallbackOpacity), in: shape)
                .overlay {
                    shape.stroke(KairoDesign.line.opacity(0.74), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(shadowRadius > 0 ? 0.34 : 0), radius: shadowRadius, x: 0, y: shadowY)
        }
    }

    @ViewBuilder
    func localPerformanceGlassRow(tint: Color, fallbackOpacity: Double) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 12))
                .overlay {
                    shape.stroke(Color.white.opacity(0.06), lineWidth: 1)
                }
        } else {
            self
                .background(KairoDesign.softSurface.opacity(fallbackOpacity), in: shape)
        }
    }

    @ViewBuilder
    func localPerformanceGlassCapsule(isInteractive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(.regular.tint(KairoDesign.blue.opacity(0.10)).interactive(), in: .capsule)
                    .overlay {
                        Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            } else {
                self
                    .glassEffect(.regular.tint(KairoDesign.muted.opacity(0.08)), in: .capsule)
            }
        } else {
            self
                .background(KairoDesign.groupedSurface, in: Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }
}
#endif
