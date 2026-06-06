#if canImport(SwiftUI)
import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let onCopy: (String) -> Void
    let onReply: (ChatMessage) -> Void
    @State private var isReasoningExpanded = false

    private var isUser: Bool { message.role == .user }
    private var bubbleMaxWidth: CGFloat { isUser ? 306 : 334 }
    private var oppositeSideSpacerWidth: CGFloat { isUser ? 42 : 34 }
    private var bubbleAlignment: Alignment { isUser ? .trailing : .leading }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: oppositeSideSpacerWidth) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .font(.callout)
                    .foregroundStyle(isUser ? .white : KairoDesign.ink)
                    .textSelection(.enabled)
                    .lineSpacing(1)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: bubbleMaxWidth, alignment: bubbleAlignment)
                    .contextMenu {
                        Button {
                            onCopy(message.text)
                        } label: {
                            Label(KairoL10n.string("chat.message.copy"), systemImage: "doc.on.doc")
                        }
                        .accessibilityIdentifier("chat.message.copy-menu.\(message.id.uuidString)")

                        Button {
                            onReply(message)
                        } label: {
                            Label(KairoL10n.string("chat.message.reply"), systemImage: "arrowshape.turn.up.left")
                        }
                        .accessibilityIdentifier("chat.message.reply-menu.\(message.id.uuidString)")
                    }

                if let reasoningText = message.reasoningText, !reasoningText.isEmpty, !isUser {
                    DisclosureGroup(
                        isExpanded: $isReasoningExpanded,
                        content: {
                            Text(reasoningText)
                                .font(.caption)
                                .foregroundStyle(KairoDesign.muted)
                                .textSelection(.enabled)
                                .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                                .padding(.top, 4)
                        },
                        label: {
                            Label(KairoL10n.string("chat.message.reasoning"), systemImage: "brain.head.profile")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(KairoDesign.muted)
                        }
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                    .background(KairoDesign.softSurface.opacity(0.48), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .accessibilityIdentifier("chat.message.reasoning.\(message.id.uuidString)")
                }

                HStack(spacing: 6) {
                    if message.status == .failed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text(message.createdAt, style: .time)
                    if !isUser, message.memoryContextCount > 0 {
                        Label(memoryContextLabel, systemImage: "brain.head.profile")
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(memoryContextLabel)
                            .accessibilityIdentifier("chat.message.memory-context")
                    }
                    messageActionButton(
                        title: KairoL10n.string("chat.message.copy"),
                        accessibilityLabel: KairoL10n.string("chat.message.copyAccessibility"),
                        systemImage: "doc.on.doc",
                        identifier: "chat.message.copy.\(message.id.uuidString)"
                    ) {
                        onCopy(message.text)
                    }

                    messageActionButton(
                        title: KairoL10n.string("chat.message.reply"),
                        accessibilityLabel: KairoL10n.string("chat.message.replyAccessibility"),
                        systemImage: "arrowshape.turn.up.left",
                        identifier: "chat.message.reply.\(message.id.uuidString)"
                    ) {
                        onReply(message)
                    }
                }
                .font(.caption2)
                .foregroundStyle(KairoDesign.muted)
                .padding(.horizontal, 6)
            }

            if !isUser { Spacer(minLength: oppositeSideSpacerWidth) }
        }
        .padding(.horizontal, 14)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message.text)
        .accessibilityIdentifier(isUser ? "chat.message.user" : "chat.message.assistant")
    }

    private var bubbleColor: Color {
        if isUser { return .accentColor }
        if message.status == .failed { return Color.orange.opacity(0.16) }
        return KairoDesign.elevatedSurface.opacity(0.72)
    }

    private var memoryContextLabel: String {
        if message.memoryContextCount == 1 {
            return KairoL10n.string("chat.message.memoryContext.one")
        }
        return KairoL10n.string("chat.message.memoryContext.many", Int64(message.memoryContextCount))
    }

    private func messageActionButton(
        title: String,
        accessibilityLabel: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(KairoDesign.muted)
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(identifier)
    }
}
#endif
