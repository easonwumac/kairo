#if canImport(SwiftUI)
import SwiftUI

struct ShareImportBanner: View {
    let notice: String
    let preview: String?
    let canSend: Bool
    let actionTitle: String
    let send: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(notice, systemImage: "square.and.arrow.down.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                if let preview {
                    Text(preview)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("chat.share-import.preview")
                }
            }
            Spacer(minLength: 8)
            Button(action: send) {
                Text(actionTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .disabled(!canSend)
            .accessibilityIdentifier("chat.share-import.send")
        }
        .padding(12)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.share-import.banner")
    }
}

struct CaptureReviewSummaryBanner: View {
    let summary: CaptureReviewSummary
    let items: [CaptureReviewItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(KairoDesign.teal)
                    .frame(width: 24, height: 24)
                    .background(KairoDesign.teal.opacity(0.14), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(summary.primaryText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(KairoDesign.ink)
                    Text(summary.detailText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .accessibilityIdentifier("chat.capture-review.detail")
                }

                Spacer(minLength: 8)
            }

            if !items.isEmpty {
                VStack(spacing: 7) {
                    ForEach(items.prefix(4)) { item in
                        CaptureReviewItemRow(item: item)
                    }
                }
                .accessibilityIdentifier("chat.capture-review.items")
            }
        }
        .padding(12)
        .background(KairoDesign.teal.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.teal.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.capture-review.summary")
    }
}

private struct CaptureReviewItemRow: View {
    let item: CaptureReviewItem

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.triageText)
                .font(.caption2.weight(.bold))
                .foregroundStyle(KairoDesign.teal)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(KairoDesign.teal.opacity(0.12), in: Capsule())

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                    .lineLimit(1)
                if !item.detail.isEmpty {
                    Text(item.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 6)

            VStack(alignment: .trailing, spacing: 3) {
                if item.isActive {
                    Text(KairoL10n.string("chat.captureReview.item.active"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
                Text(item.actionText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(7)
        .background(item.isActive ? Color.accentColor.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(item.isActive ? Color.accentColor.opacity(0.26) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.capture-review.item")
    }
}

struct ShareActionReviewBanner: View {
    let action: AgentAction
    let review: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(action.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action: review) {
                Text(buttonTitle)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("chat.share-import.review-action")
        }
        .padding(12)
        .background(KairoDesign.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.teal.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.share-import.review-banner")
    }

    private var title: String {
        action.kind == .createReminderDraft
            ? KairoL10n.string("chat.share.review.reminderReady")
            : KairoL10n.string("chat.share.review.actionReady")
    }

    private var buttonTitle: String {
        action.kind == .createReminderDraft
            ? KairoL10n.string("chat.action.reviewReminder")
            : KairoL10n.string("chat.action.reviewAction")
    }

    private var iconName: String {
        switch action.kind {
        case .saveMemory:
            return "tray.and.arrow.down.fill"
        case .openMapDirections, .openWebSearchHandoff, .openMessageHandoff, .openPhoneCallHandoff:
            return "arrow.up.forward.app"
        default:
            return "checklist.checked"
        }
    }
}

struct CalendarActionReviewBanner: View {
    let action: AgentAction
    let review: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(KairoL10n.string("chat.share.review.calendarReady"), systemImage: "calendar.badge.plus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(action.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action: review) {
                Text(KairoL10n.string("chat.action.reviewCalendar"))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("chat.calendar.review-action")
        }
        .padding(12)
        .background(KairoDesign.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.blue.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.calendar.review-banner")
    }
}

struct HandoffActionReviewBanner: View {
    let action: AgentAction
    let review: () -> Void
    private let descriptorProvider: any AgentActionDescriptorProviding

    init(
        action: AgentAction,
        descriptorProvider: any AgentActionDescriptorProviding = BuiltInPhoneToolActionDescriptorProvider(),
        review: @escaping () -> Void
    ) {
        self.action = action
        self.descriptorProvider = descriptorProvider
        self.review = review
    }

    var body: some View {
        let displayName = descriptorProvider.descriptor(for: action.kind)?.displayName ?? action.title
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Label(KairoL10n.string("chat.share.review.handoffReady"), systemImage: "arrow.up.forward.app")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KairoDesign.ink)
                Text(KairoL10n.string("chat.share.review.handoffDetail", displayName))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action: review) {
                Text(KairoL10n.string("chat.action.reviewHandoff"))
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("chat.handoff.review-action")
        }
        .padding(12)
        .background(KairoDesign.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(KairoDesign.amber.opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.handoff.review-banner")
    }
}
#endif
