#if canImport(SwiftUI)
import SwiftUI

public struct MemoryCenterView: View {
    @State private var draft: String = ""
    @State private var memories: [MemoryRecord] = []
    @State private var errorMessage: String?

    private let store: MemoryStore

    public init(store: MemoryStore = InMemoryMemoryStore()) {
        self.store = store
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Knowledge you approved")
                            .font(.title2.bold())
                        Text("Add, search, and review memories Kairo can cite later.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    KairoGroupedSurface {
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
            .task { await reload() }
            .refreshable { await reload() }
        }
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
                try await store.save(memory)
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
            let loaded = try await store.list(limit: 50)
            await MainActor.run {
                memories = loaded
                errorMessage = nil
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
}
#endif
