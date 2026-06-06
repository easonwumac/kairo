#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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
                VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                    if !message.attachments.isEmpty {
                        ChatAttachmentPreviewGrid(attachments: message.attachments, maxWidth: bubbleMaxWidth)
                    }

                    if !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(message.text)
                            .font(.callout)
                            .foregroundStyle(isUser ? .white : KairoDesign.ink)
                            .textSelection(.enabled)
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
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

private struct ChatAttachmentPreviewGrid: View {
    let attachments: [ChatAttachment]
    let maxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(attachments) { attachment in
                ChatAttachmentPreview(attachment: attachment, maxWidth: maxWidth - 22)
            }
        }
        .accessibilityIdentifier("chat.message.attachments")
    }
}

private struct ChatAttachmentPreview: View {
    let attachment: ChatAttachment
    let maxWidth: CGFloat

    var body: some View {
        if attachment.kind == .image, let image = localImage {
            image
                .resizable()
                .scaledToFill()
                .frame(maxWidth: maxWidth, minHeight: 132, maxHeight: 210)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    attachmentCaption
                }
                .accessibilityLabel(attachment.displayName)
                .accessibilityIdentifier("chat.message.attachment.image")
        } else {
            HStack(spacing: 7) {
                Image(systemName: iconName(for: attachment.kind))
                    .font(.caption.weight(.semibold))
                Text(attachment.displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(KairoDesign.muted)
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(KairoDesign.softSurface.opacity(0.54), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .accessibilityIdentifier("chat.message.attachment.file")
        }
    }

    private var attachmentCaption: some View {
        Text(attachment.displayName)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.black.opacity(0.38), in: Capsule())
            .padding(7)
    }

    private var localImage: Image? {
        guard let fileURL = attachment.fileURL else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(contentsOfFile: fileURL.path) else { return nil }
        return Image(uiImage: uiImage)
        #elseif canImport(AppKit)
        guard let nsImage = NSImage(contentsOf: fileURL) else { return nil }
        return Image(nsImage: nsImage)
        #else
        return nil
        #endif
    }
}

private func iconName(for kind: AttachmentKind) -> String {
    switch kind {
    case .text: return "doc.text"
    case .url: return "link"
    case .image: return "photo"
    case .pdf: return "doc.richtext"
    case .file: return "doc"
    case .unknown: return "questionmark.square"
    }
}
#endif
