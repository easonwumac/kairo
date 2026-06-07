#if canImport(SwiftUI)
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct InfoPageListView: View {
    @State private var pages: [InfoPage] = []
    @State private var searchQuery = ""
    @State private var errorMessage: String?
    @State private var selectedPage: InfoPage?
    @State private var selectedCategory: InfoPageCategory?
    @State private var reloadToken = 0
    @State private var isFilterPresented = false
    @State private var linkedAssetsByPageID: [UUID: [KnowledgeAsset]] = [:]
    @State private var assetLoadTasks: [UUID: Task<Void, Never>] = [:]

    @Binding private var rootChromeBackRequestID: Int
    private let usesRootChromeNavigation: Bool
    private let store: any InfoPageStore
    private let assetAPI: (any KairoKnowledgeAssetAPI)?

    public init(
        store: any InfoPageStore,
        assetAPI: (any KairoKnowledgeAssetAPI)? = nil,
        rootChromeBackRequestID: Binding<Int> = .constant(0),
        usesRootChromeNavigation: Bool = false
    ) {
        self.store = store
        self.assetAPI = assetAPI
        self._rootChromeBackRequestID = rootChromeBackRequestID
        self.usesRootChromeNavigation = usesRootChromeNavigation
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                Group {
                    if let selectedPage {
                        detailContent(for: selectedPage)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        listContent
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: selectedPage?.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
                .padding(.bottom, 32)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .kairoHiddenNavigationChrome()
            .task { await reload() }
            .task(id: reloadToken) { await reload() }
            .onReceive(NotificationCenter.default.publisher(for: .infoPageSaved)) { _ in
                reloadToken += 1
            }
            .refreshable { await reload() }
            .preference(key: RootChromePreferenceKey.self, value: rootChromeContext)
            .onChange(of: rootChromeBackRequestID) { _, _ in
                guard selectedPage != nil else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    selectedPage = nil
                }
            }
        }
    }

    private var rootChromeContext: RootChromeContext {
        guard usesRootChromeNavigation, let selectedPage else {
            return .standard
        }
        return RootChromeContext(leadingAction: .back, title: selectedPage.title)
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredPages: [InfoPage] {
        var result = pages
        if let selectedCategory {
            result = result.filter { $0.category == selectedCategory }
        }
        guard !trimmedSearchQuery.isEmpty else { return result }
        let q = trimmedSearchQuery.lowercased()
        return result.filter { page in
            page.title.localizedCaseInsensitiveContains(q)
                || page.summary.localizedCaseInsensitiveContains(q)
                || page.category.displayName.localizedCaseInsensitiveContains(q)
                || page.facts.contains(where: { $0.label.localizedCaseInsensitiveContains(q) || $0.value.localizedCaseInsensitiveContains(q) })
        }
    }

    private var presentCategories: [InfoPageCategory] {
        let used = Set(pages.map(\.category))
        return InfoPageCategory.allCases.filter { used.contains($0) }
    }

    // MARK: - List

    private var listContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            searchCard

            if let errorMessage {
                statusBanner(errorMessage, systemImage: "exclamationmark.triangle.fill", tint: KairoDesign.red)
            }

            if pages.isEmpty && trimmedSearchQuery.isEmpty && selectedCategory == nil {
                emptyState
            } else if filteredPages.isEmpty {
                emptyResults
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredPages) { page in
                        Button {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                selectedPage = page
                            }
                        } label: {
                            InfoPageCard(page: page)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var searchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)

                TextField(KairoL10n.string("infoPages.search.placeholder"), text: $searchQuery)
                    .textFieldStyle(.plain)
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("infoPages.search.text")

                if !presentCategories.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isFilterPresented.toggle()
                        }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(selectedCategory == nil ? KairoDesign.ink : KairoDesign.blue)
                            .frame(width: 28, height: 28)
                            .background(KairoDesign.softSurface.opacity(0.72), in: Circle())
                            .overlay {
                                Circle().stroke(KairoDesign.line, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("infoPages.filter.toggle")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(KairoDesign.elevatedSurface.opacity(0.78), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(KairoDesign.line, lineWidth: 1)
            }

            if isFilterPresented && !presentCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        categoryChip(label: KairoL10n.string("infoPages.filter.all"), isSelected: selectedCategory == nil) {
                            selectedCategory = nil
                        }
                        ForEach(presentCategories, id: \.self) { category in
                            categoryChip(
                                label: category.displayName,
                                systemImage: category.systemImage,
                                tint: category.tint,
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = (selectedCategory == category) ? nil : category
                            }
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(
        label: String,
        systemImage: String? = nil,
        tint: Color = KairoDesign.blue,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption2.weight(.semibold))
                }
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tint.opacity(0.15) : KairoDesign.softSurface.opacity(0.55), in: Capsule())
            .overlay {
                Capsule().stroke(isSelected ? tint : KairoDesign.line, lineWidth: 1)
            }
            .foregroundStyle(isSelected ? tint : KairoDesign.ink)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text(KairoL10n.string("infoPages.empty.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(KairoL10n.string("infoPages.empty.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyResults: some View {
        KairoGroupedSurface {
            Label(KairoL10n.string("infoPages.search.empty"), systemImage: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBanner(_ message: String, systemImage: String, tint: Color) -> some View {
        KairoGroupedSurface {
            Label(message, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
        }
    }

    // MARK: - Detail

    private func detailContent(for page: InfoPage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            detailHeader(page)

            #if canImport(WebKit) && canImport(UIKit)
            InfoPageHTMLPreview(html: InfoPageHTMLRenderer.render(page))
                .frame(minHeight: 520)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(KairoDesign.line, lineWidth: 1)
                }
            #else
            KairoGroupedSurface {
                Text(page.summary.isEmpty ? page.title : page.summary)
                    .font(.subheadline)
                    .foregroundStyle(KairoDesign.ink)
            }
            #endif

            linkedAssetsSection(for: page)

            if !page.reminderLinks.isEmpty {
                remindersSection(for: page)
            }
        }
        .accessibilityIdentifier("infoPages.detail")
        .onAppear { loadLinkedAssets(for: page) }
    }

    private func detailHeader(_ page: InfoPage) -> some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: page.category.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(page.category.tint)
                        .frame(width: 32, height: 32)
                        .background(page.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.category.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(page.category.tint)
                        Text(page.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(KairoDesign.ink)
                    }
                    Spacer()
                }

                if let (label, date) = page.primaryDateInfo() {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KairoDesign.muted)
                        Text(label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.muted)
                        Text(date, style: .date)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                    }
                }

                if !page.summary.isEmpty {
                    Text(page.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func linkedAssetsSection(for page: InfoPage) -> some View {
        if let assets = linkedAssetsByPageID[page.id], !assets.isEmpty {
            KairoGroupedSurface {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(KairoL10n.string("infoPages.detail.assets"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(assets.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KairoDesign.muted)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(assets) { asset in
                                InfoPageLinkedAssetThumbnail(asset: asset, size: 86)
                            }
                        }
                    }
                }
            }
        }
    }

    private func remindersSection(for page: InfoPage) -> some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 8) {
                Text(KairoL10n.string("infoPages.detail.reminders"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(page.reminderLinks) { link in
                    HStack(spacing: 8) {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(page.category.tint)
                        Text(link.title)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(KairoDesign.ink)
                        Spacer()
                        if let due = link.dueDate {
                            Text(due, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func loadLinkedAssets(for page: InfoPage) {
        guard let assetAPI, linkedAssetsByPageID[page.id] == nil, !page.assetIDs.isEmpty else { return }
        assetLoadTasks[page.id]?.cancel()
        let pageID = page.id
        let wantedIDs = Set(page.assetIDs)
        assetLoadTasks[page.id] = Task {
            do {
                let allAssets = try await assetAPI.list(limit: 200)
                let matches = allAssets.filter { wantedIDs.contains($0.id) }
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    linkedAssetsByPageID[pageID] = matches
                }
            } catch {
                // Best-effort; silent failure keeps the rest of the page useful.
            }
        }
    }

    private func reload() async {
        do {
            let loaded = try await store.list(limit: 100)
            await MainActor.run {
                pages = loaded
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }
}

private struct InfoPageCard: View {
    let page: InfoPage

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: page.category.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(page.category.tint)
                .frame(width: 32, height: 32)
                .background(page.category.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(page.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let (_, date) = page.primaryDateInfo() {
                        Text(date, style: .date)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(page.category.tint)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }

                HStack(spacing: 6) {
                    Text(page.category.displayName)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(page.category.tint.opacity(0.14), in: Capsule())
                        .foregroundStyle(page.category.tint)

                    if let (label, _) = page.primaryDateInfo() {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if !page.assetIDs.isEmpty {
                        Label("\(page.assetIDs.count)", systemImage: "photo.stack")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if !page.reminderLinks.isEmpty {
                        Label("\(page.reminderLinks.count)", systemImage: "bell")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if !page.summary.isEmpty {
                    Text(page.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(KairoDesign.line, lineWidth: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("infoPages.card")
    }
}

private struct InfoPageLinkedAssetThumbnail: View {
    let asset: KnowledgeAsset
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(KairoDesign.softSurface.opacity(0.82))
            if let image = localImage {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            } else {
                Image(systemName: fallbackIcon)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(KairoDesign.teal)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous).stroke(KairoDesign.line, lineWidth: 1)
        }
        .clipped()
        .accessibilityLabel(asset.title)
    }

    private var fallbackIcon: String {
        switch asset.kind {
        case .screenshot, .image: return "photo"
        case .pdf: return "doc.richtext"
        case .url: return "link"
        case .text, .note: return "text.alignleft"
        case .file: return "doc"
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

#if canImport(WebKit) && canImport(UIKit)
private struct InfoPageHTMLPreview: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: nil)
    }
}
#endif

// MARK: - InfoPage helpers (display)

extension InfoPageCategory {
    var displayName: String {
        switch self {
        case .travel: return KairoL10n.string("infoPages.category.travel")
        case .order: return KairoL10n.string("infoPages.category.order")
        case .warranty: return KairoL10n.string("infoPages.category.warranty")
        case .project: return KairoL10n.string("infoPages.category.project")
        case .event: return KairoL10n.string("infoPages.category.event")
        case .medical: return KairoL10n.string("infoPages.category.medical")
        case .finance: return KairoL10n.string("infoPages.category.finance")
        case .identityDocument: return KairoL10n.string("infoPages.category.identityDocument")
        case .homeDevice: return KairoL10n.string("infoPages.category.homeDevice")
        case .subscription: return KairoL10n.string("infoPages.category.subscription")
        case .recipeOrInstruction: return KairoL10n.string("infoPages.category.recipeOrInstruction")
        case .generalNote: return KairoL10n.string("infoPages.category.generalNote")
        }
    }

    var systemImage: String {
        switch self {
        case .travel: return "airplane"
        case .order: return "shippingbox.fill"
        case .event: return "calendar.badge.clock"
        case .medical: return "cross.case.fill"
        case .finance: return "dollarsign.circle.fill"
        case .project: return "checklist"
        case .warranty: return "shield.checkered"
        case .identityDocument: return "person.text.rectangle.fill"
        case .homeDevice: return "house.fill"
        case .subscription: return "repeat.circle.fill"
        case .recipeOrInstruction: return "fork.knife"
        case .generalNote: return "doc.text.fill"
        }
    }

    var tint: Color {
        switch self {
        case .travel: return KairoDesign.red
        case .order: return KairoDesign.blue
        case .event: return KairoDesign.amber
        case .medical: return KairoDesign.green
        case .finance: return .mint
        case .project: return .orange
        case .warranty: return KairoDesign.muted
        case .identityDocument: return .indigo
        case .homeDevice: return .orange
        case .subscription: return .cyan
        case .recipeOrInstruction: return KairoDesign.green
        case .generalNote: return KairoDesign.muted
        }
    }

    fileprivate var primaryDateLabel: String {
        switch self {
        case .travel: return KairoL10n.string("infoPages.dateLabel.departure")
        case .order: return KairoL10n.string("infoPages.dateLabel.order")
        case .event: return KairoL10n.string("infoPages.dateLabel.event")
        case .medical: return KairoL10n.string("infoPages.dateLabel.appointment")
        case .finance: return KairoL10n.string("infoPages.dateLabel.due")
        case .warranty: return KairoL10n.string("infoPages.dateLabel.expires")
        case .identityDocument: return KairoL10n.string("infoPages.dateLabel.expires")
        case .subscription: return KairoL10n.string("infoPages.dateLabel.renewal")
        case .homeDevice: return KairoL10n.string("infoPages.dateLabel.purchased")
        case .project: return KairoL10n.string("infoPages.dateLabel.deadline")
        case .recipeOrInstruction: return KairoL10n.string("infoPages.dateLabel.saved")
        case .generalNote: return KairoL10n.string("infoPages.dateLabel.saved")
        }
    }
}

extension InfoPage {
    func primaryDateInfo() -> (label: String, date: Date)? {
        if let scheduled = scheduledTimelineDate() {
            return (category.primaryDateLabel, scheduled)
        }
        if let reminderDate = reminderLinks.compactMap(\.dueDate).sorted().first {
            return (KairoL10n.string("infoPages.dateLabel.reminder"), reminderDate)
        }
        return (KairoL10n.string("infoPages.dateLabel.saved"), updatedAt)
    }

    private func scheduledTimelineDate() -> Date? {
        let dates = timeline.compactMap(\.date)
        guard !dates.isEmpty else { return nil }
        let now = Date()
        let future = dates.filter { $0 >= now }.sorted()
        if let first = future.first { return first }
        return dates.sorted().last
    }
}

#endif
