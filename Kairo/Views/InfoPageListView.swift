import SwiftUI

public struct InfoPageListView: View {
    @State private var pages: [InfoPage] = []
    @State private var searchQuery = ""
    @State private var errorMessage: String?
    @State private var selectedPage: InfoPage?
    @State private var showHTMLForPage: InfoPage?
    @State private var reloadToken = 0

    private let store: any InfoPageStore

    public init(store: any InfoPageStore) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { proxy in
        ScrollView {
            Group {
            if let errorMessage {
                errorBanner(errorMessage)
            }

            if pages.isEmpty && searchQuery.isEmpty {
                emptyState
            } else if filteredPages.isEmpty {
                KairoGroupedSurface {
                    Label("No matching pages", systemImage: "magnifyingglass")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            } else {
                pageList
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
            .padding(.bottom, 32)
        }
        .background(KairoDesign.background.ignoresSafeArea())
        .scrollIndicators(.hidden)
        #if os(iOS)
        .searchable(text: $searchQuery, prompt: "Search pages")
        #endif
        .kairoHiddenNavigationChrome()
        .task { await reload() }
        .task(id: reloadToken) { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: .infoPageSaved)) { _ in
            reloadToken += 1
        }
        .refreshable { await reload() }
        }
        .sheet(item: $selectedPage) { page in
            InfoPageDetailView(page: page)
        }
        .sheet(item: Binding(
            get: { showHTMLForPage.map { InfoPageSheetItem(page: $0) } },
            set: { _ in showHTMLForPage = nil }
        )) { sheetItem in
            InfoPageHTMLSheetView(html: InfoPageHTMLRenderer.render(sheetItem.page))
        }
    }

    private var filteredPages: [InfoPage] {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            return pages
        }
        let q = searchQuery.lowercased()
        return pages.filter { page in
            page.title.localizedCaseInsensitiveContains(q) ||
            page.summary.localizedCaseInsensitiveContains(q) ||
            page.category.rawValue.localizedCaseInsensitiveContains(q)
        }
    }

    private var emptyState: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text("No Info Pages yet")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text("Pages are created when you capture related assets. Use Chat to classify images and generate pages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal)
    }

    private var pageList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredPages) { page in
                InfoPageRow(page: page, onOpenHTML: { showHTMLForPage = page })
                    .onTapGesture { selectedPage = page }
            }
        }
        .padding(.horizontal)
    }

    private func errorBanner(_ message: String) -> some View {
        KairoGroupedSurface {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(KairoDesign.red)
        }
        .padding(.horizontal)
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

private struct InfoPageRow: View {
    let page: InfoPage
    var onOpenHTML: () -> Void

    private var categoryColor: Color {
        switch page.category {
        case .travel: return .red
        case .order: return .blue
        case .event: return KairoDesign.amber
        case .medical: return .green
        case .finance: return .mint
        case .project: return .orange
        case .warranty: return .gray
        case .identityDocument: return .indigo
        case .homeDevice: return .orange
        case .subscription: return .cyan
        case .recipeOrInstruction: return .green
        case .generalNote: return .secondary
        }
    }

    private var categoryIcon: String {
        switch page.category {
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

    var body: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: categoryIcon)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(categoryColor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(page.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                            .lineLimit(1)
                        Text(page.category.rawValue.capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onOpenHTML) {
                        Image(systemName: "ellipsis")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(KairoDesign.muted)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }

                if !page.summary.isEmpty {
                    Text(page.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if !page.facts.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(page.facts.prefix(3)) { fact in
                                HStack(spacing: 4) {
                                    Text(fact.label)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    Text(fact.value)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(KairoDesign.ink)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(KairoDesign.groupedSurface, in: Capsule())
                            }
                        }
                    }
                }
            }
            .padding(4)
        }
    }
}

public struct InfoPageDetailView: View {
    let page: InfoPage
    @State private var showHTML = false
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        #if os(iOS)
        NavigationStack {
            content
                .navigationTitle(page.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Text("Done").fontWeight(.semibold)
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: InfoPageHTMLRenderer.render(page), preview: SharePreview(page.title))
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button { showHTML = true } label: {
                            Label("HTML Preview", systemImage: "safari")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isCompact: true))
                    }
                }
                .sheet(isPresented: $showHTML) {
                    InfoPageHTMLSheetView(html: InfoPageHTMLRenderer.render(page))
                }
        }
        #else
        content
        #endif
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection
                if !page.timeline.isEmpty {
                    timelineSection
                }
                if !page.facts.isEmpty {
                    factsSection
                }
                if !page.reminderLinks.isEmpty {
                    remindersSection
                }
                summarySection
            }
            .padding()
        }
        .background(KairoDesign.background.ignoresSafeArea())
    }

    private var headerSection: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.category.rawValue.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(categoryColor)
                        Text(page.title)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(KairoDesign.ink)
                    }
                    Spacer()
                    Text(page.reminderLinks.first?.status.rawValue ?? "draft")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(categoryColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(categoryColor.opacity(0.12), in: Capsule())
                }
                Text("\(page.assetIDs.count) linked assets · \(page.timeline.count) timeline items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var timelineSection: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 4) {
                Text("Timeline")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(Array(page.timeline.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            Circle()
                                .fill(categoryColor)
                                .frame(width: 8, height: 8)
                            if index < page.timeline.count - 1 {
                                Rectangle()
                                    .fill(KairoDesign.line)
                                    .frame(width: 2)
                            }
                        }
                        .frame(width: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            if let date = item.date {
                                Text(date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let note = item.note, note != item.title {
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var factsSection: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 4) {
                Text("Details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(page.facts) { fact in
                    HStack {
                        Text(fact.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 100, alignment: .leading)
                        Text(fact.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var remindersSection: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reminders")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                ForEach(page.reminderLinks) { link in
                    HStack {
                        Image(systemName: "bell.fill")
                            .font(.caption)
                            .foregroundStyle(categoryColor)
                        Text(link.title)
                            .font(.subheadline)
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

    private var summarySection: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Summary")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(page.summary)
                    .font(.subheadline)
                    .foregroundStyle(KairoDesign.ink)
            }
        }
    }

    private var categoryColor: Color {
        switch page.category {
        case .travel: return KairoDesign.red
        case .order: return KairoDesign.blue
        case .event: return KairoDesign.amber
        case .medical: return KairoDesign.green
        case .finance: return .mint
        case .project: return KairoDesign.amber
        default: return KairoDesign.muted
        }
    }
}

#if os(iOS)
import WebKit

struct InfoPageHTMLSheetView: View {
    let html: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WebView(html: html)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("HTML Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { dismiss() } label: {
                            Text("Done").fontWeight(.semibold)
                        }
                    }
                }
        }
    }
}

private struct WebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.scrollView.isScrollEnabled = true
        view.loadHTMLString(html, baseURL: nil)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
#else
struct InfoPageHTMLSheetView: View {
    let html: String
    var body: some View {
        ScrollView {
            VStack {
                Text("HTML Preview")
                    .font(.headline)
                Text("Open this page on iOS to see rich HTML rendering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                Text(verbatim: html)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding()
        }
    }
}
#endif

struct InfoPageSheetItem: Identifiable {
    let id = UUID()
    let page: InfoPage
}
