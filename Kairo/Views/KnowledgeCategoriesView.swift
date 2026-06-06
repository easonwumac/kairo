#if canImport(SwiftUI)
import SwiftUI

public struct KnowledgeCategoriesView: View {
    @State private var folders: [KnowledgeAssetFolder] = []
    @State private var newFolderName = ""
    @State private var errorMessage: String?

    private let assetAPI: any KairoKnowledgeAssetAPI

    public init(dependencies: KnowledgeAssetFeatureDependencies) {
        self.assetAPI = dependencies.assetAPI
    }

    public var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    KairoGroupedSurface {
                        VStack(alignment: .leading, spacing: 10) {
                            Label(KairoL10n.string("categories.title"), systemImage: "folder.fill")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            HStack(spacing: 8) {
                                TextField(KairoL10n.string("categories.new.placeholder"), text: $newFolderName)
                                    .textFieldStyle(.plain)
                                    .font(.subheadline.weight(.medium))
                                    .accessibilityIdentifier("categories.new.text")
                                Button {
                                    createFolder()
                                } label: {
                                    Image(systemName: "plus")
                                }
                                .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.teal, isCompact: true))
                                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                .accessibilityIdentifier("categories.new.button")
                            }
                        }
                    }

                    if let errorMessage {
                        KairoGroupedSurface {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(KairoDesign.red)
                        }
                        .accessibilityIdentifier("categories.error")
                    }

                    KairoGroupedSurface {
                        VStack(spacing: 0) {
                            ForEach(folders) { folder in
                                HStack(spacing: 12) {
                                    Image(systemName: "folder")
                                        .foregroundStyle(KairoDesign.blue)
                                        .frame(width: 28, height: 28)
                                        .background(KairoDesign.softSurface.opacity(0.62), in: Circle())
                                    Text(folder.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(KairoDesign.ink)
                                    Spacer()
                                    Button(role: .destructive) {
                                        delete(folder)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(KairoDesign.red)
                                    .accessibilityIdentifier("categories.folder.\(Self.identifier(for: folder.name)).delete")
                                }
                                .padding(.vertical, 10)
                                .accessibilityIdentifier("categories.folder.\(Self.identifier(for: folder.name))")
                                if folder.id != folders.last?.id {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("categories.list")
                }
                .padding(.horizontal, 16)
                .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeContentTopPadding)
                .padding(.bottom, 32)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .task { await reload() }
            .refreshable { await reload() }
            .accessibilityIdentifier("categories.screen")
        }
    }

    private func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            do {
                try await assetAPI.saveFolder(KnowledgeAssetFolder(name: name))
                await MainActor.run { newFolderName = "" }
                await reload()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }

    private func delete(_ folder: KnowledgeAssetFolder) {
        Task {
            do {
                try await assetAPI.deleteFolder(id: folder.id)
                await reload()
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription }
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
