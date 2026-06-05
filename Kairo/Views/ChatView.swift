#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    private let actionDescriptorProvider: any AgentActionDescriptorProviding
    private let chromeActionRequest: ChatChromeActionRequest?
    @State private var showToolPalette = false
    @FocusState private var isComposerFocused: Bool

    public init(dependencies: ChatFeatureDependencies, chromeActionRequest: ChatChromeActionRequest? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(dependencies: dependencies))
        self.actionDescriptorProvider = dependencies.actionDescriptorProvider
        self.chromeActionRequest = chromeActionRequest
    }

    public init(environment: KairoEnvironment = .preview()) {
        self.init(dependencies: environment.chatFeatureDependencies)
    }

    @ViewBuilder
    public var body: some View {
        #if os(iOS)
        chatSurface
        .task {
            await viewModel.load()
            await viewModel.importPendingShares()
        }
        .onChange(of: chromeActionRequest) { _, request in
            handleChromeAction(request)
        }
        #else
        NavigationSplitView {
            ChatHistorySidebarView(
                threads: viewModel.threads,
                selectedThreadID: viewModel.currentThread.id,
                selectThread: { thread in
                    viewModel.selectThread(thread)
                },
                deleteThread: { thread in
                    Task { await viewModel.deleteThread(thread) }
                },
                startNewThread: {
                    viewModel.startNewThread()
                }
            )
                .navigationTitle(KairoL10n.string("chat.history.title"))
        } detail: {
            chatSurface
                .navigationTitle(viewModel.currentThread.title)
        }
        .task {
            await viewModel.load()
            await viewModel.importPendingShares()
        }
        .onChange(of: chromeActionRequest) { _, request in
            handleChromeAction(request)
        }
        #endif
    }

    private func handleChromeAction(_ request: ChatChromeActionRequest?) {
        guard let request else { return }
        switch request.kind {
        case .newThread:
            viewModel.startNewThread()
            isComposerFocused = true
        case .newPrivateThread:
            viewModel.startPrivateThread()
            isComposerFocused = true
        case .selectThread(let id):
            Task { await viewModel.selectThread(id: id) }
        case .clear:
            Task { await viewModel.clearCurrentThread() }
        case .delete:
            Task { await viewModel.deleteCurrentThread() }
        case .compact:
            viewModel.prepareCompactPrompt()
            isComposerFocused = true
        case .fork:
            Task { await viewModel.forkCurrentThread() }
        }
    }

    private var chatSurface: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.currentThread.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                ChatBubble(
                                    message: message,
                                    onCopy: copyToPasteboard,
                                    onReply: { viewModel.replyToMessage($0) },
                                    onRemember: { message in
                                        Task { await viewModel.rememberMessage(message) }
                                    }
                                )
                                if !message.attachments.isEmpty {
                                    AttachmentStrip(attachments: message.attachments)
                                        .padding(.horizontal)
                                }
                                if !message.proposedActions.isEmpty {
                                    ProposedActionsStrip(
                                        actions: message.proposedActions,
                                        descriptorProvider: actionDescriptorProvider
                                    ) { action in
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
                                Text(KairoL10n.string("chat.loading"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.top, chatMessagesTopPadding)
                    .padding(.bottom, 16)
                }
                .background(Color.clear)
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
                Label(actionResultMessage, systemImage: viewModel.actionResultSucceeded == false ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(viewModel.actionResultSucceeded == false ? .orange : .green)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .accessibilityIdentifier("chat.action-result")
            }

            if let shareImportNotice = viewModel.shareImportNotice {
                ShareImportBanner(
                    notice: shareImportNotice,
                    preview: viewModel.shareImportPreview,
                    canSend: viewModel.canSendImportedShareToChat,
                    actionTitle: viewModel.shareImportPrimaryActionTitle,
                    send: {
                        Task { await viewModel.sendImportedShareToChat() }
                    }
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if let shareImportReviewAction = viewModel.shareImportReviewAction {
                ShareActionReviewBanner(action: shareImportReviewAction) {
                    viewModel.reviewImportedShareAction()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if let calendarReviewAction = viewModel.calendarReviewAction {
                CalendarActionReviewBanner(action: calendarReviewAction) {
                    viewModel.reviewCalendarAction()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if let handoffReviewAction = viewModel.handoffReviewAction {
                HandoffActionReviewBanner(
                    action: handoffReviewAction,
                    descriptorProvider: actionDescriptorProvider
                ) {
                    viewModel.reviewHandoffAction()
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            if !viewModel.pendingAttachments.isEmpty {
                AttachmentTray(attachments: viewModel.pendingAttachments) { id in
                    viewModel.removeAttachment(id: id)
                }
            }

            composer
        }
        .sheet(item: $viewModel.pendingAction) { action in
            ActionPreviewView(
                action: action,
                descriptorProvider: actionDescriptorProvider
            ) {
                Task { await viewModel.confirmPendingAction() }
            } onCancel: {
                viewModel.cancelPendingAction()
            }
        }
    }

    private var chatMessagesTopPadding: CGFloat {
        viewModel.currentThread.messages.count <= 1 ? 116 : 16
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if let replyTarget = viewModel.replyTarget {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(KairoDesign.teal)
                        .frame(width: 24, height: 24)
                        .background(KairoDesign.softSurface.opacity(0.62), in: Circle())
                    Text(ChatViewModel.replyReferenceText(for: replyTarget))
                        .font(.caption)
                        .foregroundStyle(KairoDesign.ink)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        viewModel.cancelReplyTarget()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(KairoDesign.muted)
                            .frame(width: 24, height: 24)
                            .background(KairoDesign.softSurface.opacity(0.55), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(KairoL10n.string("chat.reply.cancel"))
                    .accessibilityIdentifier("chat.reply-preview.cancel")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(KairoDesign.elevatedSurface.opacity(0.84), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(KairoDesign.line, lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Color.clear
                        .frame(width: 1, height: 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(KairoL10n.string("chat.reply.preview"))
                        .accessibilityIdentifier("chat.reply-preview")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(KairoL10n.string("chat.replyingTo", ChatViewModel.replyReferenceText(for: replyTarget)))
                .accessibilityIdentifier("chat.reply-preview")
            }

            composerStatusRow

            if showToolPalette {
                toolPalette
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(alignment: .center, spacing: 7) {
                toolMenu

                TextField(KairoL10n.string("chat.composer.placeholder"), text: $viewModel.composerText, axis: .vertical)
                    .lineLimit(1...5)
                    .disabled(viewModel.isLoading)
                    .focused($isComposerFocused)
                    .foregroundStyle(KairoDesign.ink)
                    .tint(KairoDesign.blue)
                    .font(.callout)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: 34, alignment: .center)
                    .accessibilityIdentifier("chat.composer.text")
                    .onSubmit {
                        isComposerFocused = false
                        Task { await viewModel.sendComposerMessage() }
                    }

                Button {
                    isComposerFocused = false
                    showToolPalette = false
                    Task { await viewModel.sendComposerMessage() }
                } label: {
                    Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(sendButtonForeground)
                        .frame(width: 30, height: 30)
                        .background {
                            Circle()
                                .fill(KairoDesign.elevatedSurface.opacity(isSendDisabled ? 0.72 : 0.88))
                        }
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        }
                }
                .disabled(isSendDisabled)
                .accessibilityLabel(KairoL10n.string("chat.composer.send"))
                .accessibilityIdentifier("chat.composer.send")
            }
            .padding(.leading, 5)
            .padding(.trailing, 5)
            .padding(.vertical, 3)
            .background(KairoDesign.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Color.clear
                    .frame(width: 1, height: 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(KairoL10n.string("chat.composer.inputShell"))
                    .accessibilityIdentifier("chat.composer.input-shell")
            }
            .shadow(color: KairoDesign.shadow.opacity(0.8), radius: 12, x: 0, y: 7)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("chat.composer.input-shell")
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .background(
            LinearGradient(
                colors: [
                    KairoDesign.background.opacity(0.02),
                    KairoDesign.background.opacity(0.22),
                    KairoDesign.background.opacity(0.56)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .accessibilityIdentifier("chat.composer.surface")
    }

    private var composerStatusRow: some View {
        ChatProviderRouteBar(
            status: viewModel.providerRouteStatus,
            canEdit: viewModel.canEditProviderRoute,
            selectOption: { option in
                Task { await viewModel.selectProviderRouteOption(option) }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.composer.status-row")
    }

    private var toolMenu: some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                showToolPalette.toggle()
            }
        } label: {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(KairoDesign.elevatedSurface.opacity(showToolPalette ? 0.88 : 0.72))
                }
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KairoL10n.string("chat.tools.open"))
        .accessibilityIdentifier("chat.tools.menu")
    }

    private var toolPalette: some View {
        VStack(spacing: 7) {
            capabilityPromptButton(
                title: KairoL10n.string("chat.tools.phoneTools"),
                systemImage: "iphone.gen3",
                prompt: KairoL10n.string("chat.tools.phoneTools.prompt")
            )
            capabilityPromptButton(
                title: KairoL10n.string("chat.tools.reminderCalendar"),
                systemImage: "calendar.badge.plus",
                prompt: KairoL10n.string("chat.tools.reminderCalendar.prompt")
            )
            capabilityPromptButton(
                title: KairoL10n.string("chat.tools.messageEmailDraft"),
                systemImage: "envelope",
                prompt: KairoL10n.string("chat.tools.messageEmailDraft.prompt")
            )
            capabilityPromptButton(
                title: KairoL10n.string("chat.tools.summarizeSharedContent"),
                systemImage: "doc.text.magnifyingglass",
                prompt: KairoL10n.string("chat.tools.summarizeSharedContent.prompt")
            )
        }
        .padding(8)
        .background(KairoDesign.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.tools.palette")
    }

    private func capabilityPromptButton(
        title: String,
        systemImage: String,
        prompt: String
    ) -> some View {
        Button {
            applyPrompt(prompt)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .frame(width: 30, height: 30)
                    .background(KairoDesign.softSurface.opacity(0.55), in: Circle())

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(KairoDesign.softSurface.opacity(0.55), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func applyPrompt(_ prompt: String) {
        showToolPalette = false
        viewModel.composerText = prompt
        isComposerFocused = true
    }

    private var isSendDisabled: Bool {
        (viewModel.composerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && viewModel.pendingAttachments.isEmpty) || viewModel.isLoading
    }

    private var sendButtonForeground: Color {
        isSendDisabled ? KairoDesign.muted : KairoDesign.blue
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
                        .accessibilityLabel(KairoL10n.string("chat.attachment.remove"))
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

public struct ChatChromeActionRequest: Equatable {
    public let id = UUID()
    public let kind: ChatChromeActionKind

    public init(kind: ChatChromeActionKind) {
        self.kind = kind
    }
}

public enum ChatChromeActionKind: Equatable {
    case newThread
    case newPrivateThread
    case selectThread(UUID)
    case clear
    case delete
    case compact
    case fork
}

#endif
