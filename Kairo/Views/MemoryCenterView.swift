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
                        memoryContent
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 18)
                            .padding(.top, max(proxy.safeAreaInsets.top, 0) + KairoDesign.rootChromeNavigationStackContentTopPadding)
                            .padding(.bottom, 32)
                    }
                    .background(KairoDesign.background.ignoresSafeArea())
                    .scrollIndicators(.hidden)
                    .kairoHiddenNavigationChrome()
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

    @ViewBuilder
    private var memoryContent: some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            GlassEffectContainer(spacing: 14) {
                memoryStack
            }
        } else {
            memoryStack
        }
    }

    private var memoryStack: some View {
        VStack(alignment: .leading, spacing: 18) {
            memorySearchSection
                .id(Self.searchSectionScrollID)

            memoryRadarSection

            memoryAddSection

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(KairoDesign.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .memoryGlassSurface(tint: KairoDesign.red, cornerRadius: 14)
                    .accessibilityIdentifier("memory.error")
            }

            memoryLibraryHeader

            memoryRecordsSection
        }
    }

    private var memoryRecordsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if memories.isEmpty {
                if !trimmedSearchQuery.isEmpty {
                    emptyMemoryCard(
                        title: KairoL10n.string("memory.search.empty.title"),
                        subtitle: KairoL10n.string("memory.search.empty.subtitle"),
                        tint: KairoDesign.amber
                    )
                } else {
                    emptyMemoryCard(
                        title: KairoL10n.string("memory.empty.title"),
                        subtitle: KairoL10n.string("memory.empty.subtitle"),
                        tint: KairoDesign.teal
                    )
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
        .memoryGlassSurface(tint: KairoDesign.teal, cornerRadius: 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("memory.record")
    }

    private func emptyMemoryCard(title: String, subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .accessibilityIdentifier("memory.empty")
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .memoryGlassSurface(tint: tint, cornerRadius: 18)
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
                        .memoryGlassSurface(tint: KairoDesign.teal, cornerRadius: 8)

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
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .memoryGlassSurface(tint: KairoDesign.teal, cornerRadius: 12, isInteractive: true)
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
                    .memoryGlassSurface(tint: KairoDesign.red, cornerRadius: 10, isInteractive: true)
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
                            .memoryGlassSurface(tint: KairoDesign.teal, cornerRadius: 17)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .memoryGlassSurface(tint: KairoDesign.teal, cornerRadius: 18, isInteractive: true)
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

    private var memoryRadarSection: some View {
        HStack(spacing: 10) {
            memoryRadarTile(
                title: KairoL10n.string("memory.radar.saved"),
                value: "\(memories.count)",
                systemImage: "brain.head.profile",
                tint: KairoDesign.teal
            )

            memoryRadarTile(
                title: KairoL10n.string("memory.radar.scope"),
                value: trimmedSearchQuery.isEmpty ? KairoL10n.string("memory.radar.scope.all") : KairoL10n.string("memory.radar.scope.filtered"),
                systemImage: trimmedSearchQuery.isEmpty ? "tray.full.fill" : "line.3.horizontal.decrease.circle.fill",
                tint: trimmedSearchQuery.isEmpty ? KairoDesign.blue : KairoDesign.amber
            )
        }
        .accessibilityIdentifier("memory.radar")
    }

    private func memoryRadarTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .memoryGlassSurface(tint: tint, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .memoryGlassSurface(tint: tint, cornerRadius: 18)
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
                            .memoryGlassSurface(tint: KairoDesign.blue, cornerRadius: 8)

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
                            .memoryGlassSurface(tint: KairoDesign.blue, cornerRadius: 17)
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
                        .memoryGlassSurface(tint: KairoDesign.blue, cornerRadius: 10, fallbackOpacity: 0.36, strokeOpacity: 0.42)
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

private extension View {
    @ViewBuilder
    func memoryGlassSurface(
        tint: Color,
        cornerRadius: CGFloat,
        isInteractive: Bool = false,
        fallbackOpacity: Double = 0.68,
        strokeOpacity: Double = 0.55
    ) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.11)).interactive(), in: .rect(cornerRadius: cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(KairoDesign.line.opacity(strokeOpacity), lineWidth: 1)
                    }
            } else {
                self
                    .glassEffect(.regular.tint(tint.opacity(0.08)), in: .rect(cornerRadius: cornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(KairoDesign.line.opacity(strokeOpacity), lineWidth: 1)
                    }
            }
        } else {
            self
                .background(KairoDesign.elevatedSurface.opacity(fallbackOpacity), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(KairoDesign.line.opacity(strokeOpacity), lineWidth: 1)
                }
        }
    }
}
#endif
