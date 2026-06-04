#if canImport(SwiftUI)
import SwiftUI

public struct MemoryCenterView: View {
    @State private var draft: String = ""
    @State private var searchQuery: String = ""
    @State private var memories: [MemoryRecord] = []
    @State private var errorMessage: String?
    @State private var exportText: String = "{}"

    private let memoryAPI: any KairoMemoryAPI

    public init(store: MemoryStore = InMemoryMemoryStore()) {
        self.memoryAPI = KairoMemoryBackendService(memoryStore: store)
    }

    public init(memoryAPI: any KairoMemoryAPI) {
        self.memoryAPI = memoryAPI
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(KairoL10n.string("memory.title"))
                                .font(.title2.bold())
                            Text(KairoL10n.string("memory.subtitle"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        ShareLink(item: exportText) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.headline.weight(.semibold))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(memories.isEmpty ? .secondary : KairoDesign.teal)
                                .background(Color.white.opacity(0.85), in: Circle())
                        }
                        .disabled(memories.isEmpty)
                        .accessibilityLabel(KairoL10n.string("memory.export.accessibility"))
                        .accessibilityIdentifier("memory.export.share")
                    }

                    memorySearchSection

                    memoryAddSection

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(KairoDesign.red)
                            .accessibilityIdentifier("memory.error")
                    }

                    KairoGroupedSurface {
                        if memories.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(KairoL10n.string("memory.empty.title"))
                                    .font(.subheadline.weight(.semibold))
                                    .accessibilityIdentifier("memory.empty")
                                Text(KairoL10n.string("memory.empty.subtitle"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                        } else {
                            ForEach(memories) { memory in
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(memory.title)
                                            .font(.subheadline.weight(.semibold))
                                        Text(memory.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                        KairoStatusPill(
                                            title: memory.source.rawValue,
                                            systemImage: "doc.text.magnifyingglass",
                                            tint: KairoDesign.teal
                                        )
                                    }

                                    Spacer(minLength: 0)

                                    Button(role: .destructive) {
                                        delete(memory)
                                    } label: {
                                        Label(KairoL10n.string("memory.delete.accessibility"), systemImage: "trash")
                                            .labelStyle(.iconOnly)
                                            .font(.subheadline.weight(.semibold))
                                            .frame(width: 36, height: 36)
                                            .background(KairoDesign.red.opacity(0.10), in: Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(KairoDesign.red)
                                    .accessibilityLabel(KairoL10n.string("memory.delete.accessibility"))
                                    .accessibilityIdentifier("memory.record.delete")
                                }
                                .padding(.vertical, 10)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("memory.record")

                                if memory.id != memories.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                    .accessibilityIdentifier("memory.list")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 32)
            }
            .background(KairoDesign.background.ignoresSafeArea())
            .scrollIndicators(.hidden)
            .navigationTitle(KairoL10n.string("memory.navigationTitle"))
            .task(id: searchQuery) { await reload() }
            .refreshable { await reload() }
        }
    }

    private var memorySearchSection: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text(KairoL10n.string("memory.search.section"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)

                    TextField(KairoL10n.string("memory.search.placeholder"), text: $searchQuery)
                        .accessibilityIdentifier("memory.search.text")

                    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button(KairoL10n.string("memory.search.clear")) { searchQuery = "" }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                            .accessibilityIdentifier("memory.search.clear")
                    }
                }

                Text(searchSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("memory.search.summary")
            }
        }
    }

    private var memoryAddSection: some View {
        KairoGroupedSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text(KairoL10n.string("memory.add.section"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                TextField(KairoL10n.string("memory.add.placeholder"), text: $draft, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityIdentifier("memory.add.text")

                Button {
                    save()
                } label: {
                    Label(KairoL10n.string("memory.add.save"), systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("memory.add.save")
            }
        }
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchSummary: String {
        guard !trimmedSearchQuery.isEmpty else {
            return KairoL10n.string(
                memories.count == 1 ? "memory.search.summary.saved.one" : "memory.search.summary.saved.many",
                Int64(memories.count)
            )
        }
        return KairoL10n.string(
            memories.count == 1 ? "memory.search.summary.matches.one" : "memory.search.summary.matches.many",
            Int64(memories.count),
            trimmedSearchQuery
        )
    }

    private func save() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

        Task {
            let memory = MemoryRecord(
                title: String(text.prefix(40)),
                summary: String(text.prefix(160)),
                content: text,
                source: .manual
            )
            do {
                try await memoryAPI.save(memory)
                await reload()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func delete(_ memory: MemoryRecord) {
        Task {
            do {
                try await memoryAPI.delete(id: memory.id)
                try await memoryAPI.purgeDeleted()
                await reload()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func reload() async {
        do {
            let query = trimmedSearchQuery
            let loaded: [MemoryRecord]
            if query.isEmpty {
                loaded = try await memoryAPI.list(limit: 50)
            } else {
                loaded = try await memoryAPI.search(query: query, limit: 50)
            }
            let export = try await memoryAPI.export(limit: 500)
            let exportText = try Self.exportText(for: export)
            await MainActor.run {
                memories = loaded
                self.exportText = exportText
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }

    private static func exportText(for export: MemoryExport) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
#endif
