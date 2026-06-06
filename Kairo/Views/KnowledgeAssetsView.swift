#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct KnowledgeAssetsView: View {
    @State private var searchQuery = ""
    @State private var assets: [KnowledgeAsset] = []
    @State private var selectedAsset: KnowledgeAsset?
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var exportText = "{}"
    @State private var iCloudBackupAllowed = false
    @State private var isImporting = false

    @Binding private var rootChromeBackRequestID: Int
    private let usesRootChromeNavigation: Bool
    private let assetAPI: any KairoKnowledgeAssetAPI

    public init(
        dependencies: KnowledgeAssetFeatureDependencies,
        rootChromeBackRequestID: Binding<Int> = .constant(0),
        usesRootChromeNavigation: Bool = false
    ) {
        self.assetAPI = dependencies.assetAPI
        self._rootChromeBackRequestID = rootChromeBackRequestID
        self.usesRootChromeNavigation = usesRootChromeNavigation
    }

    public init(
        assetAPI: any KairoKnowledgeAssetAPI,
        rootChromeBackRequestID: Binding<Int> = .constant(0),
        usesRootChromeNavigation: Bool = false
    ) {
        self.init(
            dependencies: KnowledgeAssetFeatureDependencyFactory().makeDependencies(assetAPI: assetAPI),
            rootChromeBackRequestID: rootChromeBackRequestID,
            usesRootChromeNavigation: usesRootChromeNavigation
        )
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    if let selectedAsset {
                        assetDetail(selectedAsset)
                    } else {
                        assetLibrary
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
                .padding(.bottom, 32)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .kairoHiddenNavigationChrome()
            .task(id: searchQuery) { await reload() }
            .refreshable { await reload() }
            .preference(key: RootChromePreferenceKey.self, value: rootChromeContext)
            .onChange(of: rootChromeBackRequestID) { _, _ in
                selectedAsset = nil
            }
        }
    }

    private var rootChromeContext: RootChromeContext {
        guard usesRootChromeNavigation, let selectedAsset else {
            return .standard
        }
        return RootChromeContext(
            leadingAction: .back,
            title: selectedAsset.title
        )
    }

    private var assetLibrary: some View {
        VStack(alignment: .leading, spacing: 14) {
            importControls
            searchCard

            if let statusMessage {
                statusCard(statusMessage, systemImage: "checkmark.circle.fill", tint: KairoDesign.green)
                    .accessibilityIdentifier("knowledgeAssets.status")
            }

            if let errorMessage {
                statusCard(errorMessage, systemImage: "exclamationmark.triangle.fill", tint: KairoDesign.red)
                    .accessibilityIdentifier("knowledgeAssets.error")
            }

            if assets.isEmpty {
                emptyState
            } else {
                ForEach(assets) { asset in
                    assetCard(asset)
                }
            }
        }
        .accessibilityIdentifier("knowledgeAssets.library")
    }

    private var importControls: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KairoDesign.teal)
                        .frame(width: 34, height: 34)
                        .background(KairoDesign.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(KairoL10n.string("knowledgeAssets.capture.title"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                        Text(KairoL10n.string("knowledgeAssets.capture.subtitle"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }

                Toggle(isOn: $iCloudBackupAllowed) {
                    Label(
                        KairoL10n.string("knowledgeAssets.backup.toggle"),
                        systemImage: iCloudBackupAllowed ? "icloud.fill" : "icloud.slash.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(iCloudBackupAllowed ? KairoDesign.blue : KairoDesign.green)
                }
                .tint(KairoDesign.blue)
                .accessibilityIdentifier("knowledgeAssets.backup.toggle")

                Button {
                    importPendingShares()
                } label: {
                    Label(
                        isImporting ? KairoL10n.string("knowledgeAssets.import.running") : KairoL10n.string("knowledgeAssets.import.pending"),
                        systemImage: "square.and.arrow.down"
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.teal, isProminent: true))
                .disabled(isImporting)
                .accessibilityIdentifier("knowledgeAssets.import.pending")
            }
        }
    }

    private var searchCard: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)

                    TextField(KairoL10n.string("knowledgeAssets.search.placeholder"), text: $searchQuery)
                        .accessibilityIdentifier("knowledgeAssets.search.text")

                    if !trimmedSearchQuery.isEmpty {
                        Button(KairoL10n.string("knowledgeAssets.search.clear")) { searchQuery = "" }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                            .accessibilityIdentifier("knowledgeAssets.search.clear")
                    }
                }

                HStack(spacing: 8) {
                    KairoStatusPill(
                        title: searchSummary,
                        systemImage: "archivebox.fill",
                        tint: KairoDesign.teal
                    )

                    ShareLink(item: exportText) {
                        Label(KairoL10n.string("knowledgeAssets.export"), systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
                    .disabled(assets.isEmpty)
                    .accessibilityIdentifier("knowledgeAssets.export")
                }
            }
        }
    }

    private var emptyState: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text(trimmedSearchQuery.isEmpty ? KairoL10n.string("knowledgeAssets.empty.title") : KairoL10n.string("knowledgeAssets.search.empty.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .accessibilityIdentifier("knowledgeAssets.empty")
                Text(trimmedSearchQuery.isEmpty ? KairoL10n.string("knowledgeAssets.empty.subtitle") : KairoL10n.string("knowledgeAssets.search.empty.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 10)
        }
    }

    private func assetCard(_ asset: KnowledgeAsset) -> some View {
        Button {
            selectedAsset = asset
        } label: {
            HStack(alignment: .top, spacing: 12) {
                KnowledgeAssetThumbnail(asset: asset, size: 62)

                VStack(alignment: .leading, spacing: 8) {
                    Text(asset.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(asset.summary.isEmpty ? KairoL10n.string("knowledgeAssets.summary.empty") : asset.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    assetPills(asset)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .padding(14)
            .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KairoDesign.line, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("knowledgeAssets.asset.card")
    }

    private func assetDetail(_ asset: KnowledgeAsset) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            KairoFocusCard {
                VStack(alignment: .leading, spacing: 12) {
                    KnowledgeAssetThumbnail(asset: asset, size: 148)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Text(asset.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(asset.summary.isEmpty ? KairoL10n.string("knowledgeAssets.summary.empty") : asset.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    assetPills(asset)
                }
            }

            if !asset.checklistItems.isEmpty {
                detailSection(title: KairoL10n.string("knowledgeAssets.detail.checklist"), systemImage: "checklist.checked") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(asset.checklistItems) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(item.isCompleted ? KairoDesign.green : KairoDesign.muted)
                                Text(item.title)
                                    .font(.caption)
                                    .foregroundStyle(KairoDesign.ink)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }

            if !asset.proposedActions.isEmpty {
                detailSection(title: KairoL10n.string("knowledgeAssets.detail.actions"), systemImage: "wand.and.sparkles") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(asset.proposedActions) { action in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "doc.badge.clock")
                                    .foregroundStyle(KairoDesign.amber)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(action.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KairoDesign.ink)
                                    Text(action.rationale)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
            }

            if !asset.extractedText.isEmpty {
                detailSection(title: KairoL10n.string("knowledgeAssets.detail.extractedText"), systemImage: "text.viewfinder") {
                    Text(asset.extractedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            detailSection(title: KairoL10n.string("knowledgeAssets.detail.storage"), systemImage: "externaldrive.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    KairoStatusPill(
                        title: asset.iCloudBackupAllowed ? KairoL10n.string("knowledgeAssets.backup.allowed") : KairoL10n.string("knowledgeAssets.backup.localOnly"),
                        systemImage: asset.iCloudBackupAllowed ? "icloud.fill" : "lock.shield.fill",
                        tint: asset.iCloudBackupAllowed ? KairoDesign.blue : KairoDesign.green
                    )

                    Button {
                        delete(asset)
                    } label: {
                        Label(KairoL10n.string("knowledgeAssets.delete"), systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.red, isCompact: true))
                    .accessibilityIdentifier("knowledgeAssets.delete")
                }
            }
        }
        .accessibilityIdentifier("knowledgeAssets.detail")
    }

    private func detailSection<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                content()
            }
        }
    }

    private func assetPills(_ asset: KnowledgeAsset) -> some View {
        HStack(spacing: 7) {
            KairoStatusPill(title: kindLabel(for: asset.kind), systemImage: kindIcon(for: asset.kind), tint: KairoDesign.blue)
            KairoStatusPill(title: asset.attachments.count.formatted(), systemImage: "paperclip", tint: KairoDesign.teal)
            if !asset.checklistItems.isEmpty {
                KairoStatusPill(title: asset.checklistItems.count.formatted(), systemImage: "checklist", tint: KairoDesign.amber)
            }
        }
    }

    private func statusCard(_ message: String, systemImage: String, tint: Color) -> some View {
        KairoGroupedSurface {
            Label(message, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchSummary: String {
        if trimmedSearchQuery.isEmpty {
            return KairoL10n.string(
                assets.count == 1 ? "knowledgeAssets.count.one" : "knowledgeAssets.count.many",
                Int64(assets.count)
            )
        }
        return KairoL10n.string(
            assets.count == 1 ? "knowledgeAssets.search.count.one" : "knowledgeAssets.search.count.many",
            Int64(assets.count),
            trimmedSearchQuery
        )
    }

    private func reload() async {
        do {
            let query = trimmedSearchQuery
            let loaded = query.isEmpty
                ? try await assetAPI.list(limit: 100)
                : try await assetAPI.search(query: query, limit: 100)
            let export = try await assetAPI.export(limit: 500)
            let exportText = try Self.exportText(for: export)
            await MainActor.run {
                assets = loaded
                self.exportText = exportText
                errorMessage = nil
                if let selectedAssetID = selectedAsset?.id {
                    selectedAsset = loaded.first { $0.id == selectedAssetID } ?? selectedAsset
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func importPendingShares() {
        isImporting = true
        statusMessage = nil
        errorMessage = nil

        Task {
            do {
                let result = try await assetAPI.importPendingShares(limit: 20, iCloudBackupAllowed: iCloudBackupAllowed)
                await reload()
                await MainActor.run {
                    isImporting = false
                    statusMessage = KairoL10n.string(
                        result.assets.count == 1 ? "knowledgeAssets.import.result.one" : "knowledgeAssets.import.result.many",
                        Int64(result.assets.count)
                    )
                }
            } catch {
                await MainActor.run {
                    isImporting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func delete(_ asset: KnowledgeAsset) {
        Task {
            do {
                try await assetAPI.delete(id: asset.id)
                await reload()
                await MainActor.run {
                    selectedAsset = nil
                    statusMessage = KairoL10n.string("knowledgeAssets.delete.result")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func kindLabel(for kind: KnowledgeAssetKind) -> String {
        switch kind {
        case .screenshot:
            return KairoL10n.string("knowledgeAssets.kind.screenshot")
        case .image:
            return KairoL10n.string("knowledgeAssets.kind.image")
        case .text:
            return KairoL10n.string("knowledgeAssets.kind.text")
        case .url:
            return KairoL10n.string("knowledgeAssets.kind.url")
        case .pdf:
            return KairoL10n.string("knowledgeAssets.kind.pdf")
        case .file:
            return KairoL10n.string("knowledgeAssets.kind.file")
        case .note:
            return KairoL10n.string("knowledgeAssets.kind.note")
        }
    }

    private func kindIcon(for kind: KnowledgeAssetKind) -> String {
        switch kind {
        case .screenshot, .image:
            return "photo.fill"
        case .text, .note:
            return "text.alignleft"
        case .url:
            return "link"
        case .pdf:
            return "doc.richtext.fill"
        case .file:
            return "doc.fill"
        }
    }

    private static func exportText(for export: KnowledgeAssetExport) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

private struct KnowledgeAssetThumbnail: View {
    let asset: KnowledgeAsset
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(KairoDesign.softSurface.opacity(0.82))

            if let image = localImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(KairoDesign.teal)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private var fallbackIcon: String {
        switch asset.kind {
        case .screenshot, .image:
            return "photo"
        case .pdf:
            return "doc.richtext"
        case .url:
            return "link"
        case .text, .note:
            return "text.alignleft"
        case .file:
            return "doc"
        }
    }

    private var localImage: Image? {
        guard asset.kind == .screenshot || asset.kind == .image else { return nil }
        guard let fileURL = asset.attachments.first(where: { $0.kind == .image })?.fileURL else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: fileURL.path) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(contentsOf: fileURL) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}
#endif
