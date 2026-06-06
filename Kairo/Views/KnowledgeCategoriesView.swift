#if canImport(SwiftUI)
import SwiftUI

public struct KnowledgeCategoriesView: View {
    @State private var folders: [KnowledgeAssetFolder] = []
    @State private var updatingCategoryID: String?
    @State private var errorMessage: String?

    private let assetAPI: any KairoKnowledgeAssetAPI

    public init(dependencies: KnowledgeAssetFeatureDependencies) {
        self.assetAPI = dependencies.assetAPI
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    headerCard

                    if let errorMessage {
                        errorCard(errorMessage)
                    }

                    categoryGrid
                }
                .padding(.horizontal, 16)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(KairoDesign.background.ignoresSafeArea())
            .task { await reload() }
            .refreshable { await reload() }
            .accessibilityIdentifier("categories.screen")
        }
    }

    private var headerCard: some View {
        KairoFocusCard {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "folder.fill.badge.gearshape")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(KairoDesign.blue)
                    .frame(width: 42, height: 42)
                    .background(KairoDesign.blue.opacity(0.10), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(KairoL10n.string("categories.title"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(KairoL10n.string("categories.subtitle"))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(KairoDesign.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func errorCard(_ message: String) -> some View {
        KairoGroupedSurface {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(KairoDesign.red)
        }
        .accessibilityIdentifier("categories.error")
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(KairoOnboarding.defaultCategories) { category in
                categoryButton(category)
            }
        }
        .accessibilityIdentifier("categories.list")
    }

    private func categoryButton(_ category: KairoOnboardingCategory) -> some View {
        let folder = folder(for: category)
        let isEnabled = folder != nil
        let isUpdating = updatingCategoryID == category.id

        return Button {
            toggle(category, existingFolder: folder)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isEnabled ? KairoDesign.teal : KairoDesign.muted)
                    Spacer(minLength: 0)
                    if isUpdating {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }

                Text(KairoL10n.string(category.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(KairoDesign.elevatedSurface.opacity(isEnabled ? 0.72 : 0.46), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isEnabled ? KairoDesign.teal.opacity(0.28) : KairoDesign.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isUpdating)
        .accessibilityIdentifier("categories.preset.\(category.id)")
    }

    private func folder(for category: KairoOnboardingCategory) -> KnowledgeAssetFolder? {
        let title = KairoL10n.string(category.titleKey)
        return folders.first { $0.name.localizedCaseInsensitiveCompare(title) == .orderedSame }
    }

    private func toggle(_ category: KairoOnboardingCategory, existingFolder: KnowledgeAssetFolder?) {
        updatingCategoryID = category.id
        Task {
            do {
                if let existingFolder {
                    try await assetAPI.deleteFolder(id: existingFolder.id)
                } else {
                    try await assetAPI.saveFolder(KnowledgeAssetFolder(name: KairoL10n.string(category.titleKey)))
                }
                await reload()
                await MainActor.run { updatingCategoryID = nil }
            } catch {
                await MainActor.run {
                    updatingCategoryID = nil
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func reload() async {
        do {
            let loaded = try await assetAPI.listFolders()
            await MainActor.run {
                folders = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
                errorMessage = nil
            }
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    static func identifier(for name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
    }
}
#endif
