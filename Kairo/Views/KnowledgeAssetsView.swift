#if canImport(SwiftUI)
import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct KnowledgeAssetsView: View {
    @State private var searchQuery = ""
    @State private var assets: [KnowledgeAsset] = []
    @State private var folders: [KnowledgeAssetFolder] = []
    @State private var selectedAsset: KnowledgeAsset?
    @State private var assetDetailMode: KnowledgeAssetDetailMode = .html
    @State private var selectedKind: KnowledgeAssetKind?
    @State private var selectedFolderName: String?
    @State private var selectedDateFilter: KnowledgeAssetDateFilter = .all
    @State private var newFolderName = ""
    @State private var errorMessage: String?
    @State private var statusMessage: String?
    @State private var isFilterPresented = false

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
            .task(id: reloadToken) { await reload() }
            .refreshable { await reload() }
            .preference(key: RootChromePreferenceKey.self, value: rootChromeContext)
            .onChange(of: rootChromeBackRequestID) { _, _ in
                if selectedAsset != nil, assetDetailMode == .data {
                    assetDetailMode = .html
                } else {
                    selectedAsset = nil
                }
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
            searchCard

            if let statusMessage {
                statusCard(statusMessage, systemImage: "checkmark.circle.fill", tint: KairoDesign.green)
                    .accessibilityIdentifier("knowledgeAssets.status")
            }

            if let errorMessage {
                statusCard(errorMessage, systemImage: "exclamationmark.triangle.fill", tint: KairoDesign.red)
                    .accessibilityIdentifier("knowledgeAssets.error")
            }

            if assets.isEmpty, !trimmedSearchQuery.isEmpty || activeFilterCount > 0 {
                emptyState
            } else {
                ForEach(groupedAssets) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 2)
                            .accessibilityIdentifier("knowledgeAssets.group.\(group.id)")

                        ForEach(group.assets) { asset in
                            assetCard(asset)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("knowledgeAssets.library")
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)

                TextField(KairoL10n.string("knowledgeAssets.search.placeholder"), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("knowledgeAssets.search.text")

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        isFilterPresented.toggle()
                    }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(activeFilterCount > 0 ? KairoDesign.blue : KairoDesign.ink)
                        .frame(width: 28, height: 28)
                        .background(KairoDesign.softSurface.opacity(0.72), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(KairoDesign.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KairoL10n.string("knowledgeAssets.filter.open"))
                .accessibilityIdentifier("knowledgeAssets.filter.open")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(KairoDesign.elevatedSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(KairoDesign.line, lineWidth: 1)
            }

            if isFilterPresented {
                filterControls
            }
        }
    }

    private var filterControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterMenu(
                        title: selectedKind.map(kindLabel(for:)) ?? KairoL10n.string("knowledgeAssets.filter.kind.all"),
                        systemImage: "square.grid.2x2"
                    ) {
                        Button(KairoL10n.string("knowledgeAssets.filter.kind.all")) {
                            selectedKind = nil
                        }
                        ForEach(KnowledgeAssetKind.allCases, id: \.self) { kind in
                            Button(kindLabel(for: kind)) {
                                selectedKind = kind
                            }
                        }
                    }

                    filterMenu(
                        title: selectedDateFilter.title,
                        systemImage: "calendar"
                    ) {
                        ForEach(KnowledgeAssetDateFilter.allCases, id: \.self) { filter in
                            Button(filter.title) {
                                selectedDateFilter = filter
                            }
                        }
                    }

                    filterMenu(
                        title: selectedFolderName ?? KairoL10n.string("knowledgeAssets.filter.folder.all"),
                        systemImage: "folder"
                    ) {
                        Button(KairoL10n.string("knowledgeAssets.filter.folder.all")) {
                            selectedFolderName = nil
                        }
                        ForEach(folderNames, id: \.self) { folderName in
                            Button(folderName) {
                                selectedFolderName = folderName
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField(KairoL10n.string("knowledgeAssets.folder.new.placeholder"), text: $newFolderName)
                    .textFieldStyle(.plain)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("knowledgeAssets.folder.new.text")

                Button {
                    createFolder()
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                }
                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.teal, isCompact: true))
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("knowledgeAssets.folder.new.button")
            }
        }
    }

    private func filterMenu<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
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
            HStack {
                Picker("", selection: $assetDetailMode) {
                    Text(KairoL10n.string("knowledgeAssets.detail.mode.html")).tag(KnowledgeAssetDetailMode.html)
                    Text(KairoL10n.string("knowledgeAssets.detail.mode.data")).tag(KnowledgeAssetDetailMode.data)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("knowledgeAssets.detail.mode")

                Menu {
                    Button {
                        assetDetailMode = .data
                    } label: {
                        Label(KairoL10n.string("knowledgeAssets.detail.action.viewData"), systemImage: "folder")
                    }

                    Button(role: .destructive) {
                        delete(asset)
                    } label: {
                        Label(KairoL10n.string("knowledgeAssets.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .assetGlassCircleControl()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("knowledgeAssets.detail.actions")
            }

            if assetDetailMode == .html {
                assetHTMLPreview(asset)
            } else {
                assetDataView(asset)
            }
        }
        .accessibilityIdentifier("knowledgeAssets.detail")
    }

    private func assetHTMLPreview(_ asset: KnowledgeAsset) -> some View {
        KairoFocusCard {
            KnowledgeAssetHTMLPreview(html: htmlDocument(for: asset))
                .frame(minHeight: 520)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func assetDataView(_ asset: KnowledgeAsset) -> some View {
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
                    dataTree(asset)

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

    private var activeFilterCount: Int {
        var count = 0
        if selectedKind != nil { count += 1 }
        if selectedFolderName != nil { count += 1 }
        if selectedDateFilter != .all { count += 1 }
        return count
    }

    private var reloadToken: String {
        [
            trimmedSearchQuery,
            selectedKind?.rawValue ?? "allKinds",
            selectedFolderName ?? "allFolders",
            selectedDateFilter.rawValue
        ].joined(separator: "|")
    }

    private var query: KnowledgeAssetQuery {
        let interval = selectedDateFilter.interval(now: Date())
        return KnowledgeAssetQuery(
            text: trimmedSearchQuery,
            kinds: selectedKind.map { Set([$0]) } ?? [],
            folderName: selectedFolderName,
            createdAfter: interval?.start,
            createdBefore: interval?.end
        )
    }

    private var folderNames: [String] {
        let explicit = folders.map(\.name)
        let derived = assets.flatMap(\.collections)
        return Array(Set(explicit + derived)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var groupedAssets: [KnowledgeAssetGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: assets) { asset in
            KnowledgeAssetGroupKey(date: asset.updatedAt, calendar: calendar)
        }
        return grouped
            .map { key, assets in
                KnowledgeAssetGroup(
                    id: key.id,
                    title: key.title,
                    assets: assets.sorted { $0.updatedAt > $1.updatedAt }
                )
            }
            .sorted { $0.id > $1.id }
    }

    private func reload() async {
        do {
            let loaded = try await assetAPI.query(query, limit: 200)
            let folders = try await assetAPI.listFolders()
            await MainActor.run {
                assets = loaded
                self.folders = folders
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

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        Task {
            do {
                try await assetAPI.saveFolder(KnowledgeAssetFolder(name: name))
                await reload()
                await MainActor.run {
                    selectedFolderName = name
                    newFolderName = ""
                    statusMessage = KairoL10n.string("knowledgeAssets.folder.created", name)
                }
            } catch {
                await MainActor.run {
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

    private func dataTree(_ asset: KnowledgeAsset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            treeRow(icon: "folder.fill", text: "node-\(asset.id.uuidString.prefix(8))")
            treeRow(icon: "doc.text.fill", text: "json/assets.json", indent: 18)
            treeRow(icon: "doc.richtext.fill", text: "html/index.html", indent: 18)
            treeRow(icon: "folder.fill", text: "resources/", indent: 18)
            ForEach(asset.attachments) { attachment in
                treeRow(icon: "paperclip", text: attachment.displayName, indent: 34)
            }
        }
        .accessibilityIdentifier("knowledgeAssets.detail.dataTree")
    }

    private func treeRow(icon: String, text: String, indent: CGFloat = 0) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(KairoDesign.teal)
                .frame(width: 18)
            Text(text)
                .font(.caption.monospaced())
                .foregroundStyle(KairoDesign.ink)
                .lineLimit(1)
        }
        .padding(.leading, indent)
    }

    private func htmlDocument(for asset: KnowledgeAsset) -> String {
        let title = Self.escapeHTML(asset.title)
        let summary = Self.escapeHTML(asset.summary.isEmpty ? KairoL10n.string("knowledgeAssets.summary.empty") : asset.summary)
        let extractedText = Self.escapeHTML(asset.extractedText)
        let tags = asset.tags.map { "<span>\(Self.escapeHTML($0))</span>" }.joined()
        let folders = asset.collections.map { "<span>\(Self.escapeHTML($0))</span>" }.joined()
        let checklist = asset.checklistItems.map { item in
            "<li>\(Self.escapeHTML(item.title))</li>"
        }.joined()

        return """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
            body { margin: 0; padding: 22px; background: #07121d; color: #eef7ff; }
            .card { border: 1px solid rgba(255,255,255,.14); border-radius: 24px; padding: 20px; background: linear-gradient(145deg, rgba(255,255,255,.14), rgba(255,255,255,.05)); box-shadow: 0 20px 60px rgba(0,0,0,.35); }
            h1 { font-size: 28px; line-height: 1.05; margin: 0 0 12px; letter-spacing: -0.04em; }
            p { color: rgba(238,247,255,.76); line-height: 1.5; }
            h2 { margin-top: 24px; font-size: 13px; text-transform: uppercase; letter-spacing: .12em; color: rgba(238,247,255,.56); }
            .chips { display: flex; flex-wrap: wrap; gap: 8px; }
            .chips span { padding: 7px 10px; border-radius: 999px; background: rgba(94, 234, 212, .13); color: #b7fff2; font-size: 12px; }
            li { margin: 8px 0; color: rgba(238,247,255,.82); }
            pre { white-space: pre-wrap; font: 12px ui-monospace, SFMono-Regular, Menlo, monospace; color: rgba(238,247,255,.72); }
          </style>
        </head>
        <body>
          <section class="card">
            <h1>\(title)</h1>
            <p>\(summary)</p>
            <h2>\(KairoL10n.string("knowledgeAssets.html.folders"))</h2>
            <div class="chips">\(folders.isEmpty ? "<span>-</span>" : folders)</div>
            <h2>\(KairoL10n.string("knowledgeAssets.html.tags"))</h2>
            <div class="chips">\(tags.isEmpty ? "<span>-</span>" : tags)</div>
            <h2>\(KairoL10n.string("knowledgeAssets.detail.checklist"))</h2>
            <ul>\(checklist.isEmpty ? "<li>-</li>" : checklist)</ul>
            <h2>\(KairoL10n.string("knowledgeAssets.detail.extractedText"))</h2>
            <pre>\(extractedText)</pre>
          </section>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
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

#if canImport(UIKit)
private struct KnowledgeAssetHTMLPreview: UIViewRepresentable {
    var html: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
#elseif canImport(AppKit)
private struct KnowledgeAssetHTMLPreview: NSViewRepresentable {
    var html: String

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
#else
private struct KnowledgeAssetHTMLPreview: View {
    var html: String

    var body: some View {
        ScrollView {
            Text(html)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }
}
#endif

private struct KnowledgeAssetGroup: Identifiable {
    var id: String
    var title: String
    var assets: [KnowledgeAsset]
}

private enum KnowledgeAssetDetailMode: String, CaseIterable {
    case html
    case data
}

private struct KnowledgeAssetGroupKey: Hashable {
    var id: String
    var title: String

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        self.id = String(format: "%04d-%02d", year, month)
        self.title = DateFormatter.knowledgeAssetMonth.string(from: date)
    }
}

private enum KnowledgeAssetDateFilter: String, CaseIterable {
    case all
    case today
    case last7Days
    case last30Days
    case thisYear

    var title: String {
        switch self {
        case .all:
            return KairoL10n.string("knowledgeAssets.filter.date.all")
        case .today:
            return KairoL10n.string("knowledgeAssets.filter.date.today")
        case .last7Days:
            return KairoL10n.string("knowledgeAssets.filter.date.last7Days")
        case .last30Days:
            return KairoL10n.string("knowledgeAssets.filter.date.last30Days")
        case .thisYear:
            return KairoL10n.string("knowledgeAssets.filter.date.thisYear")
        }
    }

    func interval(now: Date, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .all:
            return nil
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
            return DateInterval(start: start, end: end)
        case .last7Days:
            let end = now
            let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .last30Days:
            let end = now
            let start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .thisYear:
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? now
            let end = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? now
            return DateInterval(start: start, end: end)
        }
    }
}

private extension DateFormatter {
    static let knowledgeAssetMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy MMM"
        return formatter
    }()
}

private extension View {
    func assetGlassCircleControl() -> some View {
        self
            .foregroundStyle(KairoDesign.ink)
            .frame(width: 36, height: 36)
            .background {
                Circle()
                    .fill(KairoDesign.elevatedSurface.opacity(0.72))
            }
            .overlay {
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            }
            .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 12, x: 0, y: 7)
    }
}
#endif
