#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var showMoreFocusStarts = false
    @FocusState private var isComposerFocused: Bool

    public init(environment: KairoEnvironment = .preview()) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(environment: environment))
    }

    @ViewBuilder
    public var body: some View {
        #if os(iOS)
        chatSurface
        .task {
            await viewModel.load()
            await viewModel.importPendingShares()
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
        #endif
    }

    private var shouldShowFocusPanel: Bool {
        viewModel.currentThread.messages.count <= 1
    }

    private var chatFocusPanel: some View {
        KairoFocusCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(KairoL10n.string("chat.focus.title"))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(KairoL10n.string("chat.focus.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                KairoCommandButton(
                    title: KairoL10n.string("chat.focus.shared.title"),
                    subtitle: KairoL10n.string("chat.focus.shared.subtitle"),
                    systemImage: "square.and.arrow.down",
                    tint: KairoDesign.blue
                ) {
                    applyPrompt(KairoL10n.string("chat.tools.summarizeSharedContent.prompt"))
                }

                Button {
                    withAnimation(.snappy(duration: 0.2)) {
                        showMoreFocusStarts.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: showMoreFocusStarts ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(KairoDesign.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(KairoL10n.string("chat.focus.more.title"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(KairoDesign.ink)
                            Text(KairoL10n.string("chat.focus.more.subtitle"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .background(KairoDesign.groupedSurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("chat.focus.more.toggle")

                if showMoreFocusStarts {
                    HStack(spacing: 8) {
                        ChatFocusChip(
                            title: KairoL10n.string("chat.focus.plan.title"),
                            systemImage: "calendar.badge.plus",
                            tint: KairoDesign.amber
                        ) {
                            applyPrompt(KairoL10n.string("chat.tools.reminderCalendar.prompt"))
                        }

                        ChatFocusChip(
                            title: KairoL10n.string("chat.focus.reply.title"),
                            systemImage: "envelope.open",
                            tint: KairoDesign.violet
                        ) {
                            applyPrompt(KairoL10n.string("chat.tools.messageEmailDraft.prompt"))
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.focus-panel")
    }

    private var chatSurface: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if shouldShowFocusPanel {
                            chatFocusPanel
                                .padding(.horizontal, 14)
                                .padding(.bottom, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

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
                                Text(KairoL10n.string("chat.loading"))
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
                .background(KairoDesign.background)
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
                HandoffActionReviewBanner(action: handoffReviewAction) {
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
                    .accessibilityLabel(KairoL10n.string("chat.reply.cancel"))
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
                        .accessibilityLabel(KairoL10n.string("chat.reply.preview"))
                        .accessibilityIdentifier("chat.reply-preview")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(KairoL10n.string("chat.replyingTo", ChatViewModel.replyReferenceText(for: replyTarget)))
                .accessibilityIdentifier("chat.reply-preview")
            }

            composerStatusRow

            HStack(alignment: .bottom, spacing: 10) {
                toolMenu

                TextField(KairoL10n.string("chat.composer.placeholder"), text: $viewModel.composerText, axis: .vertical)
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
                .accessibilityLabel(KairoL10n.string("chat.composer.send"))
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
                    .accessibilityLabel(KairoL10n.string("chat.composer.inputShell"))
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

    private var composerStatusRow: some View {
        ChatProviderRouteBar(
            status: viewModel.providerRouteStatus,
            isPrivateChatEnabled: viewModel.isPrivateChatEnabled,
            canEdit: viewModel.canEditProviderRoute,
            togglePrivateChat: {
                viewModel.setPrivateChatEnabled(!viewModel.isPrivateChatEnabled)
            },
            setPreference: { preference in
                Task { await viewModel.setProviderRoutePreference(preference) }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.composer.status-row")
    }

    private var toolMenu: some View {
        Menu {
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
        } label: {
            Image(systemName: "plus")
                .font(.headline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .frame(width: 42, height: 42)
                .background(Color.primary.opacity(0.06), in: Circle())
        }
        .accessibilityLabel(KairoL10n.string("chat.tools.open"))
        .accessibilityIdentifier("chat.tools.menu")
    }

    private func capabilityPromptButton(
        title: String,
        systemImage: String,
        prompt: String
    ) -> some View {
        Button {
            applyPrompt(prompt)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func applyPrompt(_ prompt: String) {
        viewModel.composerText = prompt
        isComposerFocused = true
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

private struct ChatFocusChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(tint.opacity(0.16), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
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

#endif
