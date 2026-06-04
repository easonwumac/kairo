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
                            Text("Knowledge you approved")
                                .font(.title2.bold())
                            Text("Add, search, and review memories Kairo can cite later.")
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
                        .accessibilityLabel("Export memories")
                        .accessibilityIdentifier("memory.export.share")
                    }

                    KairoGroupedSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                TextField("Search memories", text: $searchQuery)
                                    .accessibilityIdentifier("memory.search.text")

                                if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button("Clear") { searchQuery = "" }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(KairoDesign.blue)
                                        .accessibilityIdentifier("memory.search.clear")
                                }
                            }

                            Text(searchSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("memory.search.summary")

                            Divider()

                            HStack(spacing: 10) {
                                TextField("Add a memory", text: $draft, axis: .vertical)
                                    .lineLimit(1...4)
                                    .accessibilityIdentifier("memory.add.text")

                                Button("Save") { save() }
                                    .font(.subheadline.weight(.semibold))
                                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                    .accessibilityIdentifier("memory.add.save")
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(KairoDesign.red)
                            .accessibilityIdentifier("memory.error")
                    }

                    KairoGroupedSurface {
                        if memories.isEmpty {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("No memories yet")
                                    .font(.subheadline.weight(.semibold))
                                Text("Shared or manually saved context will appear here.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 10)
                        } else {
                            ForEach(memories) { memory in
                                HStack(alignment: .top, spacing: 10) {
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
                                        Image(systemName: "trash")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(width: 32, height: 32)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(KairoDesign.red)
                                    .accessibilityLabel("Delete memory")
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
            .navigationTitle("Memory")
            .task(id: searchQuery) { await reload() }
            .refreshable { await reload() }
        }
    }

    private var trimmedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchSummary: String {
        guard !trimmedSearchQuery.isEmpty else {
            return "\(memories.count) saved memories"
        }
        return "\(memories.count) matches for \"\(trimmedSearchQuery)\""
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
