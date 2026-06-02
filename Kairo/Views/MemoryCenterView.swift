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
            VStack {
                HStack {
                    TextField("Add a memory", text: $draft)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") { save() }
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                List(memories) { memory in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.title).font(.headline)
                        Text(memory.summary).font(.subheadline)
                        Text(memory.source.rawValue).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
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
