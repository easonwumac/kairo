#if canImport(SwiftUI)
import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public struct ChatView: View {
    @StateObject private var viewModel: ChatViewModel
    private let actionDescriptorProvider: any AgentActionDescriptorProviding
    private let chromeActionRequest: ChatChromeActionRequest?
    private let openModelSettings: () -> Void
    @Binding var rootChromeBackRequestID: Int
    let usesRootChromeNavigation: Bool
    @State private var showToolPalette = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var captureStatusMessage: String?
    @State private var rawJSONPanelText: String?
    @State private var showRawJSONPage: Bool = false
    @FocusState private var isComposerFocused: Bool

    public init(
        dependencies: ChatFeatureDependencies,
        chromeActionRequest: ChatChromeActionRequest? = nil,
        openModelSettings: @escaping () -> Void = {},
        rootChromeBackRequestID: Binding<Int> = .constant(0),
        usesRootChromeNavigation: Bool = false
    ) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(dependencies: dependencies))
        self.actionDescriptorProvider = dependencies.actionDescriptorProvider
        self.chromeActionRequest = chromeActionRequest
        self.openModelSettings = openModelSettings
        _rootChromeBackRequestID = rootChromeBackRequestID
        self.usesRootChromeNavigation = usesRootChromeNavigation
    }

    public init(environment: KairoEnvironment = .preview()) {
        self.init(dependencies: environment.chatFeatureDependencies)
    }

    @ViewBuilder
    public var body: some View {
        #if os(iOS)
        ZStack {
            chatSurface
                .task {
                    await viewModel.load()
                    await viewModel.importPendingShares()
                }
                .onChange(of: chromeActionRequest) { _, request in
                    handleChromeAction(request)
                }
                .onChange(of: selectedPhotoItems) { _, items in
                    guard !items.isEmpty else { return }
                    Task { await importPhotos(items) }
                }

            if showRawJSONPage, let text = rawJSONPanelText {
                ChatRawJSONPage(rawJSON: text) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                        showRawJSONPage = false
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .zIndex(100)
            }
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
        .preference(key: RootChromePreferenceKey.self, value: rawJSONChromeContext)
        .onChange(of: rootChromeBackRequestID) { _, _ in
            if showRawJSONPage {
                withAnimation(.snappy(duration: 0.2)) {
                    showRawJSONPage = false
                }
            }
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
                        if let summary = viewModel.promptPipelineHealthSummary {
                            ChatPromptPipelineHealthCard(
                                summary: summary,
                                canTuneModel: viewModel.canEditProviderRoute,
                                openModelSettings: openModelSettings
                            )
                                .padding(.horizontal, 14)
                                .id("pipeline-health")
                        }

                        ForEach(viewModel.currentThread.messages) { message in
                            VStack(alignment: .leading, spacing: 8) {
                                ChatBubble(
                                    message: message,
                                    onCopy: copyToPasteboard,
                                    onReply: { viewModel.replyToMessage($0) },
                                    onShowRawJSON: { rawJSON in
                                        rawJSONPanelText = rawJSON
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                                            showRawJSONPage = true
                                        }
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
                                Text(viewModel.inferenceStatusText)
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
        .overlay(alignment: .top) {
            chatTopMistOverlay
        }
    }

    private var rawJSONChromeContext: RootChromeContext {
        if showRawJSONPage {
            RootChromeContext(leadingAction: .back, title: KairoL10n.string("chat.message.rawJSON"))
        } else {
            .standard
        }
    }

    private var chatMessagesTopPadding: CGFloat {
        viewModel.currentThread.messages.count <= 1 ? 132 : 58
    }

    private var chatTopMistOverlay: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        KairoDesign.background.opacity(0.82),
                        KairoDesign.background.opacity(0.36),
                        KairoDesign.background.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .frame(height: 122)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black.opacity(0.92), location: 0.54),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var composer: some View {
        chatComposerGlassContainer {
            VStack(spacing: 8) {
                if let replyTarget = viewModel.replyTarget {
                    HStack(spacing: 8) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(KairoDesign.teal)
                            .frame(width: 24, height: 24)
                            .chatComposerGlassCircle(tint: KairoDesign.teal, isInteractive: false)
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
                                .chatComposerGlassCircle(tint: KairoDesign.muted, isInteractive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(KairoL10n.string("chat.reply.cancel"))
                        .accessibilityIdentifier("chat.reply-preview.cancel")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .chatComposerGlassSurface(cornerRadius: 16, tint: KairoDesign.teal, isInteractive: false)
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
                            .chatComposerGlassCircle(tint: isSendDisabled ? KairoDesign.muted : KairoDesign.blue, isInteractive: !isSendDisabled)
                    }
                    .disabled(isSendDisabled)
                    .accessibilityLabel(KairoL10n.string("chat.composer.send"))
                    .accessibilityIdentifier("chat.composer.send")
                }
                .padding(.leading, 5)
                .padding(.trailing, 5)
                .padding(.vertical, 3)
                .chatComposerGlassSurface(cornerRadius: 17, tint: KairoDesign.blue, isInteractive: true)
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
            openModelSettings: openModelSettings,
            selectOption: { option in
                Task { await viewModel.selectProviderRouteOption(option) }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.composer.status-row")
    }

    private var toolMenu: some View {
        Button {
            isComposerFocused = false
            withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                showToolPalette = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)
                .frame(width: 30, height: 30)
                .chatComposerGlassCircle(tint: showToolPalette ? KairoDesign.teal : KairoDesign.blue, isInteractive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(KairoL10n.string("chat.tools.open"))
        .accessibilityIdentifier("chat.tools.menu")
    }

    private var toolPalette: some View {
        VStack(spacing: 7) {
            capturePalette
        }
        .padding(8)
        .chatComposerGlassSurface(cornerRadius: 18, tint: KairoDesign.teal, isInteractive: false)
        .shadow(color: KairoDesign.shadow.opacity(0.75), radius: 16, x: 0, y: 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.tools.palette")
    }

    @ViewBuilder
    private var capturePalette: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                #if canImport(PhotosUI)
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 6, matching: .images) {
                    HStack(spacing: 6) {
                        captureButtonLabel(
                            title: KairoL10n.string("chat.capture.photoLibrary"),
                            systemImage: "photo.on.rectangle"
                        )
                        if !selectedPhotoItems.isEmpty {
                            Text("\(selectedPhotoItems.count)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(KairoDesign.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(KairoDesign.blue.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat.capture.photo-library")
                #else
                captureButtonLabel(title: KairoL10n.string("chat.capture.photoLibrary"), systemImage: "photo.on.rectangle")
                    .accessibilityIdentifier("chat.capture.photo-library")
                #endif

                Button {
                    handleCameraCaptureRequest()
                } label: {
                    captureButtonLabel(
                        title: KairoL10n.string("chat.capture.camera"),
                        systemImage: "camera.fill"
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat.capture.camera")
            }

            if let captureStatusMessage {
                Label(captureStatusMessage, systemImage: "info.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(KairoDesign.amber)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chat.capture.status")
            }
        }
        .padding(.bottom, 3)
    }

    private func captureButtonLabel(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(KairoDesign.ink)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .chatComposerGlassSurface(cornerRadius: 13, tint: KairoDesign.teal, isInteractive: true)
    }

    private func handleCameraCaptureRequest() {
        #if canImport(UIKit)
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            captureStatusMessage = KairoL10n.string("chat.capture.cameraUnavailable")
            return
        }
        captureStatusMessage = KairoL10n.string("chat.capture.cameraRequiresDevice")
        #else
        captureStatusMessage = KairoL10n.string("chat.capture.cameraUnavailable")
        #endif
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        #if canImport(PhotosUI)
        var attachments: [ChatAttachment] = []
        for item in items {
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else { continue }
                let normalizedData = Self.normalizedImageDataForAIAnalysis(from: data)
                let fileURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("kairo-photo-\(UUID().uuidString).jpg")
                try normalizedData.write(to: fileURL, options: .atomic)
                let visionReference = await AttachmentVisionAnalyzer.reference(from: normalizedData)
                let attachment = ChatAttachment(
                    kind: .image,
                    displayName: fileURL.lastPathComponent,
                    uniformTypeIdentifier: "public.jpeg",
                    fileURL: fileURL,
                    byteCount: Int64(normalizedData.count),
                    textPreview: visionReference.promptPreview.map {
                        KairoL10n.string("chat.capture.photoVisionTextPreview", $0)
                    } ?? KairoL10n.string("chat.capture.photoTextPreview"),
                    source: .photoPicker
                )
                attachments.append(attachment)
            } catch {
                await MainActor.run {
                    captureStatusMessage = KairoL10n.string("chat.capture.photoImportFailed")
                }
            }
        }
        await MainActor.run {
            for attachment in attachments {
                viewModel.addAttachment(attachment)
            }
            captureStatusMessage = nil
            showToolPalette = false
            selectedPhotoItems = []
        }
        #else
        _ = items
        #endif
    }

    private static func normalizedImageDataForAIAnalysis(from data: Data) -> Data {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return data }
        let maxDimension: CGFloat = 1_600
        let largestSide = max(image.size.width, image.size.height)
        let targetSize: CGSize
        if largestSide > maxDimension {
            let scale = maxDimension / largestSide
            targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            targetSize = image.size
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return renderedImage.jpegData(compressionQuality: 0.82) ?? data
        #else
        return data
        #endif
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

private struct ChatPromptPipelineHealthCard: View {
    let summary: ChatPromptPipelineHealthSummary
    let canTuneModel: Bool
    let openModelSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 11) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(KairoL10n.string("chat.pipeline.health.title"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(KairoDesign.ink)
                        Text(summary.providerID)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(tint.opacity(0.10), in: Capsule())
                    }

                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(KairoDesign.muted)
                        .lineLimit(2)
                }

                Spacer(minLength: 8)

                Text(validationPercent)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
                    .monospacedDigit()
            }

            if summary.shouldOfferModelTuning, canTuneModel {
                Button {
                    openModelSettings()
                } label: {
                    Label(KairoL10n.string("chat.pipeline.health.tune"), systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(tint.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chat.pipeline.health.tune")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .kairoGlassCard(tint: tint, cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("chat.pipeline.health")
    }

    private var detailText: String {
        KairoL10n.string(
            "chat.pipeline.health.detail",
            Int64(summary.traceCount),
            Int64(summary.repairCount),
            Int64(summary.failedCount)
        )
    }

    private var validationPercent: String {
        "\(Int((summary.validationRate * 100).rounded()))%"
    }

    private var tint: Color {
        switch summary.latestStatus {
        case .validated:
            return KairoDesign.teal
        case .needsRepair, .needsReview:
            return KairoDesign.amber
        case .failed:
            return .orange
        }
    }

    private var iconName: String {
        switch summary.latestStatus {
        case .validated:
            return "waveform.path.ecg"
        case .needsRepair:
            return "arrow.triangle.2.circlepath"
        case .needsReview:
            return "eye.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
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
                            .truncationMode(.middle)
                        Button {
                            remove(attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(KairoL10n.string("chat.attachment.remove"))
                    }
                    .font(.caption)
                    .foregroundStyle(KairoDesign.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: 220)
                    .background(KairoDesign.elevatedSurface.opacity(0.68), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

private struct ChatRawJSONPage: View {
    let rawJSON: String
    let close: () -> Void

    var body: some View {
        InfoPageJSONView(json: rawJSON)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(KairoDesign.background)
    }
}

private struct InfoPageJSONView: View {
    let json: String

    private struct ParsedInfo {
        var title: String = ""
        var category: String = ""
        var summary: String = ""
        var assetDescription: String = ""
        var ocrSummary: String = ""
        var keywords: [String] = []
        var candidateCategories: [(folder: String, reason: String)] = []
        var facts: [(label: String, value: String)] = []
        var confidence: Double = 0
    }

    private var info: ParsedInfo {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return ParsedInfo() }
        var result = ParsedInfo()
        result.title = dict["title"] as? String ?? ""
        result.category = dict["category"] as? String ?? ""
        result.summary = dict["summary"] as? String ?? ""
        result.assetDescription = dict["assetDescription"] as? String ?? ""
        result.ocrSummary = dict["ocrSummary"] as? String ?? ""
        result.keywords = dict["keywords"] as? [String] ?? []
        result.confidence = dict["confidence"] as? Double ?? 0
        if let facts = dict["facts"] as? [[String: Any]] {
            result.facts = facts.compactMap {
                guard let label = $0["label"] as? String, let value = $0["value"] as? String else { return nil }
                return (label, value)
            }
        }
        if let cats = dict["candidateCategories"] as? [[String: Any]] {
            result.candidateCategories = cats.compactMap {
                guard let folder = $0["folderName"] as? String, let reason = $0["reason"] as? String else { return nil }
                return (folder, reason)
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !info.title.isEmpty {
                    infoField(label: "Title", value: info.title)
                }

                HStack(spacing: 10) {
                    if !info.category.isEmpty {
                        infoPill(info.category, tint: .blue)
                    }
                    if info.confidence > 0 {
                        infoPill(String(format: "%.0f%%", info.confidence * 100), tint: .green)
                    }
                }

                if !info.summary.isEmpty {
                    infoField(label: "Summary", value: info.summary)
                }

                if !info.assetDescription.isEmpty {
                    infoField(label: "Description", value: info.assetDescription)
                }

                if !info.ocrSummary.isEmpty {
                    infoField(label: "OCR", value: info.ocrSummary)
                }

                if !info.keywords.isEmpty {
                    infoSection("Keywords") {
                        InfoPageKeywordTags(keywords: info.keywords)
                    }
                }

                if !info.candidateCategories.isEmpty {
                    infoSection("Categories") {
                        ForEach(info.candidateCategories.indices, id: \.self) { i in
                            let cat = info.candidateCategories[i]
                            HStack(spacing: 6) {
                                infoPill(cat.folder, tint: .orange)
                                Text(cat.reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !info.facts.isEmpty {
                    infoSection("Facts") {
                        ForEach(info.facts.indices, id: \.self) { i in
                            let fact = info.facts[i]
                            HStack(spacing: 6) {
                                Text(fact.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(fact.value)
                                    .font(.caption)
                                    .foregroundStyle(KairoDesign.ink)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(KairoDesign.softSurface.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                Divider()

                Text(KairoL10n.string("chat.message.rawJSON"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(json)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(10)
                    .background(KairoDesign.softSurface.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func infoSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
    }

    private func infoField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(KairoDesign.ink)
        }
    }

    private func infoPill(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct InfoPageKeywordTags: View {
    let keywords: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(keywords, id: \.self) { keyword in
                Text(keyword)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(KairoDesign.teal)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(KairoDesign.teal.opacity(0.10), in: Capsule())
            }
        }
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.last?.maxY ?? 0
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(proposal: proposal, subviews: subviews)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: .unspecified
                )
            }
        }
    }

    private struct RowItem { var index: Int; var x: CGFloat }
    private struct Row { var items: [RowItem]; var maxY: CGFloat; var y: CGFloat }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? 0
        var rows: [Row] = []
        var currentRow: [RowItem] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !currentRow.isEmpty, currentX + spacing + size.width > maxWidth {
                let rowHeight = currentRow.map { _ in size.height }.max() ?? size.height
                rows.append(Row(items: currentRow, maxY: currentY + rowHeight, y: currentY))
                currentRow = []
                currentX = 0
                currentY += rowHeight + spacing
            }
            currentRow.append(RowItem(index: index, x: currentX))
            currentX += size.width + spacing
        }
        if !currentRow.isEmpty {
            let size = subviews.last?.sizeThatFits(.unspecified) ?? .zero
            rows.append(Row(items: currentRow, maxY: currentY + size.height, y: currentY))
        }
        return rows
    }
}

@ViewBuilder
private func chatComposerGlassContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
        GlassEffectContainer(spacing: 8) {
            content()
        }
    } else {
        content()
    }
}

private extension View {
    @ViewBuilder
    func chatComposerGlassSurface(cornerRadius: CGFloat, tint: Color, isInteractive: Bool) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.12))
                            .interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                    }
            } else {
                self
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.08)),
                        in: .rect(cornerRadius: cornerRadius)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                    }
            }
        } else {
            self
                .background(KairoDesign.elevatedSurface.opacity(0.72), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
    }

    @ViewBuilder
    func chatComposerGlassCircle(tint: Color, isInteractive: Bool) -> some View {
        if #available(iOS 26.0, macOS 26.0, visionOS 26.0, *) {
            if isInteractive {
                self
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.12))
                            .interactive(),
                        in: .circle
                    )
                    .overlay {
                        Circle()
                            .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                    }
            } else {
                self
                    .glassEffect(
                        .regular
                            .tint(tint.opacity(0.08)),
                        in: .circle
                    )
                    .overlay {
                        Circle()
                            .stroke(KairoDesign.line.opacity(0.55), lineWidth: 1)
                    }
            }
        } else {
            self
                .background(KairoDesign.softSurface.opacity(0.62), in: Circle())
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                }
        }
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
