#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class KairoWikiSearchViewModel: ObservableObject {
    @Published public private(set) var results: [KairoWikiSearchResult] = []
    @Published public private(set) var selectedResult: KairoWikiSearchResult?
    @Published public private(set) var selectedDetail: KairoWikiDetail?
    @Published public private(set) var relatedResults: [KairoWikiSearchResult] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isLoading = false
    @Published public private(set) var isLoadingDetail = false
    @Published public private(set) var isLoadingRelated = false

    private let searchService: any KairoWikiSearchProviding
    private let detailResolver: (any KairoWikiDetailResolving)?
    private let limit: Int
    private let relatedLimit: Int

    public init(
        searchService: any KairoWikiSearchProviding,
        detailResolver: (any KairoWikiDetailResolving)? = nil,
        limit: Int = 30,
        relatedLimit: Int = 5
    ) {
        self.searchService = searchService
        self.detailResolver = detailResolver
        self.limit = limit
        self.relatedLimit = relatedLimit
    }

    public func search(query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            results = try await searchService.search(query: query, limit: limit)
            selectedResult = nil
            selectedDetail = nil
            relatedResults = []
        } catch {
            results = []
            selectedResult = nil
            selectedDetail = nil
            relatedResults = []
            errorMessage = error.localizedDescription
        }
    }

    public func open(_ route: KairoURLRoute) async -> String? {
        switch route {
        case .search(let query):
            await search(query: query)
            return query
        case .infoPage(let id):
            await select(routeResult(id: id, kind: .infoPage))
            return nil
        case .knowledgeAsset(let id):
            await select(routeResult(id: id, kind: .knowledgeAsset))
            return nil
        case .memoryRecord(let id):
            await select(routeResult(id: id, kind: .memory))
            return nil
        case .chatThread:
            return nil
        }
    }

    public func select(_ result: KairoWikiSearchResult) async {
        selectedResult = result
        selectedDetail = nil
        relatedResults = []

        isLoadingDetail = detailResolver != nil
        isLoadingRelated = true
        errorMessage = nil
        defer {
            isLoadingDetail = false
            isLoadingRelated = false
        }

        do {
            if let detailResolver {
                if let detail = try await detailResolver.detail(for: result) {
                    selectedDetail = detail
                    selectedResult = hydratedResult(from: detail, fallback: result)
                } else {
                    errorMessage = KairoL10n.string("wikiSearch.detail.missing")
                }
            }
            relatedResults = try await relatedResults(for: result)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func closeDetail() {
        selectedResult = nil
        selectedDetail = nil
        relatedResults = []
        isLoadingDetail = false
        isLoadingRelated = false
    }

    private func relatedResults(for result: KairoWikiSearchResult) async throws -> [KairoWikiSearchResult] {
        let query = [result.title, result.snippet]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !query.isEmpty else { return [] }
        return try await searchService.search(query: query, limit: relatedLimit + 1)
            .filter { $0.id != result.id || $0.kind != result.kind }
            .prefix(relatedLimit)
            .map { $0 }
    }

    private func routeResult(id: UUID, kind: KairoWikiSearchResultKind) -> KairoWikiSearchResult {
        KairoWikiSearchResult(
            id: id,
            kind: kind,
            title: KairoL10n.string("wikiSearch.detail.opening"),
            snippet: "",
            updatedAt: Date(),
            score: 1
        )
    }

    private func hydratedResult(from detail: KairoWikiDetail, fallback: KairoWikiSearchResult) -> KairoWikiSearchResult {
        switch detail {
        case .infoPage(let page, _):
            return KairoWikiSearchResult(
                id: page.id,
                kind: .infoPage,
                title: page.title,
                snippet: page.summary,
                updatedAt: page.updatedAt,
                score: fallback.score
            )
        case .knowledgeAsset(let asset, _):
            return KairoWikiSearchResult(
                id: asset.id,
                kind: .knowledgeAsset,
                title: asset.title,
                snippet: asset.summary.isEmpty ? asset.extractedText : asset.summary,
                updatedAt: asset.updatedAt,
                score: fallback.score
            )
        case .memory(let memory):
            return KairoWikiSearchResult(
                id: memory.id,
                kind: .memory,
                title: memory.title,
                snippet: memory.summary.isEmpty ? memory.content : memory.summary,
                updatedAt: memory.updatedAt,
                score: fallback.score
            )
        }
    }
}

public struct WikiSearchView: View {
    @StateObject private var viewModel: KairoWikiSearchViewModel
    @State private var searchQuery = ""
    private let routeRequest: KairoURLRoute?

    public init(
        searchService: any KairoWikiSearchProviding,
        detailResolver: (any KairoWikiDetailResolving)? = nil,
        routeRequest: KairoURLRoute? = nil
    ) {
        _viewModel = StateObject(wrappedValue: KairoWikiSearchViewModel(
            searchService: searchService,
            detailResolver: detailResolver
        ))
        self.routeRequest = routeRequest
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let selectedResult = viewModel.selectedResult {
                        detailContent(for: selectedResult, detail: viewModel.selectedDetail)
                    } else {
                        searchOverviewContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeNavigationStackContentTopPadding)
                .padding(.bottom, 32)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .kairoHiddenNavigationChrome()
            .task(id: searchQuery) {
                await viewModel.search(query: searchQuery)
            }
            .refreshable {
                await viewModel.search(query: searchQuery)
            }
            .task(id: routeRequest) {
                guard let routeRequest else { return }
                if let query = await viewModel.open(routeRequest) {
                    searchQuery = query
                }
            }
        }
    }

    @ViewBuilder
    private var searchOverviewContent: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 18) {
                searchOverviewStack
            }
        } else {
            searchOverviewStack
        }
    }

    @ViewBuilder
    private var searchOverviewStack: some View {
        header
        searchCard

        if let errorMessage = viewModel.errorMessage {
            statusBanner(errorMessage)
        }

        resultsSection
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(KairoL10n.string("wikiSearch.title"))
                .font(.title2.weight(.bold))
                .foregroundStyle(KairoDesign.ink)
            Text(KairoL10n.string("wikiSearch.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var searchCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            TextField(KairoL10n.string("wikiSearch.search.placeholder"), text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.medium))
                .accessibilityIdentifier("wikiSearch.search.text")

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(KairoL10n.string("wikiSearch.search.clear"))
                .accessibilityIdentifier("wikiSearch.search.clear")
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 48)
        .wikiSearchGlassSurface(cornerRadius: 16, tint: KairoDesign.blue, isInteractive: true)
    }

    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(KairoL10n.string("wikiSearch.results.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if viewModel.results.isEmpty, !viewModel.isLoading {
                emptyState
            } else {
                ForEach(viewModel.results) { result in
                    resultCard(result)
                }
            }
        }
        .accessibilityIdentifier("wikiSearch.results")
    }

    private var emptyState: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 6) {
                Text(KairoL10n.string("wikiSearch.empty.title"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .accessibilityIdentifier("wikiSearch.empty")
                Text(KairoL10n.string("wikiSearch.empty.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 8)
        }
    }

    private func resultCard(_ result: KairoWikiSearchResult) -> some View {
        Button {
            Task {
                await viewModel.select(result)
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon(for: result.kind))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint(for: result.kind))
                        .frame(width: 30, height: 30)
                        .background(tint(for: result.kind).opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                            .lineLimit(2)
                        if !result.snippet.isEmpty {
                            Text(result.snippet)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    KairoStatusPill(
                        title: label(for: result.kind),
                        systemImage: icon(for: result.kind),
                        tint: tint(for: result.kind)
                    )
                    KairoStatusPill(
                        title: KairoL10n.string("wikiSearch.result.score", Int64(result.score)),
                        systemImage: "sparkle.magnifyingglass",
                        tint: KairoDesign.blue
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .padding(14)
        .wikiSearchGlassSurface(cornerRadius: 16, tint: tint(for: result.kind), isInteractive: true)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wikiSearch.result.\(result.kind.rawValue)")
    }

    private func detailContent(for result: KairoWikiSearchResult, detail: KairoWikiDetail?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Button {
                viewModel.closeDetail()
            } label: {
                Label(KairoL10n.string("wikiSearch.detail.back"), systemImage: "chevron.left")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(KairoGlassButtonStyle(tint: tint(for: result.kind), isCompact: true))
            .accessibilityIdentifier("wikiSearch.detail.back")

            resultHeader(result)

            if viewModel.isLoadingDetail {
                KairoGroupedSurface {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(KairoL10n.string("wikiSearch.detail.loading"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                statusBanner(errorMessage)
            }

            if let detail {
                switch detail {
                case .infoPage(let page, let linkedAssets):
                    infoPageDetail(page, linkedAssets: linkedAssets)
                case .knowledgeAsset(let asset, let linkedInfoPages):
                    assetDetail(asset, linkedInfoPages: linkedInfoPages)
                case .memory(let memory):
                    memoryDetail(memory)
                }
            }

            relatedSection
        }
        .accessibilityIdentifier("wikiSearch.detail")
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(KairoL10n.string("wikiSearch.related.title"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                if viewModel.isLoadingRelated {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if viewModel.relatedResults.isEmpty, !viewModel.isLoadingRelated {
                KairoGroupedSurface {
                    Text(KairoL10n.string("wikiSearch.related.empty"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                }
            } else {
                ForEach(viewModel.relatedResults) { result in
                    resultCard(result)
                }
            }
        }
        .accessibilityIdentifier("wikiSearch.related")
    }

    private func resultHeader(_ result: KairoWikiSearchResult) -> some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    KairoStatusPill(title: label(for: result.kind), systemImage: icon(for: result.kind), tint: tint(for: result.kind))
                    KairoStatusPill(title: KairoL10n.string("wikiSearch.result.score", Int64(result.score)), systemImage: "sparkle.magnifyingglass", tint: KairoDesign.blue)
                }
                Text(result.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(KairoDesign.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if !result.snippet.isEmpty {
                    Text(result.snippet)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func infoPageDetail(_ page: InfoPage, linkedAssets: [KairoWikiSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailSection(title: KairoL10n.string("wikiSearch.detail.summary"), systemImage: "text.alignleft") {
                Text(page.summary.isEmpty ? KairoL10n.string("wikiSearch.detail.empty") : page.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !page.facts.isEmpty {
                detailSection(title: KairoL10n.string("wikiSearch.detail.facts"), systemImage: "list.bullet.rectangle") {
                    ForEach(page.facts) { fact in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fact.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            Text(fact.value)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            linkedItemsSection(
                title: KairoL10n.string("wikiSearch.detail.linkedAssets"),
                items: linkedAssets
            )
        }
    }

    private func assetDetail(_ asset: KnowledgeAsset, linkedInfoPages: [KairoWikiSearchResult]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailSection(title: KairoL10n.string("wikiSearch.detail.summary"), systemImage: "text.alignleft") {
                Text(asset.summary.isEmpty ? KairoL10n.string("wikiSearch.detail.empty") : asset.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !asset.extractedText.isEmpty {
                detailSection(title: KairoL10n.string("wikiSearch.detail.extractedText"), systemImage: "text.viewfinder") {
                    Text(asset.extractedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            linkedItemsSection(
                title: KairoL10n.string("wikiSearch.detail.linkedInfoPages"),
                items: linkedInfoPages
            )
        }
    }

    private func memoryDetail(_ memory: MemoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            detailSection(title: KairoL10n.string("wikiSearch.detail.summary"), systemImage: "text.alignleft") {
                Text(memory.summary.isEmpty ? KairoL10n.string("wikiSearch.detail.empty") : memory.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            detailSection(title: KairoL10n.string("wikiSearch.detail.content"), systemImage: "doc.text") {
                Text(memory.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                content()
            }
        }
    }

    @ViewBuilder
    private func linkedItemsSection(title: String, items: [KairoWikiSearchResult]) -> some View {
        if !items.isEmpty {
            detailSection(title: title, systemImage: "link") {
                ForEach(items) { item in
                    resultCard(item)
                }
            }
        }
    }

    private func statusBanner(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(KairoDesign.red)
            .accessibilityIdentifier("wikiSearch.error")
    }

    private func label(for kind: KairoWikiSearchResultKind) -> String {
        switch kind {
        case .infoPage:
            return KairoL10n.string("wikiSearch.result.infoPage")
        case .knowledgeAsset:
            return KairoL10n.string("wikiSearch.result.knowledgeAsset")
        case .memory:
            return KairoL10n.string("wikiSearch.result.memory")
        }
    }

    private func icon(for kind: KairoWikiSearchResultKind) -> String {
        switch kind {
        case .infoPage:
            return "doc.richtext.fill"
        case .knowledgeAsset:
            return "archivebox.fill"
        case .memory:
            return "brain.head.profile"
        }
    }

    private func tint(for kind: KairoWikiSearchResultKind) -> Color {
        switch kind {
        case .infoPage:
            return KairoDesign.blue
        case .knowledgeAsset:
            return KairoDesign.teal
        case .memory:
            return KairoDesign.amber
        }
    }
}

private extension View {
    @ViewBuilder
    func wikiSearchGlassSurface(cornerRadius: CGFloat, tint: Color, isInteractive: Bool = false) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.12))
                            .interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                    }
            } else {
                self
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.08)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                    }
            }
        } else {
            self
                .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(KairoDesign.line, lineWidth: 1)
                }
        }
    }
}
#endif
