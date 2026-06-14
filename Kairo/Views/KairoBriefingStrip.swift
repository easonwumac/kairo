#if canImport(SwiftUI)
import SwiftUI

struct KairoBriefingStrip: View {
    let snapshot: KairoBriefingSnapshot

    init(snapshot: KairoBriefingSnapshot = .empty) {
        self.snapshot = snapshot
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                KairoStatusPill(title: sharedTitle, systemImage: "square.and.arrow.down", tint: KairoDesign.blue)
                KairoStatusPill(title: reviewTitle, systemImage: "checklist.checked", tint: KairoDesign.amber)
                if snapshot.reminderDraftCount > 0 {
                    KairoStatusPill(title: reminderTitle, systemImage: "checklist", tint: KairoDesign.teal)
                }
                if snapshot.handoffCount > 0 {
                    KairoStatusPill(title: handoffTitle, systemImage: "arrow.up.forward.app", tint: KairoDesign.blue)
                }
                if snapshot.memoryDraftCount > 0 {
                    KairoStatusPill(title: memoryTitle, systemImage: "books.vertical", tint: KairoDesign.teal)
                }
                KairoStatusPill(title: KairoL10n.string("chat.briefing.noSilentWrites"), systemImage: "hand.raised", tint: KairoDesign.amber)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .background(KairoDesign.groupedSurface)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chat.briefing-strip")
    }

    private var sharedTitle: String {
        snapshot.pendingCaptureCount == 0
            ? KairoL10n.string("chat.briefing.shared.none")
            : KairoL10n.string("chat.briefing.shared.count", Int64(snapshot.pendingCaptureCount))
    }

    private var reviewTitle: String {
        snapshot.confirmationCount == 0
            ? KairoL10n.string("chat.briefing.reviews.none")
            : KairoL10n.string("chat.briefing.reviews.count", Int64(snapshot.confirmationCount))
    }

    private var reminderTitle: String {
        KairoL10n.string("chat.briefing.reminders.count", Int64(snapshot.reminderDraftCount))
    }

    private var handoffTitle: String {
        KairoL10n.string("chat.briefing.handoffs.count", Int64(snapshot.handoffCount))
    }

    private var memoryTitle: String {
        KairoL10n.string("chat.briefing.memory.count", Int64(snapshot.memoryDraftCount))
    }
}
#endif
