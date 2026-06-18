#if canImport(SwiftUI)
import SwiftUI

struct KairoBriefingStrip: View {
    let snapshot: KairoBriefingSnapshot
    let openCaptures: () -> Void
    let reviewCaptures: () -> Void

    init(
        snapshot: KairoBriefingSnapshot = .empty,
        openCaptures: @escaping () -> Void = {},
        reviewCaptures: @escaping () -> Void = {}
    ) {
        self.snapshot = snapshot
        self.openCaptures = openCaptures
        self.reviewCaptures = reviewCaptures
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if snapshot.pendingCaptureCount > 0 {
                    briefingButton(
                        title: sharedTitle,
                        systemImage: "square.and.arrow.down",
                        tint: KairoDesign.blue,
                        action: openCaptures
                    )
                }
                if snapshot.confirmationCount > 0 {
                    briefingButton(
                        title: reviewTitle,
                        systemImage: "checklist.checked",
                        tint: KairoDesign.amber,
                        action: reviewCaptures
                    )
                }
                if snapshot.reminderDraftCount > 0 {
                    KairoStatusPill(title: reminderTitle, systemImage: "checklist", tint: KairoDesign.teal)
                }
                if snapshot.handoffCount > 0 {
                    KairoStatusPill(title: handoffTitle, systemImage: "arrow.up.forward.app", tint: KairoDesign.blue)
                }
                if snapshot.memoryDraftCount > 0 {
                    KairoStatusPill(title: memoryTitle, systemImage: "books.vertical", tint: KairoDesign.teal)
                }
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

    @ViewBuilder
    private func briefingButton(
        title: String,
        systemImage: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            KairoStatusPill(title: title, systemImage: systemImage, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat.briefing.\(systemImage).button")
    }

    private var sharedTitle: String {
        KairoL10n.string("chat.briefing.shared.count", Int64(snapshot.pendingCaptureCount))
    }

    private var reviewTitle: String {
        KairoL10n.string("chat.briefing.reviews.count", Int64(snapshot.confirmationCount))
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
