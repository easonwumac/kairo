#if canImport(SwiftUI)
import Foundation
import SwiftUI

public struct MemoryCenterView: View {
    private static let searchSectionScrollID = "memory.search.section.scroll"

    @FocusState private var isAddFieldFocused: Bool
    @State private var draft: String = ""
    @State private var searchQuery: String = ""
    @State private var memories: [MemoryRecord] = []
    @State private var errorMessage: String?
    @State private var exportText: String = "{}"
    @State private var showAddContext = false
    @State private var showLibraryDetails = false
    @State private var expandedMemoryDetailID: UUID?

    private let memoryAPI: any KairoMemoryAPI

    public init(dependencies: MemoryFeatureDependencies) {
        self.memoryAPI = dependencies.memoryAPI
    }

    public init(memoryAPI: any KairoMemoryAPI) {
        self.init(
            dependencies: MemoryFeatureDependencyFactory().makeDependencies(memoryAPI: memoryAPI)
        )
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            memorySearchSection
                                .id(Self.searchSectionScrollID)

                            memoryAddSection

                            if let errorMessage {
                                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(KairoDesign.red)
                                    .accessibilityIdentifier("memory.error")
                            }

                            memoryLibraryHeader

                            memoryRecordsSection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 18)
                        .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeTopPadding)
                        .padding(.bottom, 32)
                    }
                    .background(KairoDesign.background.ignoresSafeArea())
                    .scrollIndicators(.hidden)
                    .navigationTitle(KairoL10n.string("memory.navigationTitle"))
                    .task(id: searchQuery) { await reload() }
                    .refreshable { await reload() }
                    .onChange(of: memories.count) { _, _ in
                        withAnimation(.snappy(duration: 0.25)) {
                            scrollProxy.scrollTo(Self.searchSectionScrollID, anchor: .top)
                        }
                    }
                }
            }
        }
    }

    private var memoryRecordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if memories.isEmpty {
                if !trimmedSearchQuery.isEmpty {
                    KairoGroupedSurface {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(KairoL10n.string("memory.search.empty.title"))
                                .font(.subheadline.weight(.semibold))
                                .accessibilityIdentifier("memory.empty")
                            Text(KairoL10n.string("memory.search.empty.subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                } else {
                    KairoGroupedSurface {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(KairoL10n.string("memory.empty.title"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                                .accessibilityIdentifier("memory.empty")
                            Text(KairoL10n.string("memory.empty.subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 10)
                    }
                }
            } else {
                ForEach(memories) { memory in
                    memoryRecordCard(memory)
                }
            }
        }
        .accessibilityIdentifier("memory.list")
    }

    private func memoryRecordCard(_ memory: MemoryRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(memory.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .lineLimit(2)

                    Text(memory.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                KairoStatusPill(
                    title: sourceLabel(for: memory.source),
                    systemImage: sourceIcon(for: memory.source),
                    tint: KairoDesign.teal
                )
                KairoStatusPill(
                    title: KairoL10n.string("memory.record.updated", Self.memoryDateFormatter.string(from: memory.updatedAt)),
                    systemImage: "clock",
                    tint: KairoDesign.blue
                )
            }

            memoryRecordDetailsDisclosure(memory)
        }
        .padding(14)
        .background(KairoDesign.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.line, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("memory.record")
    }

    private func memoryRecordDetailsDisclosure(_ memory: MemoryRecord) -> some View {
        let isExpanded = expandedMemoryDetailID == memory.id

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                expandedMemoryDetailID = isExpanded ? nil : memory.id
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.teal)
                        .frame(width: 26, height: 26)
                        .background(KairoDesign.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text(KairoL10n.string("memory.record.details"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)

                    Spacer(minLength: 8)

                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.teal)
                }
                .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? KairoL10n.string("memory.record.details.hide") : KairoL10n.string("memory.record.details.show"))
            .accessibilityIdentifier("memory.record.details.toggle")

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()

                    HStack(spacing: 8) {
                        KairoStatusPill(
                            title: memory.cloudSyncAllowed ? KairoL10n.string("memory.record.cloudAllowed") : KairoL10n.string("memory.record.localOnly"),
                            systemImage: memory.cloudSyncAllowed ? "icloud.fill" : "lock.shield.fill",
                            tint: memory.cloudSyncAllowed ? KairoDesign.blue : KairoDesign.green
                        )
                        KairoStatusPill(
                            title: expiryLabel(for: memory),
                            systemImage: memory.expiresAt == nil ? "calendar.badge.checkmark" : "calendar.badge.clock",
                            tint: memory.expiresAt == nil ? KairoDesign.green : KairoDesign.amber
                        )
                    }

                    Button {
                        delete(memory)
                    } label: {
                        Label(KairoL10n.string("memory.delete.accessibility"), systemImage: "trash")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(KairoDesign.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(KairoDesign.red.opacity(0.18), lineWidth: 1)
                    }
                    .foregroundStyle(KairoDesign.red)
                    .accessibilityLabel(KairoL10n.string("memory.delete.accessibility"))
                    .accessibilityIdentifier("memory.record.delete")
                }
            }
        }
    }

    private var memoryLibraryHeader: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showLibraryDetails.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(KairoL10n.string("memory.details.title"), systemImage: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            Text(KairoL10n.string("memory.details.subtitle"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: showLibraryDetails ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.teal)
                            .frame(width: 34, height: 34)
                            .background(KairoDesign.teal.opacity(0.10), in: Circle())
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(KairoDesign.softSurface.opacity(0.55), in: Capsule())
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(showLibraryDetails ? KairoL10n.string("memory.details.hide") : KairoL10n.string("memory.details.show"))
                .accessibilityIdentifier("memory.details.toggle")

                if showLibraryDetails {
                    HStack(spacing: 8) {
                        KairoStatusPill(
                            title: KairoL10n.string(
                                memories.count == 1 ? "memory.status.count.one" : "memory.status.count.many",
                                Int64(memories.count)
                            ),
                            systemImage: "brain.head.profile",
                            tint: KairoDesign.teal
                        )
                        KairoStatusPill(
                            title: KairoL10n.string("memory.status.userApproved"),
                            systemImage: "checkmark.shield.fill",
                            tint: KairoDesign.green
                        )
                    }

                    ShareLink(item: exportText) {
                        Label(KairoL10n.string("memory.export.accessibility"), systemImage: "square.and.arrow.up")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.teal, isCompact: true))
                    .disabled(memories.isEmpty)
                    .accessibilityLabel(KairoL10n.string("memory.export.accessibility"))
                    .accessibilityIdentifier("memory.export.share")
                }
            }
        }
        .accessibilityIdentifier("memory.library.header")
    }

    private var memorySearchSection: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 10) {
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
        .accessibilityIdentifier("memory.search.section")
    }

    private var memoryAddSection: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showAddContext.toggle()
                        if !showAddContext {
                            isAddFieldFocused = false
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.message.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                            .frame(width: 28, height: 28)
                            .background(KairoDesign.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(KairoL10n.string("memory.add.section"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: showAddContext ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)
                            .frame(width: 34, height: 34)
                            .background(KairoDesign.blue.opacity(0.10), in: Circle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showAddContext ? KairoL10n.string("memory.add.hide") : KairoL10n.string("memory.add.show"))
                .accessibilityIdentifier("memory.add.toggle")

                if showAddContext {
                    TextField(KairoL10n.string("memory.add.placeholder"), text: $draft)
                        .focused($isAddFieldFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            isAddFieldFocused = false
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .accessibilityIdentifier("memory.add.text")

                    Text(KairoL10n.string("memory.add.detail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        save()
                    } label: {
                        Label(KairoL10n.string("memory.add.save"), systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .accessibilityIdentifier("memory.add.save")
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true))
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("memory.add.save")
                }
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

    private static let memoryDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private func sourceLabel(for source: MemorySource) -> String {
        switch source {
        case .manual:
            return KairoL10n.string("memory.source.manual")
        case .chat:
            return KairoL10n.string("memory.source.chat")
        case .shareExtension:
            return KairoL10n.string("memory.source.shareExtension")
        case .documentPicker:
            return KairoL10n.string("memory.source.documentPicker")
        case .photosPicker:
            return KairoL10n.string("memory.source.photosPicker")
        case .appIntent:
            return KairoL10n.string("memory.source.appIntent")
        case .calendar:
            return KairoL10n.string("memory.source.calendar")
        case .reminders:
            return KairoL10n.string("memory.source.reminders")
        case .externalConnector:
            return KairoL10n.string("memory.source.externalConnector")
        }
    }

    private func sourceIcon(for source: MemorySource) -> String {
        switch source {
        case .manual:
            return "square.and.pencil"
        case .chat:
            return "bubble.left.and.bubble.right.fill"
        case .shareExtension:
            return "square.and.arrow.down"
        case .documentPicker:
            return "doc.text.fill"
        case .photosPicker:
            return "photo.fill"
        case .appIntent:
            return "wand.and.sparkles"
        case .calendar:
            return "calendar"
        case .reminders:
            return "checklist.checked"
        case .externalConnector:
            return "point.3.connected.trianglepath.dotted"
        }
    }

    private func expiryLabel(for memory: MemoryRecord) -> String {
        guard let expiresAt = memory.expiresAt else {
            return KairoL10n.string("memory.record.noExpiry")
        }
        return KairoL10n.string("memory.record.expires", Self.memoryDateFormatter.string(from: expiresAt))
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
                await MainActor.run {
                    showAddContext = false
                    isAddFieldFocused = false
                }
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
                await MainActor.run {
                    if expandedMemoryDetailID == memory.id {
                        expandedMemoryDetailID = nil
                    }
                }
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
