#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isComposerFocused: Bool

    public init(environment: KairoEnvironment = .preview()) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(environment: environment))
    }

    @ViewBuilder
    public var body: some View {
        #if os(iOS)
        NavigationStack {
            chatSurface
                .navigationTitle(viewModel.currentThread.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        newChatButton
                    }
                }
        }
        .task {
            await viewModel.load()
            await viewModel.importPendingShares()
        }
        #else
        NavigationSplitView {
            historyList
                .navigationTitle("History")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        newChatButton
                    }
                }
        } detail: {
            chatSurface
                .navigationTitle(viewModel.currentThread.title)
        }
        .task {
            await viewModel.load()
            await viewModel.importPendingShares()
        }
        #endif
    }

    private var newChatButton: some View {
        Button {
            viewModel.startNewThread()
        } label: {
            Label("New Chat", systemImage: "square.and.pencil")
        }
        .accessibilityIdentifier("chat.new")
    }

    private var historyList: some View {
        List(selection: Binding(
            get: { viewModel.currentThread.id },
            set: { selectedID in
                guard let selectedID, let thread = viewModel.threads.first(where: { $0.id == selectedID }) else { return }
                viewModel.selectThread(thread)
            }
        )) {
            if viewModel.threads.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Send a message to create your first saved chat.")
                )
            } else {
                ForEach(viewModel.threads) { thread in
                    ChatHistoryRow(thread: thread)
                        .tag(thread.id)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.deleteThread(thread) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private var chatSurface: some View {
        VStack(spacing: 0) {
            ChatProviderRouteBar(
                status: viewModel.providerRouteStatus,
                canEdit: viewModel.canEditProviderRoute
            ) { preference in
                Task { await viewModel.setProviderRoutePreference(preference) }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.currentThread.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                ChatBubble(
                                    message: message,
                                    onCopy: copyToPasteboard,
                                    onReply: { viewModel.replyToMessage($0) }
                                )
                                if !message.attachments.isEmpty {
                                    AttachmentStrip(attachments: message.attachments)
                                        .padding(.horizontal)
                                }
                                if !message.proposedActions.isEmpty {
                                    ProposedActionsStrip(actions: message.proposedActions) { action in
                                        viewModel.previewAction(action)
                                    }
                                        .padding(.horizontal)
                                }
                                if !message.toolCandidates.isEmpty {
                                    ToolCandidatesStrip(candidates: message.toolCandidates)
                                        .padding(.horizontal)
                                }
                            }
                            .id(message.id)
                        }

                        if viewModel.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Kairo is thinking…")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color.gray.opacity(0.08))
                .onChange(of: viewModel.currentThread.messages.count) { _, _ in
                    scrollToBottom(proxy)
                }
                .onChange(of: viewModel.isLoading) { _, _ in
                    scrollToBottom(proxy)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
            }

            if let actionResultMessage = viewModel.actionResultMessage {
                Label(actionResultMessage, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityIdentifier("chat.action-result")
            }

            if !viewModel.pendingAttachments.isEmpty {
                AttachmentTray(attachments: viewModel.pendingAttachments) { id in
                    viewModel.removeAttachment(id: id)
                }
            }

            composer
        }
        .sheet(item: $viewModel.pendingAction) { action in
            ActionPreviewView(action: action) {
                Task { await viewModel.confirmPendingAction() }
            } onCancel: {
                viewModel.cancelPendingAction()
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let replyTarget = viewModel.replyTarget {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .foregroundStyle(.secondary)
                    Text(ChatViewModel.replyReferenceText(for: replyTarget))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.cancelReplyTarget()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel reply")
                    .accessibilityIdentifier("chat.reply-preview.cancel")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Reply preview")
                        .accessibilityIdentifier("chat.reply-preview")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Replying to \(ChatViewModel.replyReferenceText(for: replyTarget))")
                .accessibilityIdentifier("chat.reply-preview")
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask Kairo", text: $viewModel.composerText, axis: .vertical)
                    .lineLimit(1...5)
                    .disabled(viewModel.isLoading)
                    .focused($isComposerFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .frame(minHeight: 52, alignment: .center)
                    .accessibilityIdentifier("chat.composer.text")
                    .onSubmit {
                        isComposerFocused = false
                        Task { await viewModel.sendComposerMessage() }
                    }

                Button {
                    isComposerFocused = false
                    Task { await viewModel.sendComposerMessage() }
                } label: {
                    Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 42)
                        .background(sendButtonBackground, in: Circle())
                }
                .disabled((viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty) || viewModel.isLoading)
                .accessibilityLabel("Send")
                .accessibilityIdentifier("chat.composer.send")
            }
            .padding(.leading, 2)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Chat composer input shell")
                    .accessibilityIdentifier("chat.composer.input-shell")
            }
            .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 8)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chat.composer.input-shell")
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(.sRGB, white: 0.98, opacity: 0.96))
        .accessibilityIdentifier("chat.composer.surface")
    }

    private var sendButtonBackground: Color {
        let isDisabled = (viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty) || viewModel.isLoading
        return isDisabled ? Color.gray.opacity(0.45) : Color.accentColor
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.2)) {
            if viewModel.isLoading {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let lastID = viewModel.currentThread.messages.last?.id {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        _ = text
        #endif
    }
}

private struct AttachmentTray: View {
    let attachments: [ChatAttachment]
    let remove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    HStack(spacing: 6) {
                        Image(systemName: iconName(for: attachment.kind))
                        Text(attachment.displayName)
                            .lineLimit(1)
                        Button {
                            remove(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove attachment")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.regularMaterial)
    }
}

private struct AttachmentStrip: View {
    let attachments: [ChatAttachment]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(attachments) { attachment in
                Label(attachment.displayName, systemImage: iconName(for: attachment.kind))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
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

private struct ProposedActionsStrip: View {
    let actions: [AgentAction]
    let onSelect: (AgentAction) -> Void
    private let catalog = SandboxActionCatalog()

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(actions) { action in
                    if let descriptor = catalog.descriptor(for: action.kind) {
                        Button {
                            onSelect(action)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: descriptor.supportStatus == .unsupportedBySandbox ? "exclamationmark.triangle" : "checkmark.circle")
                                Text(descriptor.displayName)
                                CapabilityChipView(descriptor: descriptor)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Action preview: \(descriptor.displayName), \(descriptor.supportStatus.displayName)")
                        .accessibilityIdentifier("chat.proposed-action.\(action.kind.rawValue)")
                    }
                }
            }
        }
        .accessibilityIdentifier("chat.proposed-actions")
    }
}

private struct ToolCandidatesStrip: View {
    let candidates: [AgentToolInvocationCandidate]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(candidates) { candidate in
                    HStack(spacing: 6) {
                        Image(systemName: iconName(for: candidate.skillKind))
                        Text(candidate.title)
                            .lineLimit(1)
                        Text(candidate.skillKind.settingsTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Tool candidate: \(candidate.title), \(candidate.skillKind.settingsTitle)")
                    .accessibilityIdentifier("chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id)")
                }
            }
        }
        .accessibilityIdentifier("chat.tool-candidates")
    }

    private func iconName(for kind: AgentSkillKind) -> String {
        switch kind {
        case .homeKitControl:
            return "house"
        case .shortcutWorkflow:
            return "square.stack.3d.up"
        case .oauthConnector:
            return "person.crop.circle.badge.checkmark"
        case .localModel:
            return "cpu"
        case .custom:
            return "wrench.and.screwdriver"
        }
    }
}

private struct ChatHistoryRow: View {
    let thread: ChatThread

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(thread.title)
                .font(.headline)
                .lineLimit(1)
            Text(thread.lastMessagePreview)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(thread.updatedAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chat.history.thread")
    }
}

private struct ChatBubble: View {
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

    private func messageActionButton(
        title: String,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) message")
        .accessibilityIdentifier(identifier)
    }
}
#endif
