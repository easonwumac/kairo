#if canImport(SwiftUI)
import SwiftUI

struct ChatHistorySidebarView: View {
    let threads: [ChatThread]
    let selectedThreadID: UUID
    let selectThread: (ChatThread) -> Void
    let deleteThread: (ChatThread) -> Void
    let startNewThread: () -> Void
    var topPadding: CGFloat = 0
    var openModelSettings: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Button(action: startNewThread) {
                        Label(KairoL10n.string("chat.new"), systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(KairoGlassButtonStyle(tint: KairoDesign.blue, isProminent: true))
                    .accessibilityIdentifier("chat.new")

                    if let openModelSettings {
                        Button(action: openModelSettings) {
                            Image(systemName: "cpu")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(KairoDesign.teal)
                                .frame(width: 38, height: 38)
                                .chatHistorySidebarIconButton(tint: KairoDesign.teal)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(KairoL10n.string("settings.models.section"))
                        .accessibilityIdentifier("chat.history.models")
                    }
                }

                if threads.isEmpty {
                    KairoFocusCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label(KairoL10n.string("chat.history.empty.title"), systemImage: "clock.arrow.circlepath")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            Text(KairoL10n.string("chat.history.empty.description"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    ForEach(threads) { thread in
                        ChatHistoryRow(
                            thread: thread,
                            isSelected: thread.id == selectedThreadID,
                            select: { selectThread(thread) },
                            delete: { deleteThread(thread) }
                        )
                    }
                }
            }
            .padding(14)
            .padding(.top, topPadding)
        }
        .scrollIndicators(.hidden)
        .background(KairoDesign.background)
    }
}

private struct ChatHistoryRow: View {
    let thread: ChatThread
    let isSelected: Bool
    let select: () -> Void
    let delete: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(thread.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(thread.updatedAt, style: .relative)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(thread.lastMessagePreview)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? KairoDesign.blue.opacity(0.28) : KairoDesign.line, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label(KairoL10n.string("chat.delete"), systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chat.history.thread")
    }

    private var rowBackground: Color {
        isSelected ? KairoDesign.blue.opacity(0.11) : KairoDesign.elevatedSurface
    }
}

private extension View {
    @ViewBuilder
    func chatHistorySidebarIconButton(tint: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: 19, style: .continuous)

        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint.opacity(0.10)).interactive(), in: .rect(cornerRadius: 19))
                .overlay {
                    shape.stroke(KairoDesign.line.opacity(0.48), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.14), radius: 7, x: 0, y: 3)
        } else {
            self
                .background(KairoDesign.groupedSurface.opacity(0.72), in: shape)
                .overlay {
                    shape.stroke(KairoDesign.line.opacity(0.8), lineWidth: 1)
                }
                .shadow(color: KairoDesign.shadow.opacity(0.24), radius: 8, x: 0, y: 4)
        }
    }
}
#endif
