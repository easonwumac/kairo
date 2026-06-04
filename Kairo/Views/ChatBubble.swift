#if canImport(SwiftUI)
import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    let onCopy: (String) -> Void
    let onReply: (ChatMessage) -> Void

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 44) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 5) {
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contextMenu {
                        Button {
                            onCopy(message.text)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        .accessibilityIdentifier("chat.message.copy-menu.\(message.id.uuidString)")

                        Button {
                            onReply(message)
                        } label: {
                            Label("Reply", systemImage: "arrowshape.turn.up.left")
                        }
                        .accessibilityIdentifier("chat.message.reply-menu.\(message.id.uuidString)")
                    }

                HStack(spacing: 6) {
                    if message.status == .failed {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                    }
                    Text(message.createdAt, style: .time)
                    if !isUser, message.memoryContextCount > 0 {
                        Label(memoryContextLabel, systemImage: "brain.head.profile")
                            .accessibilityIdentifier("chat.message.memory-context")
                    }
                    messageActionButton(
                        title: "Copy",
                        systemImage: "doc.on.doc",
                        identifier: "chat.message.copy.\(message.id.uuidString)"
                    ) {
                        onCopy(message.text)
                    }

                    messageActionButton(
                        title: "Reply",
                        systemImage: "arrowshape.turn.up.left",
                        identifier: "chat.message.reply.\(message.id.uuidString)"
                    ) {
                        onReply(message)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            }

            if !isUser { Spacer(minLength: 44) }
        }
        .padding(.horizontal)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message.text)
        .accessibilityIdentifier(isUser ? "chat.message.user" : "chat.message.assistant")
    }

    private var bubbleColor: Color {
        if isUser { return .accentColor }
        if message.status == .failed { return Color.orange.opacity(0.16) }
        return Color.primary.opacity(0.06)
    }

    private var memoryContextLabel: String {
        let suffix = message.memoryContextCount == 1 ? "" : "s"
        return "Used \(message.memoryContextCount) memory item\(suffix)"
    }

    private func messageActionButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 24)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) message")
        .accessibilityIdentifier(identifier)
    }
}
#endif
