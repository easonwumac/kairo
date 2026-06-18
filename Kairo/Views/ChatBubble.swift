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
    let onShowRawJSON: (String) -> Void
    @State private var isReasoningExpanded = false
    @State private var isPipelineDetailPresented = false

    private var isUser: Bool { message.role == .user }
    private var bubbleMaxWidth: CGFloat { isUser ? 520 : 720 }
    private var oppositeSideSpacerWidth: CGFloat { isUser ? 72 : 0 }
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
                            .lineSpacing(1)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: bubbleMaxWidth, alignment: bubbleAlignment)
                .onLongPressGesture {
                    guard !isUser, let rawJSON = message.rawModelResponse?.trimmingCharacters(in: .whitespacesAndNewlines), !rawJSON.isEmpty else {
                        return
                    }
                    onShowRawJSON(rawJSON)
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

                if !isUser, let diagnostic = message.pipelineDiagnosticResult {
                    PipelineDiagnosticResultCard(result: diagnostic, maxWidth: bubbleMaxWidth)
                        .accessibilityIdentifier("chat.message.pipeline-diagnostic.\(message.id.uuidString)")
                }

                if !isUser, let trace = message.promptPipelineTrace, shouldShowTraceChip(for: trace) {
                    Button {
                        isPipelineDetailPresented = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: traceIconName(for: trace.status))
                                .font(.caption2.weight(.bold))
                            Text(traceStatusText(for: trace))
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .opacity(0.62)
                        }
                        .foregroundStyle(traceTint(for: trace.status))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .frame(maxWidth: bubbleMaxWidth, alignment: .leading)
                        .background(traceTint(for: trace.status).opacity(0.10), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(traceStatusText(for: trace))
                    .accessibilityIdentifier("chat.message.pipeline.\(message.id.uuidString)")
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
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(message.text)
        .accessibilityIdentifier(isUser ? "chat.message.user" : "chat.message.assistant")
        .sheet(isPresented: $isPipelineDetailPresented) {
            if let trace = message.promptPipelineTrace {
                PromptPipelineTraceDetailView(trace: trace)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
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

    private func traceStatusText(for trace: PromptPipelineTrace) -> String {
        let attempts = max(trace.attemptCount, 1)
        switch trace.status {
        case .validated:
            return KairoL10n.string("chat.message.pipeline.validated", Int64(attempts))
        case .needsRepair:
            return KairoL10n.string("chat.message.pipeline.repaired", Int64(attempts))
        case .needsReview:
            return KairoL10n.string("chat.message.pipeline.review", Int64(attempts))
        case .failed:
            return KairoL10n.string("chat.message.pipeline.failed", Int64(attempts))
        }
    }

    private func shouldShowTraceChip(for trace: PromptPipelineTrace) -> Bool {
        trace.status != .validated || !trace.validationIssues.isEmpty
    }

    private func traceTint(for status: PromptPipelineTrace.Status) -> Color {
        switch status {
        case .validated:
            return KairoDesign.teal
        case .needsRepair, .needsReview:
            return KairoDesign.amber
        case .failed:
            return .orange
        }
    }

    private func traceIconName(for status: PromptPipelineTrace.Status) -> String {
        switch status {
        case .validated:
            return "checkmark.seal.fill"
        case .needsRepair:
            return "arrow.triangle.2.circlepath"
        case .needsReview:
            return "eye.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
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

private struct PromptPipelineTraceDetailView: View {
    let trace: PromptPipelineTrace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                headerCard
                stagesCard
                if !trace.validationIssues.isEmpty {
                    issuesCard
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(KairoDesign.background.ignoresSafeArea())
        .accessibilityIdentifier("chat.pipeline.detail")
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: iconName(for: trace.status))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(pipelineTint(for: trace.status))
                    .frame(width: 34, height: 34)
                    .background(pipelineTint(for: trace.status).opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(KairoL10n.string("chat.pipeline.detail.title"))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(trace.providerID)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.muted)
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                metricPill(KairoL10n.string("chat.pipeline.detail.attempts", Int64(max(trace.attemptCount, 1))))
                metricPill(KairoL10n.string("chat.pipeline.detail.repairs", Int64(trace.repairedStageCount)))
                metricPill(KairoL10n.string("chat.pipeline.detail.failures", Int64(trace.failedStageCount)))
            }
        }
        .padding(14)
        .kairoGlassCard(tint: pipelineTint(for: trace.status), cornerRadius: 18)
    }

    private var stagesCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text(KairoL10n.string("chat.pipeline.detail.stages"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)

            ForEach(Array(trace.stages.enumerated()), id: \.offset) { index, stage in
                PromptPipelineStageRow(index: index + 1, stage: stage)
                if index < trace.stages.count - 1 {
                    Divider().opacity(0.45)
                }
            }
        }
        .padding(14)
        .kairoGlassCard(tint: KairoDesign.blue, cornerRadius: 18)
    }

    private var issuesCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(KairoL10n.string("chat.pipeline.detail.issues"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(KairoDesign.ink)

            ForEach(Array(trace.validationIssues.enumerated()), id: \.offset) { _, issue in
                Label(issue, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(KairoDesign.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .kairoGlassCard(tint: KairoDesign.amber, cornerRadius: 18)
    }

    private func metricPill(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(KairoDesign.ink)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(KairoDesign.softSurface.opacity(0.72), in: Capsule())
    }
}

private struct PipelineDiagnosticResultCard: View {
    let result: PipelineDiagnosticResult
    let maxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: iconName)
                    .font(.caption.weight(.bold))
                Text(KairoL10n.string("chat.pipeline.diagnostic.result", result.verdict.rawValue, confidenceText))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(tint)

            if !result.likelyFailure.isEmpty {
                Text(result.likelyFailure)
                    .font(.caption2)
                    .foregroundStyle(KairoDesign.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !result.promptFix.isEmpty {
                Label(result.promptFix, systemImage: "wrench.and.screwdriver.fill")
                    .font(.caption2)
                    .foregroundStyle(KairoDesign.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: maxWidth, alignment: .leading)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var confidenceText: String {
        "\(Int((result.confidence * 100).rounded()))%"
    }

    private var tint: Color {
        switch result.verdict {
        case .pass:
            return KairoDesign.teal
        case .watch:
            return KairoDesign.amber
        case .fail:
            return .orange
        }
    }

    private var iconName: String {
        switch result.verdict {
        case .pass:
            return "checkmark.seal.fill"
        case .watch:
            return "eye.fill"
        case .fail:
            return "exclamationmark.triangle.fill"
        }
    }
}

private struct PromptPipelineStageRow: View {
    let index: Int
    let stage: PromptPipelineStageTrace

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(index)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(pipelineTint(for: stage.status))
                .frame(width: 22, height: 22)
                .background(pipelineTint(for: stage.status).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(stageTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(stageStatusText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(pipelineTint(for: stage.status))
                }

                Text(stageMetadata)
                    .font(.caption2)
                    .foregroundStyle(KairoDesign.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if let detail = stage.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(KairoDesign.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("chat.pipeline.stage.\(index)")
    }

    private var stageTitle: String {
        switch stage.name {
        case .buildPrompt:
            return KairoL10n.string("chat.pipeline.stage.buildPrompt")
        case .requestModel:
            return KairoL10n.string("chat.pipeline.stage.requestModel")
        case .parseStructuredOutput:
            return KairoL10n.string("chat.pipeline.stage.parseStructuredOutput")
        case .validateDraft:
            return KairoL10n.string("chat.pipeline.stage.validateDraft")
        case .repairPrompt:
            return KairoL10n.string("chat.pipeline.stage.repairPrompt")
        case .routeEscalation:
            return KairoL10n.string("chat.pipeline.stage.routeEscalation")
        case .finalize:
            return KairoL10n.string("chat.pipeline.stage.finalize")
        }
    }

    private var stageStatusText: String {
        switch stage.status {
        case .pending:
            return KairoL10n.string("chat.pipeline.stage.status.pending")
        case .passed:
            return KairoL10n.string("chat.pipeline.stage.status.passed")
        case .repaired:
            return KairoL10n.string("chat.pipeline.stage.status.repaired")
        case .failed:
            return KairoL10n.string("chat.pipeline.stage.status.failed")
        }
    }

    private var stageMetadata: String {
        var parts: [String] = []
        if let attempt = stage.attempt {
            parts.append(KairoL10n.string("chat.pipeline.stage.attempt", Int64(attempt)))
        }
        if let inputCharacters = stage.inputCharacters {
            parts.append(KairoL10n.string("chat.pipeline.stage.input", Int64(inputCharacters)))
        }
        if let outputCharacters = stage.outputCharacters {
            parts.append(KairoL10n.string("chat.pipeline.stage.output", Int64(outputCharacters)))
        }
        return parts.isEmpty ? KairoL10n.string("chat.pipeline.stage.noMetrics") : parts.joined(separator: " · ")
    }
}

private func pipelineTint(for status: PromptPipelineTrace.Status) -> Color {
    switch status {
    case .validated:
        return KairoDesign.teal
    case .needsRepair, .needsReview:
        return KairoDesign.amber
    case .failed:
        return .orange
    }
}

private func iconName(for status: PromptPipelineTrace.Status) -> String {
    switch status {
    case .validated:
        return "checkmark.seal.fill"
    case .needsRepair:
        return "arrow.triangle.2.circlepath"
    case .needsReview:
        return "eye.fill"
    case .failed:
        return "exclamationmark.triangle.fill"
    }
}

private func pipelineTint(for status: PromptPipelineStageTrace.Status) -> Color {
    switch status {
    case .pending:
        return KairoDesign.muted
    case .passed:
        return KairoDesign.teal
    case .repaired:
        return KairoDesign.amber
    case .failed:
        return .orange
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
