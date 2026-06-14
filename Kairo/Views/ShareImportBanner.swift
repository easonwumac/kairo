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
