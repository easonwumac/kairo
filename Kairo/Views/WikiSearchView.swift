#if canImport(SwiftUI)
import Foundation
import SwiftUI

@MainActor
public final class KairoWikiSearchViewModel: ObservableObject {
    @Published public private(set) var results: [KairoWikiSearchResult] = []
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isLoading = false

    private let searchService: any KairoWikiSearchProviding
    private let limit: Int

    public init(
        searchService: any KairoWikiSearchProviding,
        limit: Int = 30
    ) {
        self.searchService = searchService
        self.limit = limit
    }

    public func search(query: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            results = try await searchService.search(query: query, limit: limit)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }
}

public struct WikiSearchView: View {
    @StateObject private var viewModel: KairoWikiSearchViewModel
    @State private var searchQuery = ""

    public init(searchService: any KairoWikiSearchProviding) {
        _viewModel = StateObject(wrappedValue: KairoWikiSearchViewModel(searchService: searchService))
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    searchCard

                    if let errorMessage = viewModel.errorMessage {
                        statusBanner(errorMessage)
                    }

                    resultsSection
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
        }
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
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
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
        .padding(14)
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("wikiSearch.result.\(result.kind.rawValue)")
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
#endif
